# Benchmark Results

This document contains performance comparison results between Pureflow and other state management libraries.

## Results Summary

| Feature | [Pureflow](https://pub.dev/packages/pureflow) | [Bloc](https://pub.dev/packages/bloc) | [BlocSignals](https://pub.dev/packages/bloc_signals) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [Caffeine](https://pub.dev/packages/caffeine) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|---|---|---|
| State Holder: Create | 0.80 us | 0.82 us | 647.39 us | 83.86 us | 151.86 us | 0.84 us | 14.51 us | 7.91 us | 1.00 us | 
| State Holder: Read | 0.02 us | 0.04 us | 0.10 us | 4.18 us | 0.11 us | 0.07 us | 0.60 us | 0.04 us | 0.04 us | 
| State Holder: Write | 0.05 us | 0.16 us | 2.86 us | 24.62 us | 1.81 us | 0.04 us | 4.65 us | 13.02 us | 0.07 us | 
| State Holder: Notify | 0.13 us | 0.57 us | 3.24 us | 25.50 us | 2.33 us | 0.44 us | 4.73 us | 43.24 us | 0.12 us | 
| State Holder: Notify - Many Dependents (1000) | 38.70 us | 52.94 us | 442.11 us | 1019.85 us | 426.59 us | 265.87 us | 26.04 us | 27319.26 us | 30.35 us | 
| Recomputable View: Create | 1.24 us | — | — | 201.23 us | 282.90 us | 1.14 us | 13.75 us | 7.54 us | 3.71 us | 
| Recomputable View: Read | 0.04 us | — | — | 8.75 us | 0.10 us | 0.07 us | 0.67 us | 1.02 us | 0.04 us | 
| Recomputable View: Recompute | 0.24 us | — | — | 53.18 us | 3.88 us | 0.49 us | 5.00 us | 5.42 us | 0.18 us | 
| Recomputable View: Chain | 0.45 us | — | — | 106.91 us | 5.93 us | 0.76 us | 5.35 us | 5.14 us | 0.25 us | 
| Recomputable View: Chain - Many Dependents (1000) | 180.94 us | — | — | 1233168.00 us | 1973.61 us | 273.04 us | 369.42 us | 296.00 us | 98.11 us | 
| Async Concurrency: Sequential | 4.59 us | 5.05 us | 6.53 us | — | — | — | 4.87 us | — | — | 

## Feature Descriptions and Implementations

### State Holder

A reactive container that holds a mutable value and notifies listeners when the value changes.

| Package | Implementation |
|---------|----------------|
| **Pureflow** | `Store<T>` |
| **Bloc** | `Cubit<T>` |
| **BlocSignals** | `CubitSignal<T>` |
| **Riverpod** | `Notifier<T>` |
| **Signals** | `Signal<T>` (via `signal()` function) |
| **AlienSignals** | `WritableSignal<T>` (via `signal()` function) |
| **Caffeine** | `Store<T>` (via `Store.accum()`) |
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
| **BlocSignals** | Not benchmarked (uses `signals_core`) |
| **Riverpod** | `Provider<T>` (using `ref.watch()` for dependency tracking) |
| **Signals** | `Computed<T>` (via `computed()` function) |
| **AlienSignals** | `Computed<T>` (via `computed()` function) |
| **Caffeine** | `Store<T>` (via `Store.derive()`) |
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
| **BlocSignals** | `BlocSignal<TEvent, TState>` (with `sequential()`) |
| **Riverpod** | Not supported (—) |
| **Signals** | Not supported (—) |
| **AlienSignals** | Not supported (—) |
| **Caffeine** | `Store<T>` with serialized `async*` event handlers |
| **MobX** | Not supported (—) |
| **ValueNotifier** | Not supported (—) |

**Operations:**
- **Sequential**: Execute async tasks one at a time in order

## Performance Comparison (vs Pureflow)

This table shows the percentage difference from Pureflow for each metric.

| Feature | [Bloc](https://pub.dev/packages/bloc) | [BlocSignals](https://pub.dev/packages/bloc_signals) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [Caffeine](https://pub.dev/packages/caffeine) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|---|---|
| State Holder: Create | 2.5% | 80421.4% | 10330.2% | 18787.9% | 5.0% | 1704.6% | 884.1% | 23.9% | 
| State Holder: Read | 98.3% | 412.0% | 21020.7% | 456.7% | 253.0% | 2948.3% | 108.2% | 100.6% | 
| State Holder: Write | 240.1% | 6089.5% | 53213.1% | 3818.2% | -3.2% | 9968.8% | 28084.4% | 46.3% | 
| State Holder: Notify | 345.8% | 2411.5% | 19682.7% | 1709.1% | 239.1% | 3567.2% | 33441.1% | -6.8% | 
| State Holder: Notify - Many Dependents (1000) | 36.8% | 1042.4% | 2535.2% | 1002.3% | 587.0% | -32.7% | 70490.5% | -21.6% | 
| Recomputable View: Create | — | — | 16164.6% | 22766.1% | -7.6% | 1011.2% | 509.5% | 200.1% | 
| Recomputable View: Read | — | — | 20005.0% | 140.1% | 65.3% | 1445.6% | 2247.9% | -10.1% | 
| Recomputable View: Recompute | — | — | 22149.3% | 1521.4% | 104.4% | 1993.5% | 2167.1% | -25.0% | 
| Recomputable View: Chain | — | — | 23726.3% | 1221.8% | 70.3% | 1091.9% | 1044.4% | -44.1% | 
| Recomputable View: Chain - Many Dependents (1000) | — | — | 681421.6% | 990.7% | 50.9% | 104.2% | 63.6% | -45.8% | 
| Async Concurrency: Sequential | 9.9% | 42.3% | — | — | — | 5.9% | — | — | 

## Detailed Results

### Pureflow

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.45 |
| Computed.chain.many_dependents | 180.94 |
| Computed.create | 1.24 |
| Computed.read | 0.04 |
| Computed.recompute | 0.24 |
| Pipeline.sequential | 4.59 |
| Store.create | 0.80 |
| Store.notify | 0.13 |
| Store.notify.many_dependents | 38.70 |
| Store.read | 0.02 |
| Store.write | 0.05 |

### Bloc

| Benchmark | Time (μs) |
|-----------|-----------|
| Cubit.create | 0.82 |
| Cubit.notify | 0.57 |
| Cubit.notify.many_dependents | 52.94 |
| Cubit.read | 0.04 |
| Cubit.write | 0.16 |
| Sequential | 5.05 |

### BlocSignals

| Benchmark | Time (μs) |
|-----------|-----------|
| CubitSignal.create | 647.39 |
| CubitSignal.notify | 3.24 |
| CubitSignal.notify.many_dependents | 442.11 |
| CubitSignal.read | 0.10 |
| CubitSignal.write | 2.86 |
| Sequential | 6.53 |

### Riverpod

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 106.91 |
| Computed.chain.many_dependents | 1233168.00 |
| Computed.create | 201.23 |
| Computed.read | 8.75 |
| Computed.recompute | 53.18 |
| StateProvider.create | 83.86 |
| StateProvider.notify | 25.50 |
| StateProvider.notify.many_dependents | 1019.85 |
| StateProvider.read | 4.18 |
| StateProvider.write | 24.62 |

### Signals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 5.93 |
| Computed.chain.many_dependents | 1973.61 |
| Computed.create | 282.90 |
| Computed.read | 0.10 |
| Computed.recompute | 3.88 |
| Signal.create | 151.86 |
| Signal.notify | 2.33 |
| Signal.notify.many_dependents | 426.59 |
| Signal.read | 0.11 |
| Signal.write | 1.81 |

### AlienSignals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.76 |
| Computed.chain.many_dependents | 273.04 |
| Computed.create | 1.14 |
| Computed.read | 0.07 |
| Computed.recompute | 0.49 |
| Signal.create | 0.84 |
| Signal.notify | 0.44 |
| Signal.notify.many_dependents | 265.87 |
| Signal.read | 0.07 |
| Signal.write | 0.04 |

### Caffeine

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 5.35 |
| Computed.chain.many_dependents | 369.42 |
| Computed.create | 13.75 |
| Computed.read | 0.67 |
| Computed.recompute | 5.00 |
| Sequential | 4.87 |
| Store.create | 14.51 |
| Store.notify | 4.73 |
| Store.notify.many_dependents | 26.04 |
| Store.read | 0.60 |
| Store.write | 4.65 |

### MobX

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 5.14 |
| Computed.chain.many_dependents | 296.00 |
| Computed.create | 7.54 |
| Computed.read | 1.02 |
| Computed.recompute | 5.42 |
| Observable.create | 7.91 |
| Observable.notify | 43.24 |
| Observable.notify.many_dependents | 27319.26 |
| Observable.read | 0.04 |
| Observable.write | 13.02 |

### ValueNotifier

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.25 |
| Computed.chain.many_dependents | 98.11 |
| Computed.create | 3.71 |
| Computed.read | 0.04 |
| Computed.recompute | 0.18 |
| ValueNotifier.create | 1.00 |
| ValueNotifier.notify | 0.12 |
| ValueNotifier.notify.many_dependents | 30.35 |
| ValueNotifier.read | 0.04 |
| ValueNotifier.write | 0.07 |

---

*Generated automatically by `benchmark/bin/run_benchmarks.dart`*
