# PureFlow

A high-performance reactive state management library for Dart and Flutter

PureFlow provides a minimal, fast, and type-safe reactive state management solution. It combines the simplicity of signals with the power of computed values and controlled async pipelines.

---

## Features

- **🚀 Blazing Fast** — Faster than most of the packages in all benchmarks
- **🎯 Type-Safe** — Full type inference with no runtime surprises
- **🔗 Automatic Dependency Tracking** — Computed values track dependencies automatically
- **📦 Lazy Evaluation** — Computations only run when accessed
- **🔄 Batching** — Group multiple updates into a single notification
- **⚡ Zero-Allocation Listeners** — Linked list-based listener management
- **🌊 Stream Integration** — Every reactive value is also a `Stream`
- **🎛️ Controlled Async** — Pipeline system for handling concurrency of async operations

---

## Installation

Add PureFlow to your `pubspec.yaml`:

```yaml
dependencies:
  pureflow: ^1.0.0
```

For Flutter projects use instead:

```yaml
dependencies:
  pureflow_flutter: ^1.0.0
```

---

## Core Concepts

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
  equality: (a, b) => listequality(a,b),
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
name.listen((value) {
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

Computations are lazy — they only run when their value is accessed:

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
  equality: (a, b) => listequality(a, b),
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
Store.batch(() {
  firstName.value = 'Jane';
  lastName.value = 'Smith';
}); // Single notification: fullName = "Jane Smith"
```

#### Nested Batches

Batches can be nested. Notifications are only sent when the outermost batch completes:

```dart
Store.batch(() {
  counter.value = 1;
  Store.batch(() {
    counter.value = 2;
  }); // No notification yet
  counter.value = 3;
}); // Single notification with value 3
```

#### Return Values

`Store.batch` returns the value from the action function:

```dart
final result = Store.batch(() {
  firstName.value = 'John';
  lastName.value = 'Doe';
  return fullName.value;
});
print(result); // John Doe
```

---

### Pipeline (Controlled Async)

`Pipeline` provides structured async task execution with customizable concurrency strategies. It's perfect for:

- Rate limiting API calls
- Ensuring sequential execution of dependent operations
- Implementing search-as-you-type with automatic cancellation
- Managing concurrent background tasks

```dart
// Create a pipeline with sequential execution
final pipeline = Pipeline(
  transformer: (source, process) => source.asyncExpand(process),
);

// Run tasks through the pipeline
final result = await pipeline.run((context) async {
  // Check if still active before expensive operations
  if (!context.isActive) return null;

  final data = await fetchData();
  return processData(data);
});
```

#### Concurrency Strategies

The `transformer` parameter defines how concurrent tasks are handled:

```dart
// Sequential: Process one at a time
Stream<R> sequential<E, R>(Stream<E> source, Stream<R> Function(E) process) {
  return source.asyncExpand(process);
}

// Droppable: Skip events while processing
Stream<R> droppable<E, R>(Stream<E> source, Stream<R> Function(E) process) {
  return source.exhaustMap(process);
}

// Restartable: Cancel previous, process latest
Stream<R> restartable<E, R>(Stream<E> source, Stream<R> Function(E) process) {
  return source.switchMap(process);
}

// Concurrent: Process all at once
Stream<R> concurrent<E, R>(Stream<E> source, Stream<R> Function(E) process) {
  return source.flatMap(process);
}
```

> 💡 **Tip**: The [bloc_concurrency](https://pub.dev/packages/bloc_concurrency) package provides ready-to-use transformers that work perfectly with Pipeline.

#### Cancellation Pattern

Tasks receive a `PipelineEventContext` that allows checking if the task should continue:

```dart
await pipeline.run((context) async {
  for (final item in items) {
    if (!context.isActive) {
      // Pipeline is being disposed or task was superseded
      return null;
    }
    await processItem(item);
  }
  return 'Done';
});
```

#### Graceful Disposal

Pipeline supports both graceful and forced shutdown:

```dart
// Wait for all tasks to finish
await pipeline.dispose();

// Cancel immediately
await pipeline.dispose(force: true);
```

---

## Real-World Example

Here's a complete authentication controller example:

```dart
class AuthenticationController {
  AuthenticationController() {
    // Restartable: cancels previous login when new one starts
    _pipeline = Pipeline(
      transformer: (source, process) => source.switchMap(process),
    );
  }

  late final Pipeline _pipeline;

  // Reactive State
  final _user = Store<User?>(null);
  final _isLoading = Store<bool>(false);
  final _error = Store<String?>(null);

  // Computed Properties
  late final isAuthenticated = Computed(() => _user.value != null);

  late final statusMessage = Computed(() {
    if (_isLoading.value) return 'Loading...';
    if (_error.value != null) return 'Error: ${_error.value}';
    if (isAuthenticated.value) return 'Welcome, ${_user.value!.name}!';
    return 'Please log in';
  });

  // Actions
  Future<User> login(String email, String password) {
    return _pipeline.run((context) async {
      _error.value = null;
      _isLoading.value = true;

      try {
        final user = await api.login(email, password);
        if (!context.isActive) {
          return;
        }
        // Update state atomically
        Store.batch(() {
          _user.value = user;
          _isLoading.value = false;
        });

        return user;
      } catch (e) {
        if (context.isActive) {
          Store.batch(() {
            _error.value = e.toString();
            _isLoading.value = false;
          });
        }
        rethrow;
      }
    });
  }

  Future<void> dispose() async {
    await _pipeline.dispose(force: true);
    _user.dispose();
    _isLoading.dispose();
    _error.dispose();
    isAuthenticated.dispose();
    statusMessage.dispose();
  }
}
```

---

## Performance

PureFlow is engineered for maximum performance:

| Feature | Benefit |
|---------|---------|
| **Linked List Listeners** | O(1) add/remove, zero allocation |
| **Lazy Computation** | Only compute when accessed |
| **Dirty Tracking** | Skip unchanged dependencies |
| **Pooled Nodes** | Reduced GC pressure |
| **Batch Updates** | Minimize notification overhead |

In benchmarks, PureFlow outperforms popular packages almost across all operations.

---

## Flutter Integration

The `pureflow_flutter` package provides seamless integration with Flutter's widget system through zero-overhead adapters.

### Installation

```yaml
dependencies:
  pureflow_flutter: ^1.0.0
```

### Usage with ValueListenableBuilder

The `asListenable` extension converts any `Store` or `Computed` to a Flutter `ValueListenable`:

```dart
import 'package:pureflow/pureflow.dart';
import 'package:pureflow_flutter/pureflow_flutter.dart';

class CounterPage extends StatelessWidget {
  final counter = Store<int>(0);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: counter.asListenable,
      builder: (context, value, child) {
        return Text('Count: $value');
      },
    );
  }
}
```

### Usage with AnimatedBuilder

Since `ValueListenable` extends `Listenable`, you can use PureFlow with any widget that accepts a `Listenable`:

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

The `ValueUnitListenable` adapter is designed for maximum efficiency:

- **No allocation per access** — Instances are cached and bound using `Expando`
- **Direct delegation** — All operations forward to PureFlow's listener system
- **Cached instances** — Same source always returns the same adapter

```dart
final store = Store<int>(0);
print(identical(store.asListenable, store.asListenable)); // true
```

---

## API Reference

### Store<T>

| Member | Description |
|--------|-------------|
| `Store(T value, {equality?})` | Create a new store with initial value and optional custom equality |
| `T value` | Get or set the current value |
| `update(T Function(T))` | Update value using a function |
| `addListener(VoidCallback)` | Register a change listener |
| `removeListener(VoidCallback)` | Remove a change listener |
| `listen(void Function(T))` | Subscribe as a stream |
| `dispose()` | Release resources |
| `static batch<R>(R Function())` | Batch multiple updates |

## License

MIT License — see [LICENSE](LICENSE) for details.
