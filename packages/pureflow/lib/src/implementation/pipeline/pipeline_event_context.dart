import 'dart:async';

import 'package:meta/meta.dart';
import 'package:pureflow/src/internal/pipeline/task_stream.dart';

/// Context object passed to pipeline tasks providing access to cancellation state.
///
/// [PipelineEventContext] is the primary way for tasks running in a `Pipeline`
/// to check whether they should continue execution or abort early. This enables
/// cooperative cancellation where long-running tasks can periodically check
/// their status and exit gracefully.
///
/// ## Usage Pattern
///
/// Tasks should check [isActive] before and during expensive operations:
///
/// ```dart
/// await pipeline.run((context) async {
///   // Check before starting
///   if (!context.isActive) return null;
///
///   final data = await expensiveFetch();
///
///   // Check after each async operation
///   if (!context.isActive) return null;
///
///   return processData(data);
/// });
/// ```
///
/// ## Cancellation Reasons
///
/// A task becomes inactive when:
/// 1. **Pipeline disposed**: `Pipeline.dispose` was called
/// 2. **Task superseded**: A newer task cancelled this one (with restartable transformer)
/// 3. **Explicit cancellation**: The task was cancelled by the pipeline
///
/// ## Properties
///
/// - [isActive]: Combined check - task not cancelled AND pipeline active
///
/// ## Example with Loop
///
/// ```dart
/// await pipeline.run((context) async {
///   final results = <Item>[];
///
///   for (final id in itemIds) {
///     // Exit loop early if cancelled
///     if (!context.isActive) break;
///
///     final item = await fetchItem(id);
///     results.add(item);
///   }
///
///   return results;
/// });
/// ```
final class PipelineEventContext {
  /// The async task function to be executed.
  @internal
  final Future<dynamic> Function(PipelineEventContext context) task;

  /// The completer that will be completed with the task's result.
  @internal
  final Completer<dynamic> completer;

  final TaskStream _taskStream;

  bool _isCancelled = false;

  /// Creates a new pipeline event context.
  @internal
  PipelineEventContext({
    required this.task,
    required this.completer,
    required TaskStream taskStream,
  }) : _taskStream = taskStream;

  /// Returns whether this task is still active and should continue execution.
  ///
  /// A task is active when:
  /// - It has not been cancelled
  /// - The pipeline has not been disposed
  ///
  /// Tasks should check this property:
  /// - Before starting expensive operations
  /// - After each `await` in long-running operations
  /// - In loop iterations when processing multiple items
  ///
  /// ## Returns
  /// `true` if the task should continue, `false` if it should abort.
  ///
  /// ## Example
  /// ```dart
  /// await pipeline.run((context) async {
  ///   for (var i = 0; i < 1000; i++) {
  ///     if (!context.isActive) {
  ///       print('Cancelled at iteration $i');
  ///       return null;
  ///     }
  ///     await processItem(i);
  ///   }
  ///   return 'Completed all items';
  /// });
  /// ```
  ///
  /// ## Thread Safety
  ///
  /// This property can be safely read at any time during task execution.
  /// The value may change from `true` to `false` between reads if the
  /// pipeline is disposed or the task is cancelled.
  @pragma('vm:prefer-inline')
  bool get isActive => !_isCancelled && _taskStream.isActive;

  @internal
  @pragma('vm:prefer-inline')
  void cancel() => _isCancelled = true;
}
