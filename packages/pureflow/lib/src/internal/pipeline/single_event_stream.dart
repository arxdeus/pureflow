import 'dart:async';

import 'package:meta/meta.dart';
import 'package:pureflow/src/common/bit_flags.dart';
import 'package:pureflow/src/common/synchronous_future.dart';

import 'package:pureflow/src/implementation/pipeline/pipeline_event_context.dart';

/// Bit flags for pipeline event status.
const int canceledBit = 1 << 0;
const int pausedBit = 1 << 1;
const int closedBit = 1 << 2;
const int didCallDoneBit = 1 << 3;
const int asFutureCompletedBit = 1 << 4;

/// Stream implementation that allows us to detect cancellation without
/// relying on [StreamController].
@internal
class SinglePipelineEventStream extends Stream<dynamic> {
  final PipelineEventContext event;
  final void Function(PipelineEventContext event) onStreamClosed;

  SinglePipelineEventStream(this.event, this.onStreamClosed);

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      SinglePipelineEventSubscription(
        event,
        onStreamClosed,
        onData,
        onDone,
      );
}

@internal
class SinglePipelineEventSubscription implements StreamSubscription<dynamic> {
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
  List<AsFutureRequest<Object?>>? _asFutureRequests;

  SinglePipelineEventSubscription(
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
      final result = await Future.sync(() => evt.task(evt));
      final statusFlag = _statusFlag;
      if (!statusFlag.hasFlag(canceledBit) && evt.isActive) {
        await _completeWithResult(result);
      } else {
        // Task was cancelled, but still complete the completer to avoid hanging
        final completer = evt.completer;
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      }
    } catch (error, stackTrace) {
      // Always propagate error through completer FIRST, before any other processing
      // This ensures the error reaches the caller of run() immediately
      final completer = evt.completer;
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      // Then handle error through stream subscription if needed
      final statusFlag = _statusFlag;
      if (!statusFlag.hasFlag(canceledBit) && evt.isActive) {
        await _completeWithError(error, stackTrace);
      } else {
        // Even if not emitting, we need to store completion for asyncExpand
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
    if (statusFlag.hasFlag(didCallDoneBit)) return;
    // Don't call onDone if subscription is canceled
    if (statusFlag.hasFlag(canceledBit)) return;
    _statusFlag = statusFlag.setFlag(didCallDoneBit);
    _onDone?.call();
  }

  Future<void> _completeWithResult(dynamic result) async {
    final completer = event.completer;
    if (!completer.isCompleted) {
      completer.complete(result);
    }
    _lastData = result;

    // Wait for resume if paused
    var statusFlag = _statusFlag;
    if (statusFlag.hasFlag(pausedBit) && !statusFlag.hasFlag(canceledBit)) {
      final resumeCompleter = _resumeCompleter ??= Completer<void>();
      await resumeCompleter.future;
      _resumeCompleter = null;
      statusFlag = _statusFlag;
    }
    if (statusFlag.hasFlag(canceledBit)) return;

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
      if (statusFlag.hasFlag(pausedBit) && !statusFlag.hasFlag(canceledBit)) {
        _completeResumeCompleter(); // Resume immediately to avoid blocking
      }

      if (statusFlag.hasFlag(canceledBit)) return;

      _completeAsFutureWithError(error, stackTrace);
    } catch (_) {
      // If error handling itself throws, don't let it stop pipeline
    }
  }

  @pragma('vm:prefer-inline')
  void _closeStream() {
    var statusFlag = _statusFlag;
    if (statusFlag.hasFlag(closedBit)) return;
    _statusFlag = statusFlag = statusFlag.setFlag(closedBit);

    final evt = event;
    onStreamClosed(evt);

    if (!statusFlag.hasFlag(canceledBit) &&
        !evt.completer.isCompleted &&
        evt.isActive) {
      evt.cancel();
    }
    if (_lastError == null) {
      _completeAsFutureWithSuccess();
    }
    // Always call onDone when stream closes to store completion to asyncExpand
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
    if (statusFlag.hasFlag(canceledBit)) {
      return _taskFuture ?? const SynchronousFuture<void>(null);
    }
    _statusFlag = statusFlag.setFlag(canceledBit);
    event.cancel();
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
    if (statusFlag.hasFlag(pausedBit | canceledBit)) return;
    _statusFlag = statusFlag.setFlag(pausedBit);
    resumeSignal?.whenComplete(resume);
  }

  @override
  void resume() {
    final statusFlag = _statusFlag;
    if (!statusFlag.hasFlag(pausedBit)) return;
    _statusFlag = statusFlag.clearFlag(pausedBit);
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
  bool get isPaused => _statusFlag.hasFlag(pausedBit);

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    final statusFlag = _statusFlag;
    if (statusFlag.hasFlag(asFutureCompletedBit)) {
      final lastError = _lastError;
      if (lastError != null) {
        return Future<E>.error(lastError, _lastStackTrace);
      }
      return SynchronousFuture<E>(futureValue ?? _lastData as E);
    }
    final request = AsFutureRequest<E>(
      futureValue: futureValue,
      completer: Completer<E>.sync(),
    );
    (_asFutureRequests ??= []).add(request);
    return request.completer.future;
  }

  @pragma('vm:prefer-inline')
  void _completeAsFutureWithSuccess() {
    final statusFlag = _statusFlag;
    if (statusFlag.hasFlag(asFutureCompletedBit)) return;
    final requests = _asFutureRequests;
    if (requests == null || requests.isEmpty) return;
    _statusFlag = statusFlag.setFlag(asFutureCompletedBit);
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
    if (statusFlag.hasFlag(asFutureCompletedBit)) return;
    final requests = _asFutureRequests;
    if (requests == null || requests.isEmpty) return;
    _statusFlag = statusFlag.setFlag(asFutureCompletedBit);
    final length = requests.length;
    // Use indexed loop for better performance
    for (var index = 0; index < length; index++) {
      requests[index].completeError(error, stackTrace);
    }
    requests.clear();
  }
}

@internal
final class AsFutureRequest<E> {
  final Completer<E> completer;
  final E? futureValue;

  AsFutureRequest({required this.futureValue, required this.completer});

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
