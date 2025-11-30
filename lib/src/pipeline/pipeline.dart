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

/// Context object that provides access to the active status of a pipeline event.
/// Can be used directly as a parameter in pipeline tasks.
///
/// This class is also the internal event wrapper - unified for zero-allocation overhead.
final class PipelineEventContext {
  final Future<dynamic> Function(PipelineEventContext context) _task;
  final Completer<dynamic> _completer;
  final _TaskStream _taskStream;

  bool _isCancelled = false;

  PipelineEventContext._({
    required Future<dynamic> Function(PipelineEventContext) task,
    required Completer<dynamic> completer,
    required _TaskStream taskStream,
  })  : _task = task,
        _completer = completer,
        _taskStream = taskStream;

  /// Returns whether the event is still active (not cancelled and pipeline active).
  @pragma('vm:prefer-inline')
  bool get isActive => !_isCancelled && _taskStream._isActive;

  @pragma('vm:prefer-inline')
  void _cancel() => _isCancelled = true;
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
      PipelineEventContext._(
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
  @pragma('vm:prefer-inline')
  Future<void> dispose({bool force = false}) =>
      _taskStream.dispose(force: force);
}

/// Internal stream wrapper for processing pipeline tasks.
class _TaskStream {
  final EventTransformer<dynamic, dynamic> transformer;
  // Use ListQueue for better performance - more cache-friendly than Queue
  final Queue<PipelineEventContext> _eventQueue = Queue<PipelineEventContext>();
  // Use Set for O(1) removal instead of List O(n)
  final Set<PipelineEventContext> _activeEvents = {};
  Completer<void>? _waitingCompleter;
  bool _isActive = true;
  bool _isDisposed = false;
  // ignore: cancel_subscriptions - cancelled in dispose()
  StreamSubscription<dynamic>? _subscription;

  _TaskStream({required this.transformer}) {
    _initializeProcessing();
  }

  @pragma('vm:prefer-inline')
  void _initializeProcessing() {
    final sourceStream = _SourceStream._(this);
    final processedStream = transformer(sourceStream, _processEvent);
    _subscription = processedStream.listen(
      null, // Results are handled in _SinglePipelineEventSubscription
      cancelOnError: false,
      onDone: _handleDone,
    );
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
    final activeEvents = _activeEvents;
    if (activeEvents.isEmpty) return;
    // Iterate directly over Set without copying
    for (final event in activeEvents) {
      event._cancel();
    }
    activeEvents.clear();
  }

  @pragma('vm:prefer-inline')
  Stream<dynamic> _processEvent(dynamic event) {
    // Fast type check
    if (event is! PipelineEventContext) {
      return const Stream<dynamic>.empty();
    }
    _activeEvents.add(event);
    return _SinglePipelineEventStream._(event, _activeEvents.remove);
  }

  @pragma('vm:prefer-inline')
  void add(PipelineEventContext event) {
    // Optimize: check _isDisposed first (most common case)
    if (_isDisposed) return event._cancel();
    if (!_isActive) return event._cancel();

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

    final eventQueue = _eventQueue;
    final activeEvents = _activeEvents;

    if (force) {
      // Force mode: make all events inactive immediately
      _isActive = false;

      // Cancel all queued events (they haven't started yet)
      final queueLength = eventQueue.length;
      for (var index = 0; index < queueLength; index++) {
        eventQueue.removeFirst()._cancel();
      }

      _cancelActiveEvents();
      _completeWaitingCompleter();

      // Cancel the subscription
      final sub = _subscription;
      _subscription = null;
      await sub?.cancel();
      return;
    }

    // Non-force mode: prevent new events but keep existing ones active
    final queuedCount = eventQueue.length;
    final activeCount = activeEvents.length;
    final totalCount = queuedCount + activeCount;

    if (totalCount == 0) {
      _isActive = false;
      _completeWaitingCompleter();
      final sub = _subscription;
      _subscription = null;
      await sub?.cancel();
      return;
    }

    // Pre-allocate futures list with known size
    final futures = eventQueue
        .map((e) => e._completer.future)
        .followedBy(activeEvents.map((e) => e._completer.future));

    // Wake up the stream processor to start processing queued events
    _completeWaitingCompleter();

    // Wait for all events to complete
    try {
      await Future.wait(futures);
    } catch (_) {}

    // After all events complete, mark as inactive
    _isActive = false;
    _completeWaitingCompleter();

    // Cancel the subscription
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
  }
}

/// Custom Stream implementation to replace async* generator.
/// Pulls events from _TaskStream's queue on demand.
class _SourceStream extends Stream<dynamic> {
  final _TaskStream _taskStream;

  _SourceStream._(this._taskStream);

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _SourceStreamSubscription._(
      _taskStream,
      onData,
      onDone,
    );
  }
}

/// Bit flags for source stream subscription status.
const int _srcCanceledBit = 1 << 0;
const int _srcPausedBit = 1 << 1;
const int _srcScheduledBit = 1 << 2;

/// Custom StreamSubscription for _SourceStream.
class _SourceStreamSubscription implements StreamSubscription<dynamic> {
  final _TaskStream _taskStream;
  void Function(dynamic event)? _onData;
  void Function()? _onDone;

  int _statusFlag = 0;
  Completer<void>? _resumeCompleter;

  _SourceStreamSubscription._(
    this._taskStream,
    this._onData,
    this._onDone,
  ) {
    _scheduleNext();
  }

  void _scheduleNext() {
    // Prevent multiple scheduleMicrotask calls
    if (_statusFlag.hasFlag(_srcScheduledBit)) return;
    if (_statusFlag.hasFlag(_srcCanceledBit)) return;

    _statusFlag = _statusFlag.setFlag(_srcScheduledBit);
    _processNext();
  }

  void _processNext() {
    _statusFlag = _statusFlag.clearFlag(_srcScheduledBit);

    if (_statusFlag.hasFlag(_srcCanceledBit)) return;

    // If paused, wait for resume
    if (_statusFlag.hasFlag(_srcPausedBit)) return;

    // If stream is closed
    if (!_taskStream._isActive) {
      _invokeDone();
      return;
    }

    // If queue is empty, wait for new events
    if (_taskStream._eventQueue.isEmpty) {
      final completer =
          _taskStream._waitingCompleter ??= Completer<void>.sync();
      completer.future.then((_) {
        if (!_statusFlag.hasFlag(_srcCanceledBit)) {
          _scheduleNext();
        }
      });
      return;
    }

    // Get event from queue and emit
    final event = _taskStream._eventQueue.removeFirst();

    _onData?.call(event);
    // Schedule next event processing
    _scheduleNext();
  }

  @pragma('vm:prefer-inline')
  void _invokeDone() => _onDone?.call();

  @override
  Future<void> cancel() {
    if (_statusFlag.hasFlag(_srcCanceledBit)) {
      return const SynchronousFuture<void>(null);
    }
    _statusFlag = _statusFlag.setFlag(_srcCanceledBit);
    _completeResumeCompleter();
    return const SynchronousFuture<void>(null);
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    if (_statusFlag.hasFlag(_srcPausedBit | _srcCanceledBit)) return;
    _statusFlag = _statusFlag.setFlag(_srcPausedBit);
    resumeSignal?.whenComplete(resume);
  }

  @override
  void resume() {
    if (!_statusFlag.hasFlag(_srcPausedBit)) return;
    _statusFlag = _statusFlag.clearFlag(_srcPausedBit);
    _completeResumeCompleter();
    _scheduleNext();
  }

  @pragma('vm:prefer-inline')
  void _completeResumeCompleter() {
    final completer = _resumeCompleter;
    if (completer != null) {
      _resumeCompleter = null;
      completer.complete();
    }
  }

  @override
  bool get isPaused => _statusFlag.hasFlag(_srcPausedBit);

  @override
  void onData(void Function(dynamic event)? handleData) {
    _onData = handleData;
  }

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {
    _onDone = handleDone;
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    final completer = Completer<E>();
    final oldOnDone = _onDone;
    _onDone = () {
      oldOnDone?.call();
      completer.complete(futureValue);
    };
    return completer.future;
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
  final PipelineEventContext event;
  final void Function(PipelineEventContext event) onStreamClosed;

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
      onDone,
    );
  }
}

class _SinglePipelineEventSubscription implements StreamSubscription<dynamic> {
  final PipelineEventContext event;
  final void Function(PipelineEventContext event) onStreamClosed;
  void Function(dynamic event)? _onData;
  void Function()? _onDone;

  int _statusFlag = 0;
  Completer<void>? _resumeCompleter;
  Future<void>? _taskFuture;
  Object? _lastData;
  Object? _lastError;
  StackTrace? _lastStackTrace;
  // Lazy initialization - most events don't use asFuture
  List<_AsFutureRequest<Object?>>? _asFutureRequests;

  _SinglePipelineEventSubscription._(
    this.event,
    this.onStreamClosed,
    this._onData,
    this._onDone,
  ) {
    _taskFuture = _run();
  }

  Future<void> _run() async {
    final evt = event; // Cache for hot path
    try {
      // Future.sync wraps synchronous exceptions into Future errors
      final result = await Future.sync(() => evt._task(evt));
      final statusFlag = _statusFlag;
      if (!statusFlag.hasFlag(_canceledBit) && !evt._isCancelled) {
        await _completeWithResult(result);
      } else {
        // Task was cancelled, but still complete the completer to avoid hanging
        final completer = evt._completer;
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      }
    } catch (error, stackTrace) {
      // Always propagate error through completer FIRST, before any other processing
      // This ensures the error reaches the caller of run() immediately
      final completer = evt._completer;
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      // Then handle error through stream subscription if needed
      final statusFlag = _statusFlag;
      if (!statusFlag.hasFlag(_canceledBit) && !evt._isCancelled) {
        await _completeWithError(error, stackTrace);
      } else {
        // Even if not emitting, we need to signal completion for asyncExpand
        _invokeDoneHandlerIfNeeded();
      }
    } finally {
      // Close stream in finally to ensure it's always called
      _closeStream();
    }
  }

  @pragma('vm:prefer-inline')
  void _invokeDataHandler(dynamic result) => _onData?.call(result);

  @pragma('vm:prefer-inline')
  void _invokeDoneHandlerIfNeeded() {
    final statusFlag = _statusFlag;
    if (statusFlag.hasFlag(_didCallDoneBit)) return;
    // Don't call onDone if subscription is canceled
    if (statusFlag.hasFlag(_canceledBit)) return;
    _statusFlag = statusFlag.setFlag(_didCallDoneBit);
    _onDone?.call();
  }

  Future<void> _completeWithResult(dynamic result) async {
    final completer = event._completer;
    if (!completer.isCompleted) {
      completer.complete(result);
    }
    _lastData = result;

    // Wait for resume if paused
    var statusFlag = _statusFlag;
    if (statusFlag.hasFlag(_pausedBit) && !statusFlag.hasFlag(_canceledBit)) {
      final resumeCompleter = _resumeCompleter ??= Completer<void>();
      await resumeCompleter.future;
      _resumeCompleter = null;
      statusFlag = _statusFlag;
    }
    if (statusFlag.hasFlag(_canceledBit)) return;

    _invokeDataHandler(result);
    _invokeDoneHandlerIfNeeded();
    _completeAsFutureWithSuccess();
  }

  Future<void> _completeWithError(Object error, StackTrace stackTrace) async {
    // Completer is already completed with error in _run()
    // Wrap everything in try-catch to ensure errors don't stop pipeline processing
    try {
      _lastError = error;
      _lastStackTrace = stackTrace;

      final statusFlag = _statusFlag;
      // Don't wait for resume if paused - error is already propagated
      if (statusFlag.hasFlag(_pausedBit) && !statusFlag.hasFlag(_canceledBit)) {
        _completeResumeCompleter(); // Resume immediately to avoid blocking
      }

      if (statusFlag.hasFlag(_canceledBit)) return;

      _completeAsFutureWithError(error, stackTrace);
    } catch (_) {
      // If error handling itself throws, don't let it stop pipeline
    }
  }

  @pragma('vm:prefer-inline')
  void _closeStream() {
    var statusFlag = _statusFlag;
    if (statusFlag.hasFlag(_closedBit)) return;
    _statusFlag = statusFlag = statusFlag.setFlag(_closedBit);

    final evt = event;
    onStreamClosed(evt);

    if (!statusFlag.hasFlag(_canceledBit) &&
        !evt._completer.isCompleted &&
        !evt._isCancelled) {
      evt._cancel();
    }
    if (_lastError == null) {
      _completeAsFutureWithSuccess();
    }
    // Always call onDone when stream closes to signal completion to asyncExpand
    _invokeDoneHandlerIfNeeded();
    _completeResumeCompleter();
    // Clear references to help GC
    _lastData = null;
    _lastError = null;
    _lastStackTrace = null;
  }

  @override
  Future<void> cancel() {
    final statusFlag = _statusFlag;
    if (statusFlag.hasFlag(_canceledBit)) {
      return _taskFuture ?? const SynchronousFuture<void>(null);
    }
    _statusFlag = statusFlag.setFlag(_canceledBit);
    event._cancel();
    _completeResumeCompleter();
    return _taskFuture ?? const SynchronousFuture<void>(null);
  }

  @override
  void onData(void Function(dynamic event)? handleData) {
    _onData = handleData;
  }

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {
    _onDone = handleDone;
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    final statusFlag = _statusFlag;
    if (statusFlag.hasFlag(_pausedBit | _canceledBit)) return;
    _statusFlag = statusFlag.setFlag(_pausedBit);
    resumeSignal?.whenComplete(resume);
  }

  @override
  void resume() {
    final statusFlag = _statusFlag;
    if (!statusFlag.hasFlag(_pausedBit)) return;
    _statusFlag = statusFlag.clearFlag(_pausedBit);
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
    final statusFlag = _statusFlag;
    if (statusFlag.hasFlag(_asFutureCompletedBit)) {
      final lastError = _lastError;
      if (lastError != null) {
        return Future<E>.error(lastError, _lastStackTrace);
      }
      return SynchronousFuture<E>(futureValue ?? _lastData as E);
    }
    final request = _AsFutureRequest<E>(
      futureValue: futureValue,
      completer: Completer<E>.sync(),
    );
    (_asFutureRequests ??= []).add(request);
    return request.completer.future;
  }

  @pragma('vm:prefer-inline')
  void _completeAsFutureWithSuccess() {
    final statusFlag = _statusFlag;
    if (statusFlag.hasFlag(_asFutureCompletedBit)) return;
    final requests = _asFutureRequests;
    if (requests == null || requests.isEmpty) return;
    _statusFlag = statusFlag.setFlag(_asFutureCompletedBit);
    final length = requests.length;
    final lastData = _lastData;
    // Use indexed loop for better performance
    for (var index = 0; index < length; index++) {
      requests[index].completeSuccess(lastData);
    }
    requests.clear();
  }

  @pragma('vm:prefer-inline')
  void _completeAsFutureWithError(Object error, StackTrace stackTrace) {
    final statusFlag = _statusFlag;
    if (statusFlag.hasFlag(_asFutureCompletedBit)) return;
    final requests = _asFutureRequests;
    if (requests == null || requests.isEmpty) return;
    _statusFlag = statusFlag.setFlag(_asFutureCompletedBit);
    final length = requests.length;
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
