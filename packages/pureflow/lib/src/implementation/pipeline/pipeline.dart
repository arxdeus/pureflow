import 'dart:async';

import 'package:pureflow/src/internal/pipeline/task_stream.dart';
import 'package:pureflow/src/observer.dart';
import 'package:pureflow/src/pipeline.dart';

export 'pipeline_event_context.dart' show PipelineEventContext;

/// EventMapper transforms a single event into a stream of results.

/// Pipeline processes tasks through a unified event bus with transformation.

class PipelineImpl implements Pipeline {
  final TaskStream _taskStream;

  @override
  final String? debugLabel;

  PipelineImpl({
    required EventTransformer<dynamic, dynamic> transformer,
    this.debugLabel,
  }) : _taskStream = TaskStream(transformer: transformer) {
    final observer = Pureflow.observer;
    if (observer != null && observer.onCreated != null) {
      try {
        observer.onCreated!(debugLabel, FlowKind.pipeline);
      } catch (_) {}
    }
  }

  /// Runs a task through the pipeline event bus.
  /// The task receives a PipelineEventContext object that provides access
  /// to the `isActive` getter.
  @override
  @pragma('vm:prefer-inline')
  Future<R> run<R>(
    Future<R> Function(PipelineEventContext context) task, {
    String? debugLabel,
  }) {
    final observer = Pureflow.observer;
    if (observer != null && observer.onPipelineEvent != null) {
      try {
        observer.onPipelineEvent!(this.debugLabel, debugLabel);
      } catch (_) {}
    }

    final completer = Completer<R>.sync();
    _taskStream.add(
      PipelineEventContext(
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
  @override
  @pragma('vm:prefer-inline')
  Future<void> dispose({bool force = false}) =>
      _taskStream.dispose(force: force);
}
