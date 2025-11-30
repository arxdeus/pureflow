import 'dart:async';

import 'package:pureflow/src/internal/pipeline/task_stream.dart';

/// Context object that provides access to the active status of a pipeline event.
/// Can be used directly as a parameter in pipeline tasks.
final class PipelineEventContext {
  final Future<dynamic> Function(PipelineEventContext context) task;
  final Completer<dynamic> completer;
  final TaskStream _taskStream;

  bool _isCancelled = false;

  PipelineEventContext({
    required this.task,
    required this.completer,
    required TaskStream taskStream,
  }) : _taskStream = taskStream;

  /// Returns whether the event is still active (not cancelled and pipeline active).
  @pragma('vm:prefer-inline')
  bool get isActive => !_isCancelled && _taskStream.isActive;

  /// Returns whether the event has been cancelled.
  @pragma('vm:prefer-inline')
  bool get isCancelled => _isCancelled;

  @pragma('vm:prefer-inline')
  void cancel() => _isCancelled = true;
}
