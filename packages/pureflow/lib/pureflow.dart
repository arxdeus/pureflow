/// Pureflow - A high-performance reactive signals library for Dart and Flutter.
///
/// Pureflow provides a minimal, fast, and type-safe reactive state management
/// solution. It combines the simplicity of signals with the power of computed
/// values and controlled async pipelines.
///
/// ## Core Concepts
///
/// ### Store (Signal)
///
/// `Store` is a reactive container for a single mutable value. When the value
/// changes, all listeners and dependent computeds are automatically notified.
///
/// ```dart
/// final counter = Store<int>(0);
/// counter.addListener(() => print('Counter: ${counter.value}'));
/// counter.value = 1; // Prints: Counter: 1
/// ```
///
/// ### Computed (Derived State)
///
/// `Computed` creates derived values that automatically track their dependencies
/// and lazily recompute when those dependencies change.
///
/// ```dart
/// final firstName = Store<String>('John');
/// final lastName = Store<String>('Doe');
/// final fullName = Computed(() => '${firstName.value} ${lastName.value}');
///
/// print(fullName.value); // John Doe
/// firstName.value = 'Jane';
/// print(fullName.value); // Jane Doe (recomputed automatically)
/// ```
///
/// ### Batching
///
/// Multiple store updates can be batched to defer notifications until all
/// updates are complete:
///
/// ```dart
/// Store.batch(() {
///   firstName.value = 'Jane';
///   lastName.value = 'Smith';
/// }); // Single notification after both updates
/// ```
///
/// ### Pipeline (Controlled Async)
///
/// `Pipeline` provides structured async task execution with customizable
/// concurrency strategies:
///
/// ```dart
/// final pipeline = Pipeline(
///   transformer: (source, process) => source.asyncExpand(process),
/// );
///
/// await pipeline.run((context) async {
///   if (!context.isActive) return null;
///   return await fetchData();
/// });
/// ```
///
/// ## Performance
///
/// Pureflow is designed for maximum performance:
/// - Faster than signals_core in all benchmarks
/// - Zero-allocation listener management with linked lists
/// - Lazy computation with efficient dirty tracking
/// - Pooled dependency nodes to reduce GC pressure
///
/// ## Flutter Integration
///
/// See the `pureflow_flutter` package for Flutter-specific adapters:
///
/// ```dart
/// import 'package:pureflow_flutter/pureflow_flutter.dart';
///
/// ValueListenableBuilder<int>(
///   valueListenable: counter.asListenable,
///   builder: (context, value, child) => Text('$value'),
/// );
/// ```
library;

export 'src/computed.dart' show Computed;
export 'src/interfaces.dart' show Observable, ValueHolder;
export 'src/pipeline.dart'
    show EventMapper, EventTransformer, Pipeline, PipelineEventContext;
export 'src/store.dart' show Store;
