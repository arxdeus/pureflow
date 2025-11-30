import 'dart:async';

import 'package:meta/meta.dart';
import 'package:pureflow/src/common/bit_flags.dart';
import 'package:pureflow/src/common/synchronous_future.dart';

import 'package:pureflow/src/internal/pipeline/task_stream.dart';

/// Bit flags for source stream subscription status.
const int srcCanceledBit = 1 << 0;
const int srcPausedBit = 1 << 1;
const int srcScheduledBit = 1 << 2;

/// Custom Stream implementation to replace async* generator.
/// Pulls events from TaskStream's queue on demand.
@internal
class SourceStream extends Stream<dynamic> {
  final TaskStream taskStream;

  SourceStream(this.taskStream);

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return SourceStreamSubscription(
      taskStream,
      onData,
      onDone,
    );
  }
}

/// Custom StreamSubscription for SourceStream.
@internal
class SourceStreamSubscription implements StreamSubscription<dynamic> {
  final TaskStream taskStream;
  void Function(dynamic event)? _onData;
  void Function()? _onDone;

  int _statusFlag = 0;
  Completer<void>? _resumeCompleter;

  SourceStreamSubscription(
    this.taskStream,
    this._onData,
    this._onDone,
  ) {
    _scheduleNext();
  }

  void _scheduleNext() {
    // Prevent multiple scheduleMicrotask calls
    if (_statusFlag.hasFlag(srcScheduledBit)) return;
    if (_statusFlag.hasFlag(srcCanceledBit)) return;

    _statusFlag = _statusFlag.setFlag(srcScheduledBit);
    _processNext();
  }

  void _processNext() {
    _statusFlag = _statusFlag.clearFlag(srcScheduledBit);

    if (_statusFlag.hasFlag(srcCanceledBit)) return;

    // If paused, wait for resume
    if (_statusFlag.hasFlag(srcPausedBit)) return;

    // If stream is closed
    if (!taskStream.isActive) {
      _invokeDone();
      return;
    }

    // If queue is empty, wait for new events
    if (taskStream.eventQueue.isEmpty) {
      final completer =
          taskStream.waitingCompleter ??= Completer<void>.sync();
      completer.future.then((_) {
        if (!_statusFlag.hasFlag(srcCanceledBit)) {
          _scheduleNext();
        }
      });
      return;
    }

    // Get event from queue and emit
    final event = taskStream.eventQueue.removeFirst();

    _onData?.call(event);
    // Schedule next event processing
    _scheduleNext();
  }

  @pragma('vm:prefer-inline')
  void _invokeDone() => _onDone?.call();

  @override
  Future<void> cancel() {
    if (_statusFlag.hasFlag(srcCanceledBit)) {
      return const SynchronousFuture<void>(null);
    }
    _statusFlag = _statusFlag.setFlag(srcCanceledBit);
    _completeResumeCompleter();
    return const SynchronousFuture<void>(null);
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    if (_statusFlag.hasFlag(srcPausedBit | srcCanceledBit)) return;
    _statusFlag = _statusFlag.setFlag(srcPausedBit);
    resumeSignal?.whenComplete(resume);
  }

  @override
  void resume() {
    if (!_statusFlag.hasFlag(srcPausedBit)) return;
    _statusFlag = _statusFlag.clearFlag(srcPausedBit);
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
  bool get isPaused => _statusFlag.hasFlag(srcPausedBit);

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

