import 'dart:async';

import 'package:pureflow/src/impl/pipeline/pipeline_event_context.dart';
import 'package:pureflow/src/interface/pipeline/interfaces.dart';
import 'package:pureflow/src/internal/pipeline/task_stream.dart';

export 'pipeline_event_context.dart' show PipelineEventContext;

/// EventMapper transforms a single event into a stream of results.

/// Pipeline processes tasks through a unified event bus with transformation.
class Pipeline {
  final TaskStream _taskStream;

  Pipeline({
    required EventTransformer<dynamic, dynamic> transformer,
  }) : _taskStream = TaskStream(transformer: transformer);

  /// Runs a task through the pipeline event bus.
  /// The task receives a PipelineEventContext object that provides access
  /// to the `isActive` getter.
  @pragma('vm:prefer-inline')
  Future<ResultType> run<ResultType>(
    Future<ResultType> Function(PipelineEventContext context) task,
  ) {
    final completer = Completer<ResultType>.sync();
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
  @pragma('vm:prefer-inline')
  Future<void> dispose({bool force = false}) =>
      _taskStream.dispose(force: force);
}
