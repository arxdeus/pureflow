# Benchmark Results

This document contains performance comparison results between Pureflow and other state management libraries.

## Results Summary

| Feature | [Pureflow](https://pub.dev/packages/pureflow) | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) |
|---------|---|---|---|---|---|---|
| State Holder: Create | 0.20 us | 1.01 us | 16.11 us | 0.50 us | 1.82 us | 0.15 us |
| State Holder: Read | 0.05 us | 0.02 us | 0.54 us | 0.06 us | 0.07 us | 0.02 us |
| State Holder: Write | 0.09 us | 0.28 us | 2.22 us | 0.73 us | 5.41 us | 0.06 us |
| State Holder: Notify | 0.12 us | 0.94 us | 2.60 us | 1.75 us | 26.90 us | 0.11 us |
| State Holder: Notify - Many Dependents (1000) | 32.96 us | 80.89 us | 215.29 us | 669.22 us | 17784.66 us | 21.77 us |
| Recomputable View: Create | 0.30 us | — | 0.51 us | 0.65 us | 1.92 us | 1.66 us |
| Recomputable View: Read | 0.05 us | — | 0.52 us | 0.11 us | 0.51 us | 0.02 us |
| Recomputable View: Recompute | 0.45 us | — | 7.75 us | 1.40 us | 6.37 us | 0.20 us |
| Recomputable View: Chain | 0.82 us | — | 11.69 us | 2.11 us | 14.44 us | 0.33 us |
| Recomputable View: Chain - Many Dependents (1000) | 318.84 us | — | 4758.12 us | 560.40 us | 476.35 us | 139.87 us |
| Async Concurrency: Sequential | 10.61 us | 14.29 us | — | — | — | — |

## Feature Descriptions and Implementations

### State Holder

A reactive container that holds a mutable value and notifies listeners when the value changes.

| Package | Implementation |
|---------|----------------|
| **Pureflow** | `Store<T>` |
| **Bloc** | `Cubit<T>` |
| **Riverpod** | `StateProvider<T>` |
| **Signals** | `Signal<T>` (via `signal()` function) |
| **MobX** | `Observable<T>` |
| **ValueNotifier** | `ValueNotifier<T>` |

**Operations:**
- **Create**: Instantiate a new state holder with an initial value
- **Read**: Access the current value
- **Write**: Update the value
- **Notify**: Update the value and notify a single listener
- **Notify - Many Dependents (1000)**: Update the value and notify 1000 listeners

### Recomputable View

A derived value that automatically tracks dependencies and recomputes when those dependencies change. Also known as computed values, selectors, or derived state.

| Package | Implementation |
|---------|----------------|
| **Pureflow** | `Computed<T>` |
| **Bloc** | Not supported (—) |
| **Riverpod** | `Provider<T>` (using `ref.watch()` for dependency tracking) |
| **Signals** | `Computed<T>` (via `computed()` function) |
| **MobX** | `Computed<T>` |
| **ValueNotifier** | `ComputedValueNotifier<T>` (custom implementation) |

**Operations:**
- **Create**: Instantiate a new computed value with a computation function
- **Read**: Access the computed value (triggers computation if needed)
- **Recompute**: Update a dependency and read the computed value (triggers recomputation)
- **Chain**: Create a chain of computed values (computed depends on another computed) and update the root dependency
- **Chain - Many Dependents (1000)**: Create 1000 computed values that depend on the same source, update the source, and read all computed values

### Async Concurrency

A system for managing concurrent async operations with configurable execution strategies (sequential, concurrent, restartable, etc.).

| Package | Implementation |
|---------|----------------|
| **Pureflow** | `Pipeline` (with configurable `transformer`) |
| **Bloc** | `Bloc<TEvent, TState>` (with event handlers) |
| **Riverpod** | Not supported (—) |
| **Signals** | Not supported (—) |
| **MobX** | Not supported (—) |
| **ValueNotifier** | Not supported (—) |

**Operations:**
- **Sequential**: Execute async tasks one at a time in order


## Performance Comparison (vs Pureflow)

This table shows the percentage difference from Pureflow for each metric.

| Feature | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) |
|---------|---|---|---|---|---|
| State Holder: Create | 409.3% | 8018.8% | 153.1% | 818.7% | -23.7% |
| State Holder: Read | -54.2% | 961.6% | 17.1% | 37.3% | -52.9% |
| State Holder: Write | 220.2% | 2458.2% | 746.1% | 6142.4% | -27.2% |
| State Holder: Notify | 676.7% | 2050.0% | 1346.9% | 22171.7% | -5.2% |
| State Holder: Notify - Many Dependents (1000) | 145.4% | 553.2% | 1930.6% | 53862.3% | -33.9% |
| Recomputable View: Create | — | 69.1% | 115.4% | 540.8% | 454.6% |
| Recomputable View: Read | — | 906.6% | 103.9% | 881.2% | -57.8% |
| Recomputable View: Recompute | — | 1624.4% | 211.3% | 1317.5% | -55.1% |
| Recomputable View: Chain | — | 1328.3% | 158.4% | 1664.5% | -59.6% |
| Recomputable View: Chain - Many Dependents (1000) | — | 1392.3% | 75.8% | 49.4% | -56.1% |
| Async Concurrency: Sequential | 34.7% | — | — | — | — |

## Detailed Results

### Pureflow

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.82 |
| Computed.chain.many_dependents | 318.84 |
| Computed.create | 0.30 |
| Computed.read | 0.05 |
| Computed.recompute | 0.45 |
| Pipeline.sequential | 10.61 |
| Store.create | 0.20 |
| Store.notify | 0.12 |
| Store.notify.many_dependents | 32.96 |
| Store.read | 0.05 |
| Store.write | 0.09 |

### Bloc

| Benchmark | Time (μs) |
|-----------|-----------|
| Cubit.create | 1.01 |
| Cubit.notify | 0.94 |
| Cubit.notify.many_dependents | 80.89 |
| Cubit.read | 0.02 |
| Cubit.write | 0.28 |
| Sequential | 14.29 |

### Riverpod

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 11.69 |
| Computed.chain.many_dependents | 4758.12 |
| Computed.create | 0.51 |
| Computed.read | 0.52 |
| Computed.recompute | 7.75 |
| StateProvider.create | 16.11 |
| StateProvider.notify | 2.60 |
| StateProvider.notify.many_dependents | 215.29 |
| StateProvider.read | 0.54 |
| StateProvider.write | 2.22 |

### Signals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 2.11 |
| Computed.chain.many_dependents | 560.40 |
| Computed.create | 0.65 |
| Computed.read | 0.11 |
| Computed.recompute | 1.40 |
| Signal.create | 0.50 |
| Signal.notify | 1.75 |
| Signal.notify.many_dependents | 669.22 |
| Signal.read | 0.06 |
| Signal.write | 0.73 |

### MobX

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 14.44 |
| Computed.chain.many_dependents | 476.35 |
| Computed.create | 1.92 |
| Computed.read | 0.51 |
| Computed.recompute | 6.37 |
| Observable.create | 1.82 |
| Observable.notify | 26.90 |
| Observable.notify.many_dependents | 17784.66 |
| Observable.read | 0.07 |
| Observable.write | 5.41 |

### ValueNotifier

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.33 |
| Computed.chain.many_dependents | 139.87 |
| Computed.create | 1.66 |
| Computed.read | 0.02 |
| Computed.recompute | 0.20 |
| ValueNotifier.create | 0.15 |
| ValueNotifier.notify | 0.11 |
| ValueNotifier.notify.many_dependents | 21.77 |
| ValueNotifier.read | 0.02 |
| ValueNotifier.write | 0.06 |

---

*Generated automatically by `benchmark/bin/run_benchmarks.dart`*
