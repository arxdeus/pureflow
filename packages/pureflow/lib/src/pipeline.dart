import 'package:pureflow/src/implementation/pipeline/pipeline.dart';

export 'implementation/pipeline/pipeline.dart' show PipelineEventContext;

/// A function that transforms a stream of events using a processing function.
///
/// [EventTransformer] defines the concurrency strategy for processing events
/// in a [Pipeline]. It receives a source stream of events and a process function,
/// and returns a stream of results.
///
/// ## Type Parameters
/// - [E]: The type of input events
/// - [R]: The type of output results
///
/// ## Parameters
/// - `source`: The stream of incoming events to process
/// - `process`: A function that transforms each event into a stream of results
///
/// ## Common Transformers
///
/// ### Sequential (one at a time)
/// ```dart
/// Stream<R> sequential<E, R>(Stream<E> source, Stream<R> Function(E) process) {
///   return source.asyncExpand(process);
/// }
/// ```
///
/// ### Concurrent (all at once)
/// ```dart
/// Stream<R> concurrent<E, R>(Stream<E> source, Stream<R> Function(E) process) {
///   return source.flatMap(process);
/// }
/// ```
///
/// ### Droppable (skip while processing)
/// ```dart
/// Stream<R> droppable<E, R>(Stream<E> source, Stream<R> Function(E) process) {
///   return source.exhaustMap(process);
/// }
/// ```
///
/// ### Restartable (cancel previous)
/// ```dart
/// Stream<R> restartable<E, R>(Stream<E> source, Stream<R> Function(E) process) {
///   return source.switchMap(process);
/// }
/// ```
///
/// ## Usage with Pipeline
///
/// ```dart
/// final pipeline = Pipeline(
///   transformer: (source, process) => source.asyncExpand(process),
/// );
/// ```
typedef EventTransformer<E, R> = Stream<R> Function(
  Stream<E> source,
  Stream<R> Function(E event) process,
);

/// A function that maps a single event to a stream of results.
///
/// [EventMapper] is used internally by [EventTransformer] to process
/// individual events. It receives an event and returns a stream that
/// may emit zero, one, or multiple results.
///
/// ## Type Parameters
/// - [E]: The type of the input event
/// - [R]: The type of output results
///
/// ## Example
///
/// ```dart
/// EventMapper<int, String> mapper = (int event) async* {
///   yield 'Processing $event';
///   await Future.delayed(Duration(seconds: 1));
///   yield 'Completed $event';
/// };
/// ```
typedef EventMapper<E, R> = Stream<R> Function(E event);

/// A pipeline for executing asynchronous tasks with controlled concurrency.
///
/// [Pipeline] provides a structured way to run async operations with
/// customizable event transformation strategies. It's particularly useful for:
/// - Rate limiting API calls
/// - Ensuring sequential execution of dependent operations
/// - Implementing search-as-you-type with automatic cancellation
/// - Managing concurrent background tasks
///
/// ## Features
///
/// - **Configurable concurrency**: Use different transformers for sequential,
///   concurrent, droppable, or restartable execution
/// - **Cancellation support**: Tasks can check if they should continue via
///   [PipelineEventContext.isActive]
/// - **Graceful shutdown**: [dispose] waits for active tasks or cancels them
/// - **Type-safe results**: Each task returns a typed Future
///
/// ## Basic Usage
///
/// ```dart
/// // Create a pipeline with sequential execution
/// final pipeline = Pipeline(
///   transformer: (source, process) => source.asyncExpand(process),
/// );
///
/// // Run tasks through the pipeline
/// final result = await pipeline.run((context) async {
///   // Check if still active before expensive operations
///   if (!context.isActive) return null;
///
///   final data = await fetchData();
///   return processData(data);
/// });
/// ```
///
/// ## Cancellation Pattern
///
/// ```dart
/// await pipeline.run((context) async {
///   for (final item in items) {
///     if (!context.isActive) {
///       // Pipeline is being disposed or task was superseded
///       return null;
///     }
///     await processItem(item);
///   }
///   return 'Done';
/// });
/// ```
///
/// ## With bloc_concurrency Transformers
///
/// ```dart
/// import 'package:bloc_concurrency/bloc_concurrency.dart';
///
/// // Only process latest event, cancel previous
/// final searchPipeline = Pipeline(transformer: restartable());
///
/// // Process one at a time, drop events while busy
/// final savePipeline = Pipeline(transformer: droppable());
/// ```
abstract class Pipeline {
  /// Creates a new [Pipeline] with the specified event transformer.
  ///
  /// The [transformer] determines how multiple concurrent tasks are handled.
  /// Common strategies include sequential processing, parallel execution,
  /// dropping events while busy, or cancelling previous operations.
  ///
  /// ## Parameters
  /// - [transformer]: A function that defines the concurrency strategy.
  ///
  /// ## Example
  /// ```dart
  /// // Sequential processing
  /// final pipeline = Pipeline(
  ///   transformer: (source, process) => source.asyncExpand(process),
  /// );
  ///
  /// // Using bloc_concurrency
  /// final pipeline = Pipeline(transformer: sequential());
  /// ```
  factory Pipeline({
    required EventTransformer<dynamic, dynamic> transformer,
  }) = PipelineImpl;

  /// Runs an asynchronous task through the pipeline.
  ///
  /// The task is queued according to the pipeline's transformer strategy.
  /// It receives a [PipelineEventContext] that provides:
  /// - [PipelineEventContext.isActive]: Whether the task should continue
  /// - [PipelineEventContext.isCancelled]: Whether the task was explicitly cancelled
  ///
  /// ## Type Parameters
  /// - [R]: The return type of the task
  ///
  /// ## Parameters
  /// - [task]: An async function that receives a context and returns a result.
  ///
  /// ## Returns
  /// A [Future] that completes with the task's result when the task finishes.
  ///
  /// ## Example
  /// ```dart
  /// final result = await pipeline.run<User>((context) async {
  ///   final response = await api.fetchUser(userId);
  ///
  ///   if (!context.isActive) {
  ///     throw CancelledException();
  ///   }
  ///
  ///   return User.fromJson(response.data);
  /// });
  /// ```
  ///
  /// ## Error Handling
  ///
  /// If the task throws an exception, the Future completes with that error.
  /// The pipeline continues to function normally for subsequent tasks.
  ///
  /// ```dart
  /// try {
  ///   await pipeline.run((context) async {
  ///     throw Exception('Task failed');
  ///   });
  /// } catch (e) {
  ///   print('Caught: $e');
  /// }
  /// ```
  Future<R> run<R>(
    Future<R> Function(PipelineEventContext context) task,
  );

  /// Disposes the pipeline and releases all resources.
  ///
  /// ## Parameters
  /// - [force]: If `true`, all active tasks are immediately marked as inactive
  ///   and the method returns quickly. If `false` (default), the method waits
  ///   for all active tasks to complete naturally.
  ///
  /// ## Returns
  /// A [Future] that completes when:
  /// - All active tasks have completed (if `force` is `false`)
  /// - Immediately after marking tasks inactive (if `force` is `true`)
  ///
  /// ## Graceful Shutdown (force: false)
  ///
  /// ```dart
  /// // Wait for all tasks to finish
  /// await pipeline.dispose();
  /// ```
  ///
  /// After calling dispose without force:
  /// - New tasks can still be queued but won't start
  /// - Active tasks continue until completion
  /// - [PipelineEventContext.isActive] returns `false` for new checks
  ///
  /// ## Forced Shutdown (force: true)
  ///
  /// ```dart
  /// // Cancel immediately
  /// await pipeline.dispose(force: true);
  /// ```
  ///
  /// With force:
  /// - All active tasks immediately see [PipelineEventContext.isActive] as `false`
  /// - Tasks should check `isActive` and return early
  /// - The Future completes without waiting
  ///
  /// ## Idempotent
  ///
  /// Calling [dispose] multiple times is safe; subsequent calls return
  /// immediately.
  Future<void> dispose({bool force = false});
}
