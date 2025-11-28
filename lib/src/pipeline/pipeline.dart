import 'dart:async';
import 'dart:collection';

import 'package:pureflow/src/common/bit_flags.dart';
import 'package:pureflow/src/common/synchronous_future.dart';

/// EventMapper transforms a single event into a stream of results.
typedef EventMapper<EventType, ResultType> = Stream<ResultType> Function(
    EventType event);

/// EventTransformer processes a stream of events using an EventMapper.
typedef EventTransformer<EventType, ResultType> = Stream<ResultType> Function(
  Stream<EventType> source,
  EventMapper<EventType, ResultType> process,
);

/// Mixin for objects that can be cancelled and track active state.
mixin _CancellableMixin {
  _TaskStream get _taskStream;
  bool _isCancelled = false;

  @pragma('vm:prefer-inline')
  bool get isActive => !_isCancelled && _taskStream._isActive;

  @pragma('vm:prefer-inline')
  void markCancelled() => _isCancelled = true;
}

/// Context object that provides access to the active status of a pipeline event.
/// Can be used directly as a parameter in pipeline tasks.
class PipelineEventContext with _CancellableMixin {
  @override
  final _TaskStream _taskStream;
  final Stopwatch _stopwatch;

  PipelineEventContext._(this._taskStream, this._stopwatch);

  /// Returns the duration for which the current event has been processing.
  @pragma('vm:prefer-inline')
  Duration get eventDuration => _stopwatch.elapsed;
}

/// Internal event wrapper for pipeline tasks.
class _PipelineEvent<ResultType> with _CancellableMixin {
  final Future<ResultType> Function(PipelineEventContext context) task;
  final Completer<ResultType> completer;
  @override
  final _TaskStream _taskStream;
  late final PipelineEventContext context;
  final Stopwatch _stopwatch = Stopwatch();

  _PipelineEvent({
    required this.task,
    required this.completer,
    required _TaskStream taskStream,
  }) : _taskStream = taskStream {
    context = PipelineEventContext._(_taskStream, _stopwatch);
  }

  @pragma('vm:prefer-inline')
  void cancel() {
    markCancelled();
    context.markCancelled();
  }
}

/// Pipeline processes tasks through a unified event bus with transformation.
class Pipeline {
  final EventTransformer<dynamic, dynamic> transformer;
  final _TaskStream _taskStream;

  Pipeline({required this.transformer})
      : _taskStream = _TaskStream(transformer: transformer);

  /// Runs a task through the pipeline event bus.
  /// The task receives a PipelineEventContext object that provides access
  /// to the `isActive` getter.
  @pragma('vm:prefer-inline')
  Future<ResultType> run<ResultType>(
    Future<ResultType> Function(PipelineEventContext context) task,
  ) {
    final completer = Completer<ResultType>.sync();
    _taskStream.add(
      _PipelineEvent<ResultType>(
        task: task,
        completer: completer,
        taskStream: _taskStream,
      ),
    );
    return completer.future;
  }

  /// Disposes the pipeline.
  ///
  /// If [force] is `true`, all events become inactive immediately.
  /// If [force] is `false`, new events are prevented and the method waits
  /// for all active events to complete.
  Future<void> dispose({bool force = false}) {
    return _taskStream.dispose(force: force);
  }
}

/// Internal stream wrapper for processing pipeline tasks.
class _TaskStream {
  final EventTransformer<dynamic, dynamic> transformer;
  // Use ListQueue for better performance - more cache-friendly than Queue
  final Queue<_PipelineEvent<dynamic>> _eventQueue =
      Queue<_PipelineEvent<dynamic>>();
  // Use Set for O(1) removal instead of List O(n)
  final Set<_PipelineEvent<dynamic>> _activeEvents = {};
  Completer<void>? _waitingCompleter;
  bool _isActive = true;
  bool _isDisposed = false;
  StreamSubscription<dynamic>? _subscription;

  _TaskStream({required this.transformer}) {
    _initializeProcessing();
  }

  void _initializeProcessing() {
    final sourceStream = _createSourceStream();
    final processedStream = transformer(sourceStream, _processEvent);
    _subscription = processedStream.listen(
      null, // Results are handled in _SinglePipelineEventSubscription
      onError: _handleError,
      cancelOnError: false,
      onDone: _handleDone,
    );
  }

  Stream<dynamic> _createSourceStream() async* {
    while (_isActive) {
      if (_eventQueue.isEmpty) {
        final pendingCompleter = _waitingCompleter ??= Completer<void>.sync();
        await pendingCompleter.future;
        _waitingCompleter = null;
        if (!_isActive) return;
      }
      yield _eventQueue.removeFirst();
    }
  }

  @pragma('vm:prefer-inline')
  void _handleDone() {
    _isActive = false;
    _cancelActiveEvents();
    _completeWaitingCompleter();
  }

  @pragma('vm:prefer-inline')
  void _completeWaitingCompleter() {
    final completer = _waitingCompleter;
    if (completer != null && !completer.isCompleted) {
      _waitingCompleter = null;
      completer.complete();
    }
  }

  @pragma('vm:prefer-inline')
  void _cancelActiveEvents() {
    if (_activeEvents.isEmpty) return;
    // Iterate directly over Set without copying
    for (final event in _activeEvents) {
      event.cancel();
    }
    _activeEvents.clear();
  }

  @pragma('vm:prefer-inline')
  Stream<dynamic> _processEvent(dynamic event) {
    // Fast type check
    if (event is! _PipelineEvent<dynamic>) {
      return const Stream<dynamic>.empty();
    }
    _activeEvents.add(event);
    return _SinglePipelineEventStream._(event, _activeEvents.remove);
  }

  @pragma('vm:prefer-inline')
  void _handleError(Object error, StackTrace stackTrace) {
    // Errors are handled in _SinglePipelineEventSubscription
    // This is a fallback for transformer-level errors
    if (_activeEvents.isEmpty) return;
    _cancelActiveEvents();
  }

  @pragma('vm:prefer-inline')
  void add(_PipelineEvent<dynamic> event) {
    // Optimize: check _isDisposed first (most common case)
    if (_isDisposed) return event.cancel();
    if (!_isActive) return event.cancel();

    _eventQueue.add(event);
    _completeWaitingCompleter();
  }

  /// Disposes the task stream.
  ///
  /// If [force] is `true`, all events become inactive immediately.
  /// If [force] is `false`, new events are prevented and the method waits
  /// for all active events to complete.
  Future<void> dispose({bool force = false}) async {
    if (_isDisposed) return;
    _isDisposed = true;

    if (force) {
      // Force mode: make all events inactive immediately
      _isActive = false;

      // Cancel all queued events (they haven't started yet)
      final queueLength = _eventQueue.length;
      for (var index = 0; index < queueLength; index++) {
        _eventQueue.removeFirst().cancel();
      }

      _cancelActiveEvents();
      _completeWaitingCompleter();

      // Cancel the subscription
      await _subscription?.cancel();
      _subscription = null;
      return;
    }

    // Non-force mode: prevent new events but keep existing ones active
    final queuedCount = _eventQueue.length;
    final activeCount = _activeEvents.length;
    final totalCount = queuedCount + activeCount;

    if (totalCount == 0) {
      _isActive = false;
      _completeWaitingCompleter();
      final sub = _subscription;
      if (sub != null) {
        await sub.cancel();
      }
      _subscription = null;
      return;
    }

    // Collect futures directly without copying lists
    final futures = <Future<dynamic>>[];
    // Add queued events - iterate directly over Queue
    for (final event in _eventQueue) {
      futures.add(event.completer.future);
    }
    // Add active events - iterate directly over Set
    for (final event in _activeEvents) {
      futures.add(event.completer.future);
    }

    // Wake up the stream processor to start processing queued events
    _completeWaitingCompleter();

    // Wait for all events to complete
    await Future.wait(futures);

    // After all events complete, mark as inactive
    _isActive = false;
    _completeWaitingCompleter();

    // Cancel the subscription
    final sub = _subscription;
    if (sub != null) {
      await sub.cancel();
    }
    _subscription = null;
  }
}

/// Bit flags for pipeline event status.
const int _canceledBit = 1 << 0;
const int _pausedBit = 1 << 1;
const int _closedBit = 1 << 2;
const int _didCallDoneBit = 1 << 3;
const int _asFutureCompletedBit = 1 << 4;

/// Stream implementation that allows us to detect cancellation without
/// relying on [StreamController].
class _SinglePipelineEventStream extends Stream<dynamic> {
  final _PipelineEvent<dynamic> event;
  final void Function(_PipelineEvent<dynamic> event) onStreamClosed;

  _SinglePipelineEventStream._(this.event, this.onStreamClosed);

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _SinglePipelineEventSubscription._(
      event,
      onStreamClosed,
      onData,
      onError,
      onDone,
      cancelOnError ?? false,
    );
  }
}

class _SinglePipelineEventSubscription implements StreamSubscription<dynamic> {
  final _PipelineEvent<dynamic> event;
  final void Function(_PipelineEvent<dynamic> event) onStreamClosed;
  void Function(dynamic event)? _onData;
  Function? _onError;
  void Function()? _onDone;
  final bool _cancelOnError;
  final Zone _zone = Zone.current;

  int _statusFlag = 0;
  Completer<void>? _resumeCompleter;
  Future<void>? _taskFuture;
  Object? _lastData;
  Object? _lastError;
  StackTrace? _lastStackTrace;
  final List<_AsFutureRequest<Object?>> _asFutureRequests = [];

  _SinglePipelineEventSubscription._(
    this.event,
    this.onStreamClosed,
    this._onData,
    this._onError,
    this._onDone,
    this._cancelOnError,
  ) {
    _taskFuture = _run();
  }

  Future<void> _run() async {
    event._stopwatch.start();
    try {
      final result = await event.task(event.context);
      if (_shouldEmit) {
        await _completeWithResult(result);
      }
    } catch (error, stackTrace) {
      if (_shouldEmit) {
        await _completeWithError(error, stackTrace);
      }
    } finally {
      event._stopwatch.stop();
      _closeStream();
    }
  }

  @pragma('vm:prefer-inline')
  bool get _shouldEmit =>
      !_statusFlag.hasFlag(_canceledBit) && !event._isCancelled;

  @pragma('vm:prefer-inline')
  void _tryCompleteCompleter(void Function() complete) {
    final eventCompleter = event.completer;
    if (!eventCompleter.isCompleted) {
      complete();
    }
  }

  @pragma('vm:prefer-inline')
  Future<void> _waitForResumeIfPaused() async {
    if (!_statusFlag.hasFlag(_pausedBit)) return;
    if (_statusFlag.hasFlag(_canceledBit)) return;
    final resumeCompleter = _resumeCompleter ??= Completer<void>();
    await resumeCompleter.future;
    _resumeCompleter = null;
  }

  @pragma('vm:prefer-inline')
  void _invokeDataHandler(dynamic result) {
    final handler = _onData;
    if (handler != null) {
      _zone.runUnaryGuarded(handler, result);
    }
  }

  @pragma('vm:prefer-inline')
  void _invokeDoneHandlerIfNeeded() {
    if (_statusFlag.hasFlag(_didCallDoneBit)) return;
    _statusFlag = _statusFlag.setFlag(_didCallDoneBit);
    final doneHandler = _onDone;
    if (doneHandler != null) {
      _zone.runGuarded(doneHandler);
    }
  }

  @pragma('vm:prefer-inline')
  bool _invokeErrorHandler(Object error, StackTrace stackTrace) {
    final errorHandler = _onError;
    if (errorHandler == null) {
      _zone.handleUncaughtError(error, stackTrace);
      return false;
    }

    var handled = true;
    _zone.runGuarded(() {
      if (errorHandler is void Function(Object, StackTrace)) {
        errorHandler(error, stackTrace);
      } else if (errorHandler is void Function(Object)) {
        errorHandler(error);
      } else {
        _zone.handleUncaughtError(error, stackTrace);
        handled = false;
      }
    });
    return handled;
  }

  Future<void> _completeWithResult(dynamic result) async {
    _tryCompleteCompleter(() => event.completer.complete(result));
    _lastData = result;
    _lastError = null;
    _lastStackTrace = null;

    await _waitForResumeIfPaused();
    if (_statusFlag.hasFlag(_canceledBit)) return;

    _invokeDataHandler(result);
    _invokeDoneHandlerIfNeeded();
    _completeAsFutureWithSuccess();
  }

  Future<void> _completeWithError(Object error, StackTrace stackTrace) async {
    _tryCompleteCompleter(
      () => event.completer.completeError(error, stackTrace),
    );
    _lastError = error;
    _lastStackTrace = stackTrace;

    await _waitForResumeIfPaused();
    if (_statusFlag.hasFlag(_canceledBit)) return;

    final handled = _invokeErrorHandler(error, stackTrace);

    if (_cancelOnError && handled) {
      await cancel();
      return;
    }

    if (!handled && _onData == null) {
      _invokeDoneHandlerIfNeeded();
    }
    _completeAsFutureWithError(error, stackTrace);
  }

  @pragma('vm:prefer-inline')
  void _closeStream() {
    if (_statusFlag.hasFlag(_closedBit)) return;
    _statusFlag = _statusFlag.setFlag(_closedBit);
    onStreamClosed(event);
    if (!_statusFlag.hasFlag(_canceledBit) &&
        !event.completer.isCompleted &&
        !event._isCancelled) {
      event.cancel();
    }
    if (_lastError == null) {
      _completeAsFutureWithSuccess();
    }
    _completeResumeCompleter();
    // Clear references to help GC
    _lastData = null;
    _lastError = null;
    _lastStackTrace = null;
  }

  @override
  Future<void> cancel() {
    if (_statusFlag.hasFlag(_canceledBit)) {
      return _taskFuture ?? const SynchronousFuture<void>(null);
    }
    _statusFlag = _statusFlag.setFlag(_canceledBit);
    event.cancel();
    _completeResumeCompleter();
    return _taskFuture ?? const SynchronousFuture<void>(null);
  }

  @override
  void onData(void Function(dynamic event)? handleData) {
    _onData = handleData;
  }

  @override
  void onError(Function? handleError) {
    _onError = handleError;
  }

  @override
  void onDone(void Function()? handleDone) {
    _onDone = handleDone;
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    if (_statusFlag.hasFlag(_pausedBit | _canceledBit)) return;
    _statusFlag = _statusFlag.setFlag(_pausedBit);
    resumeSignal?.whenComplete(resume);
  }

  @override
  void resume() {
    if (!_statusFlag.hasFlag(_pausedBit)) return;
    _statusFlag = _statusFlag.clearFlag(_pausedBit);
    _completeResumeCompleter();
  }

  @pragma('vm:prefer-inline')
  void _completeResumeCompleter() {
    final resumeCompleter = _resumeCompleter;
    if (resumeCompleter != null) {
      _resumeCompleter = null;
      resumeCompleter.complete();
    }
  }

  @override
  bool get isPaused => _statusFlag.hasFlag(_pausedBit);

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    if (_statusFlag.hasFlag(_asFutureCompletedBit)) {
      if (_lastError != null) {
        return Future<E>.error(_lastError!, _lastStackTrace);
      }
      return Future<E>.value(futureValue ?? _lastData as E);
    }
    final request = _AsFutureRequest<E>(
      futureValue: futureValue,
      completer: Completer<E>.sync(),
    );
    _asFutureRequests.add(request);
    return request.completer.future;
  }

  @pragma('vm:prefer-inline')
  void _completeAsFutureWithSuccess() {
    if (_statusFlag.hasFlag(_asFutureCompletedBit)) return;
    final requests = _asFutureRequests;
    final length = requests.length;
    if (length == 0) return;
    _statusFlag = _statusFlag.setFlag(_asFutureCompletedBit);
    // Use indexed loop for better performance
    for (var index = 0; index < length; index++) {
      requests[index].completeSuccess(_lastData);
    }
    requests.clear();
  }

  @pragma('vm:prefer-inline')
  void _completeAsFutureWithError(Object error, StackTrace stackTrace) {
    if (_statusFlag.hasFlag(_asFutureCompletedBit)) return;
    final requests = _asFutureRequests;
    final length = requests.length;
    if (length == 0) return;
    _statusFlag = _statusFlag.setFlag(_asFutureCompletedBit);
    // Use indexed loop for better performance
    for (var index = 0; index < length; index++) {
      requests[index].completeError(error, stackTrace);
    }
    requests.clear();
  }
}

final class _AsFutureRequest<E> {
  final Completer<E> completer;
  final E? futureValue;

  _AsFutureRequest({required this.futureValue, required this.completer});

  @pragma('vm:prefer-inline')
  void completeSuccess(Object? lastData) {
    if (completer.isCompleted) return;
    if (futureValue != null) {
      completer.complete(futureValue as E);
      return;
    }
    completer.complete(lastData as E);
  }

  @pragma('vm:prefer-inline')
  void completeError(Object error, StackTrace stackTrace) {
    if (completer.isCompleted) return;
    completer.completeError(error, stackTrace);
  }
}
