# Pureflow Flutter

[![pureflow_flutter](https://img.shields.io/pub/v/pureflow_flutter.svg)](https://pub.dev/packages/pureflow_flutter)
[![Codecheck](https://github.com/arxdeus/pureflow/actions/workflows/code_check.yaml/badge.svg?branch=main)](https://github.com/arxdeus/pureflow/actions/workflows/code_check.yaml)

Zero-overhead Flutter integration for Pureflow reactive state management.

This package provides seamless integration between Pureflow's reactive system and Flutter's widget layer through lightweight adapters that work with `ValueListenableBuilder`, `AnimatedBuilder`, and other Flutter widgets.

---

## Installation

Add `pureflow_flutter` to your `pubspec.yaml`:

```yaml
dependencies:
  pureflow_flutter: ^1.0.0
```

> **Note**: `pureflow_flutter` automatically includes `pureflow` as a dependency. For core concepts and API documentation, see the [pureflow package](https://pub.dev/packages/pureflow).

---

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:pureflow_flutter/pureflow_flutter.dart';

class CounterPage extends StatelessWidget {
  final counter = Store<int>(0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: ValueListenableBuilder<int>(
          valueListenable: counter.asListenable,
          builder: (context, value, child) {
            return Text('Count: $value');
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

---

## Flutter Integration

### The `asListenable` Extension

The core feature of `pureflow_flutter` is the `asListenable` extension that converts any `Store` or `Computed` to a Flutter `ValueListenable`:

```dart
final counter = Store<int>(0);
final listenable = counter.asListenable; // Returns ValueListenable<int>
```

### Using with ValueListenableBuilder

The most common way to use Pureflow in Flutter widgets:

```dart
class MyWidget extends StatelessWidget {
  final counter = Store<int>(0);
  final multiplier = Store<int>(1);

  late final result = Computed(() => counter.value * multiplier.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: counter.asListenable,
          builder: (context, value, child) {
            return Text('Counter: $value');
          },
        ),
        ValueListenableBuilder<int>(
          valueListenable: result.asListenable,
          builder: (context, value, child) {
            return Text('Result: $value');
          },
        ),
      ],
    );
  }
}
```

### Using with AnimatedBuilder

Since `ValueListenable` extends `Listenable`, you can use it with any widget that accepts a `Listenable`:

```dart
AnimatedBuilder(
  animation: counter.asListenable,
  builder: (context, child) {
    return Text('${counter.value}');
  },
);
```

### Using with StreamBuilder

Every `Store` and `Computed` is also a `Stream`, so you can use `StreamBuilder`:

```dart
StreamBuilder<int>(
  stream: counter,
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const CircularProgressIndicator();
    }
    return Text('Count: ${snapshot.data}');
  },
);
```

---

## Flutter-Specific Patterns

### StatefulWidget with Controller

For more complex state management, use a controller pattern:

```dart
class CounterController {
  final counter = Store<int>(0);
  final multiplier = Store<int>(1);

  late final doubled = Computed(() => counter.value * 2);
  late final result = Computed(() => counter.value * multiplier.value);

  void increment() => counter.value++;
  void decrement() => counter.value--;

  void dispose() {
    counter.dispose();
    multiplier.dispose();
    doubled.dispose();
    result.dispose();
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  late final controller = CounterController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: controller.counter.asListenable,
            builder: (context, value, child) {
              return Text('Counter: $value');
            },
          ),
          ValueListenableBuilder<int>(
            valueListenable: controller.result.asListenable,
            builder: (context, value, child) {
              return Text('Result: $value');
            },
          ),
          ElevatedButton(
            onPressed: controller.increment,
            child: const Text('Increment'),
          ),
        ],
      ),
    );
  }
}
```

### Batching Updates to Minimize Rebuilds

Use `batch` to update multiple stores and trigger a single rebuild:

```dart
// Without batching: triggers 2 rebuilds
firstName.value = 'John';
lastName.value = 'Doe';

// With batching: triggers 1 rebuild
batch(() {
  firstName.value = 'John';
  lastName.value = 'Doe';
});
```

### Custom Equality for Collections

When storing collections, use custom equality to avoid unnecessary rebuilds:

```dart
import 'package:flutter/foundation.dart';

final items = Store<List<int>>([1, 2, 3],
  equality: (a, b) => listEquals(a, b),
);

// This won't trigger a rebuild if contents are the same
items.value = [1, 2, 3]; // No rebuild
items.value = [1, 2, 4]; // Rebuild triggered
```

### Conditional Rendering

Use computed values for conditional UI:

```dart
class AuthWidget extends StatelessWidget {
  final _isLoading = Store<bool>(false);
  final _user = Store<User?>(null);

  late final isAuthenticated = Computed(() => _user.value != null);
  late final showLoading = Computed(() => _isLoading.value);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: showLoading.asListenable,
      builder: (context, loading, child) {
        if (loading) return const CircularProgressIndicator();

        return ValueListenableBuilder<bool>(
          valueListenable: isAuthenticated.asListenable,
          builder: (context, authenticated, child) {
            if (authenticated) {
              return const Text('Welcome!');
            }
            return const LoginForm();
          },
        );
      },
    );
  }
}
```

---

## Zero-Overhead Adapter

The `ValueObservableAdapter` is designed for maximum efficiency:

- **No allocation per access** - Instances are cached using `Expando`
- **Direct delegation** - All operations forward to Pureflow's listener system
- **Cached instances** - Same source always returns the same adapter instance

```dart
final store = Store<int>(0);
final a = store.asListenable;
final b = store.asListenable;
print(identical(a, b)); // true - same instance
```

This means you can safely call `asListenable` multiple times without performance concerns.

---

## Complete Example

Here's a complete Flutter app example:

```dart
import 'package:flutter/material.dart';
import 'package:pureflow_flutter/pureflow_flutter.dart';

class CounterController {
  final counter = Store<int>(0);
  final multiplier = Store<int>(1);

  late final doubled = Computed(() => counter.value * 2);
  late final result = Computed(() => counter.value * multiplier.value);

  final pipeline = Pipeline(
    transformer: (source, process) => source.asyncExpand(process),
  );

  void increment() => counter.value++;
  void decrement() => counter.value--;
  void incrementMultiplier() => multiplier.value++;
  void decrementMultiplier() => multiplier.value--;

  Future<String> addTenAsync() {
    return pipeline.run((context) async {
      if (!context.isActive) return 'Cancelled';
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!context.isActive) return 'Cancelled during operation';
      counter.value = counter.value + 10;
      return 'Added 10 to counter';
    });
  }

  void dispose() {
    counter.dispose();
    multiplier.dispose();
    doubled.dispose();
    result.dispose();
    pipeline.dispose();
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  late final controller = CounterController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pureflow Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: controller.counter.asListenable,
              builder: (context, value, child) {
                return Text(
                  'Counter: $value',
                  style: Theme.of(context).textTheme.headlineMedium,
                );
              },
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<int>(
              valueListenable: controller.doubled.asListenable,
              builder: (context, value, child) {
                return Text(
                  'Doubled: $value',
                  style: Theme.of(context).textTheme.headlineSmall,
                );
              },
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<int>(
              valueListenable: controller.result.asListenable,
              builder: (context, value, child) {
                return Text(
                  'Counter × Multiplier: $value',
                  style: Theme.of(context).textTheme.headlineSmall,
                );
              },
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: controller.decrement,
                  child: const Text('-'),
                ),
                const SizedBox(width: 20),
                ElevatedButton(
                  onPressed: controller.increment,
                  child: const Text('+'),
                ),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final result = await controller.addTenAsync();
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text(result)));
              },
              child: const Text('Add 10 (async)'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Best Practices

### 1. Always Dispose Resources

Dispose stores, computeds, and pipelines in your widget's `dispose` method:

```dart
class _MyWidgetState extends State<MyWidget> {
  late final counter = Store<int>(0);
  late final doubled = Computed(() => counter.value * 2);

  @override
  void dispose() {
    counter.dispose();
    doubled.dispose();
    super.dispose();
  }
}
```

### 2. Use Controllers for Complex State

For complex state management, extract logic into a controller class:

```dart
class MyController {
  final _state = Store<MyState>(MyState.initial());
  // ... other stores and computeds

  void dispose() {
    _state.dispose();
    // ... dispose other resources
  }
}
```

### 3. Batch Multiple Updates

When updating multiple stores, use `batch` to minimize widget rebuilds:

```dart
batch(() {
  firstName.value = 'John';
  lastName.value = 'Doe';
  age.value = 30;
}); // Single rebuild instead of three
```

### 4. Use Computed for Derived State

Prefer `Computed` over manual calculations in widgets:

```dart
// ✅ Good: Computed automatically tracks dependencies
late final totalPrice = Computed(() =>
  items.value.fold(0.0, (sum, item) => sum + item.price)
);

// ❌ Avoid: Manual calculation in widget
Widget build(BuildContext context) {
  final total = items.value.fold(0.0, (sum, item) => sum + item.price);
  // ...
}
```

### 5. Use Custom Equality for Collections

For stores containing lists or maps, use custom equality:

```dart
final items = Store<List<Item>>([...],
  equality: (a, b) => listEquals(a, b),
);
```

---

## Performance

The Flutter adapter is designed for zero overhead:

- **Cached instances** - `asListenable` returns the same instance for the same source
- **Direct delegation** - No wrapper overhead, operations forward directly to Pureflow
- **No allocations** - Uses `Expando` for caching, no per-access allocations

This means you can call `asListenable` freely without performance concerns.

---

## Additional Resources

- **[Pureflow Core Package](https://pub.dev/packages/pureflow)** - Core reactive state management API and documentation
- **[GitHub Repository](https://github.com/arxdeus/pureflow)** - Source code, issues, and contributions
- **[Full Documentation](https://github.com/arxdeus/pureflow#readme)** - Complete guide with all features

---

## License

MIT License - see [LICENSE](LICENSE) for details.
