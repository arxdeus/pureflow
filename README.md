# Pureflow

[![Codecheck](https://github.com/arxdeus/pureflow/actions/workflows/code_check.yaml/badge.svg?branch=main)](https://github.com/arxdeus/pureflow/actions/workflows/code_check.yaml)
[![Dependabot Updates](https://github.com/arxdeus/pureflow/actions/workflows/dependabot/dependabot-updates/badge.svg?branch=main)](https://github.com/arxdeus/pureflow/actions/workflows/dependabot/dependabot-updates)

**`pureflow`**: [![pureflow](https://img.shields.io/pub/v/pureflow.svg)](https://pub.dev/packages/pureflow)


**`pureflow_flutter`**: [![pureflow_flutter](https://img.shields.io/pub/v/pureflow_flutter.svg)](https://pub.dev/packages/pureflow_flutter)

A Pipeline-first reactive state toolkit for Dart and Flutter

Pureflow starts from the problem most UI state libraries leave to you: async work. A `Pipeline` lets you choose how tasks run — sequentially, restartably, droppably, or concurrently — while `Store`, `Computed`, and batching keep the resulting state small and predictable.

---

## Features

- **🎛️ Pipeline-first async** - Make concurrency policy explicit for searches, saves, background jobs, and event flows
- **🔁 Built-in task strategies** - Use `sequential()`, `restartable()`, `droppable()`, or `concurrent()` without writing stream plumbing
- **🎯 Type-safe state** - Model values with `Store<T>` and derive read-only state with `Computed<T>`
- **🔗 Automatic dependency tracking** - Computed values track exactly what they read
- **🔄 Batching** - Group multiple state updates into a single notification
- **⚡ Lightweight listener system** - Linked list-based listener management with low allocation overhead
- **🌊 Stream integration** - Every reactive value is also a `Stream`

---

## Installation

Add Pureflow to your `pubspec.yaml`:

```yaml
dependencies:
  pureflow: ^1.1.0
```

For Flutter projects use instead:

```yaml
dependencies:
  pureflow_flutter: ^1.0.1
```

---

## Core Concepts

### Pipeline (Controlled Async)

`Pipeline` is the main entry point when user actions can overlap: search boxes,
save buttons, auth refreshes, uploads, and background jobs. Instead of hiding
concurrency in callbacks, Pureflow makes the policy part of the object you run
work through.

```dart
import 'package:pureflow/pureflow.dart';

// Latest search wins; older in-flight searches are marked inactive.
final searchPipeline = Pipeline(transformer: restartable());

final results = await searchPipeline.run((context) async {
  final response = await fetchSearchResults('flutter');

  if (!context.isActive) return null; // Ignore stale work.
  return response.items;
});
```

#### Choose how tasks overlap

The `transformer` parameter defines what happens when new work arrives before
previous work finishes:

```dart
// Process one task at a time.
final sequentialPipeline = Pipeline(transformer: sequential());

// Keep only the latest task active.
final restartablePipeline = Pipeline(transformer: restartable());

// Ignore new tasks while one is running.
final droppablePipeline = Pipeline(transformer: droppable());

// Let every task run immediately.
final concurrentPipeline = Pipeline(transformer: concurrent());
```

For advanced use cases, you can still pass any custom `EventTransformer` to
`Pipeline`.

#### Cancellation pattern

Tasks receive a `PipelineEventContext`. Check `context.isActive` before
expensive follow-up work or before applying results to state:

```dart
await searchPipeline.run((context) async {
  final data = await fetchData();
  if (!context.isActive) return null;

  return processData(data);
});
```

#### Graceful disposal

Pipeline supports both graceful and forced shutdown:

```dart
// Wait for all tasks to finish.
await searchPipeline.dispose();

// Cancel immediately.
await searchPipeline.dispose(force: true);
```

#### Bloc-style typed events

`Pipeline` runs untyped `Future Function(ctx)` tasks. If you want a `bloc`-like
ergonomic — an abstract event hierarchy plus per-subtype handlers registered
via `on<T>(...)` — you can wrap `Pipeline` in a small router that keeps a
table of `(type, handler)` registrations and dispatches incoming events to
the matching handler. The router still relies on a single `EventTransformer`,
so concurrency policy applies uniformly to every event subtype.

```dart
sealed class CounterEvent {}
class Incremented extends CounterEvent { final int by; const Incremented(this.by); }
class Reset       extends CounterEvent { const Reset(); }

final events = EventPipeline<CounterEvent>(
  transformer: (source, process) => source.asyncExpand(process),
);

events.on<Incremented>((event, ctx) async => counter.update((v) => v + event.by));
events.on<Reset>      ((event, ctx) async => counter.value = 0);

await events.add(const Incremented(2));
await events.add(const Reset());
```

Runnable, self-contained examples ship in this repo:

- [`example/typed_event_pipeline.dart`](example/typed_event_pipeline.dart) —
  the `EventPipeline<E>` abstraction plus a counter feature with a sealed
  event hierarchy and a sequential transformer.

---

### Store

`Store` is a reactive container for a single mutable value. When the value changes, all listeners and dependent computeds are automatically notified.

```dart
import 'package:pureflow/pureflow.dart';

// Create a store with an initial value
final counter = Store<int>(0);

// Read the current value
print(counter.value); // 0

// Listen to changes
counter.addListener(() {
  print('Counter changed to: ${counter.value}');
});

// Update the value
counter.value = 1; // Prints: Counter changed to: 1

// Update using a function
counter.update((current) => current + 1); // Prints: Counter changed to: 2
```

#### Equality Checking

Store performs smart equality checking to avoid unnecessary notifications:

```dart
final counter = Store<int>(1);
counter.value = 1; // No notification - same value
counter.value = 2; // Notification triggered
```

You can provide a custom equality function for advanced use cases:

```dart
// Deep list comparison
final items = Store<List<int>>([1, 2, 3],
  equality: (a, b) => listEquals(a, b),
);

// Custom object comparison
final user = Store<User>(User(name: 'Alice'),
  equality: (a, b) => a.name == b.name && a.id == b.id,
);
```

#### Stream Support

Every `Store` and `Computed` is also a `Stream`, making it compatible with `StreamBuilder` and other stream-based APIs:

```dart
final name = Store<String>('Alice');

// Subscribe to changes
final sub = name.listen((value) {
  print('Name is now: $value');
});
```

---

### Computed (Derived State)

`Computed` creates derived values that automatically track their dependencies and lazily recompute when those dependencies change.

```dart
final firstName = Store<String>('John');
final lastName = Store<String>('Doe');

// Computed automatically tracks firstName and lastName as dependencies
final fullName = Computed(() => '${firstName.value} ${lastName.value}');

print(fullName.value); // John Doe

firstName.value = 'Jane';
print(fullName.value); // Jane Doe (automatically recomputed)
```

#### Lazy Evaluation

Computations are lazy - they only run when their value is accessed:

```dart
final expensive = Computed(() {
  print('Computing...');
  return someExpensiveCalculation();
});

// Nothing printed yet - computation hasn't run

print(expensive.value); // Prints "Computing..." then the result
print(expensive.value); // Returns cached value, no recomputation
```

#### Chained Computeds

Computed values can depend on other computed values, creating a reactive computation graph:

```dart
final items = Store<List<int>>([1, 2, 3, 4, 5]);
final doubled = Computed(() => items.value.map((x) => x * 2).toList());
final sum = Computed(() => doubled.value.reduce((a, b) => a + b));

print(sum.value); // 30

items.value = [1, 2, 3];
print(sum.value); // 12 (both doubled and sum recomputed)
```

#### Custom Equality in Computed

You can provide a custom equality function to prevent notifications when the computed value hasn't actually changed:

```dart
final items = Store<List<int>>([1, 2, 3]);

// Without custom equality: creates new list each time, triggers notifications
final filtered = Computed(() => items.value.where((x) => x > 0).toList());

// With custom equality: only notifies if list contents actually changed
final filteredWithequality = Computed(
  () => items.value.where((x) => x > 0).toList(),
  equality: (a, b) => listEquals(a, b),
);
```

#### Conditional Dependencies

Dependencies are tracked per-computation, so conditional access works correctly:

```dart
final useMetric = Store<bool>(true);
final celsius = Store<double>(20.0);
final fahrenheit = Store<double>(68.0);

final temperature = Computed(() {
  if (useMetric.value) {
    return '${celsius.value}°C';  // Only celsius tracked
  } else {
    return '${fahrenheit.value}°F';  // Only fahrenheit tracked
  }
});
```

---

### Batching

Multiple store updates can be batched to defer notifications until all updates are complete. This improves performance and prevents intermediate inconsistent states from being observed.

```dart
final firstName = Store<String>('');
final lastName = Store<String>('');
final fullName = Computed(() => '${firstName.value} ${lastName.value}'.trim());

// Without batching: 2 notifications, fullName accessed mid-update
firstName.value = 'John';  // Notification 1: fullName = "John"
lastName.value = 'Doe';    // Notification 2: fullName = "John Doe"

// With batching: 1 notification after both updates
batch(() {
  firstName.value = 'Jane';
  lastName.value = 'Smith';
}); // Single notification: fullName = "Jane Smith"
```

#### Nested Batches

Batches can be nested. Notifications are only sent when the outermost batch completes:

```dart
batch(() {
  counter.value = 1;
  batch(() {
    counter.value = 2;
  }); // No notification yet
  counter.value = 3;
}); // Single notification with value 3
```

#### Return Values

`batch` returns the value from the action function:

```dart
final result = batch(() {
  firstName.value = 'John';
  lastName.value = 'Doe';
  return fullName.value;
});
print(result); // John Doe
```

### Real-world examples

- [`example/search_as_you_type.dart`](example/search_as_you_type.dart) —
  restartable search; run with `dart run example/search_as_you_type.dart`.
- [`example/form_validation.dart`](example/form_validation.dart) — reactive
  form validation; run with `dart run example/form_validation.dart`.
- [`example/cart_controller.dart`](example/cart_controller.dart) — shopping cart
  controller with read-only state; run with `dart run example/cart_controller.dart`.
- [`example/auth_session.dart`](example/auth_session.dart) — auth/session state
  with an async pipeline; run with `dart run example/auth_session.dart`.

Use the transformer helper style when choosing concurrency:

```dart
final search = Pipeline(transformer: restartable());
```

---

## Flutter Integration

The `pureflow_flutter` package provides seamless integration with Flutter's widget system through zero-overhead adapters.

### Installation

```yaml
dependencies:
  pureflow_flutter: ^1.0.1
```

### Usage with ValueListenableBuilder

The `asListenable` extension converts any `Store` or `Computed` to a Flutter `ValueListenable`:

```dart
// From any stateful piece of your code
final counter = Store<int>(0);

// Inside of any widget `build` method
@override
Widget build(BuildContext context) {
  return ValueListenableBuilder<int>(
    valueListenable: counter.asListenable,
    builder: (context, value, child) {
      return Text('Count: $value');
    },
  );
}

```

### Usage with AnimatedBuilder

Since `ValueListenable` extends `Listenable`, you can use Pureflow with any widget that accepts a `Listenable`:

```dart
AnimatedBuilder(
  animation: counter.asListenable,
  builder: (context, child) => Text('${counter.value}'),
);
```

### Computed Values in Flutter

Computed values work seamlessly with Flutter widgets:

```dart
final firstName = Store<String>('John');
final lastName = Store<String>('Doe');
final fullName = Computed(() => '${firstName.value} ${lastName.value}');

// In widget
ValueListenableBuilder<String>(
  valueListenable: fullName.asListenable,
  builder: (context, name, child) => Text('Hello, $name!'),
);
```

### Zero-Overhead Adapter

The `ValueObservableAdapter` adapter is designed for maximum efficiency:

- **No allocation per access** - Instances are cached and bound using `Expando`
- **Direct delegation** - All operations forward to Pureflow's listener system
- **Cached instances** - Same source always returns the same adapter

```dart
final store = Store<int>(0);
print(identical(store.asListenable, store.asListenable)); // true
```

---

## Performance

Pureflow is engineered for maximum performance:

| Feature | Benefit |
|---------|---------|
| **Linked List Listeners** | O(1) add/remove, zero allocation |
| **Lazy Computation** | Only compute when accessed |
| **Dirty Tracking** | Skip unchanged dependencies |
| **Pooled Nodes** | Reduced GC pressure |
| **Batch Updates** | Minimize notification overhead |

In benchmarks, Pureflow outperforms popular packages almost across all operations. See [BENCHMARK_README.md](benchmark/README.md) for detailed performance comparisons.

---

## License

MIT License - see [LICENSE](LICENSE) for details.
