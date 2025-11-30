import 'dart:async';

import '../../internal/pipeline/task_stream.dart';

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
/// 3. **Explicit cancellation**: The task's [cancel] method was called
///
/// ## Properties
///
/// - [isActive]: Combined check - task not cancelled AND pipeline active
/// - [isCancelled]: Whether this specific task was cancelled
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
  ///
  /// This is the function passed to `Pipeline.run` that performs the actual
  /// work. It receives this context as a parameter.
  final Future<dynamic> Function(PipelineEventContext context) task;

  /// The completer that will be completed with the task's result.
  ///
  /// This completer is used internally to bridge the async task execution
  /// with the Future returned by `Pipeline.run`.
  final Completer<dynamic> completer;

  final TaskStream _taskStream;

  bool _isCancelled = false;

  /// Creates a new pipeline event context.
  ///
  /// This constructor is internal to the pipeline implementation.
  /// Users receive contexts through `Pipeline.run` callbacks.
  ///
  /// ## Parameters
  /// - [task]: The async function to execute
  /// - [completer]: The completer to signal completion
  /// - [taskStream]: Reference to the pipeline's task stream for checking active state
  PipelineEventContext({
    required this.task,
    required this.completer,
    required TaskStream taskStream,
  }) : _taskStream = taskStream;

  /// Returns whether this task is still active and should continue execution.
  ///
  /// A task is active when:
  /// - It has not been explicitly cancelled via [cancel]
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

  /// Returns whether this specific task has been cancelled.
  ///
  /// Unlike [isActive], this only checks if [cancel] was called on this
  /// context, not whether the pipeline itself is still active.
  ///
  /// ## Returns
  /// `true` if [cancel] was called, `false` otherwise.
  ///
  /// ## Use Cases
  ///
  /// Use [isCancelled] when you need to distinguish between:
  /// - Task cancelled by transformer (e.g., newer task superseded this one)
  /// - Pipeline being disposed
  ///
  /// In most cases, [isActive] is preferred as it handles both scenarios.
  ///
  /// ## Example
  /// ```dart
  /// await pipeline.run((context) async {
  ///   final result = await doWork();
  ///
  ///   if (context.isCancelled) {
  ///     // This task was specifically cancelled
  ///     log.info('Task cancelled, discarding result');
  ///   } else if (!context.isActive) {
  ///     // Pipeline is shutting down
  ///     log.info('Pipeline disposing');
  ///   }
  ///
  ///   return result;
  /// });
  /// ```
  @pragma('vm:prefer-inline')
  bool get isCancelled => _isCancelled;

  /// Marks this task as cancelled.
  ///
  /// After calling this method:
  /// - [isCancelled] returns `true`
  /// - [isActive] returns `false`
  ///
  /// This method is typically called by the pipeline's transformer when
  /// implementing cancellation strategies (e.g., restartable transformer
  /// cancelling the previous task when a new one arrives).
  ///
  /// ## Cooperative Cancellation
  ///
  /// Calling [cancel] does not forcefully stop the task. The task must
  /// cooperatively check [isActive] or [isCancelled] and return early.
  ///
  /// ## Idempotent
  ///
  /// Calling [cancel] multiple times is safe; subsequent calls have no effect.
  ///
  /// ## Example
  /// ```dart
  /// // In a custom transformer
  /// void onNewEvent(PipelineEventContext previousContext) {
  ///   previousContext.cancel(); // Cancel the previous task
  /// }
  /// ```
  @pragma('vm:prefer-inline')
  void cancel() => _isCancelled = true;
}
