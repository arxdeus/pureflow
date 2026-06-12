# Benchmark Results

This document contains performance comparison results between Pureflow and other state management libraries.

## Results Summary

| Feature | [Pureflow](https://pub.dev/packages/pureflow) | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|---|
| State Holder: Create | 0.92 us | 0.51 us | 6.73 us | 1.02 us | 0.86 us | 3.80 us | 0.90 us | 
| State Holder: Read | 0.02 us | 0.01 us | 0.24 us | 0.04 us | 0.03 us | 0.06 us | 0.01 us | 
| State Holder: Write | 0.04 us | 0.11 us | 1.13 us | 0.36 us | 0.05 us | 2.29 us | 0.03 us | 
| State Holder: Notify | 0.11 us | 0.56 us | 1.38 us | 0.65 us | 0.28 us | 8.89 us | 0.05 us | 
| State Holder: Notify - Many Dependents (1000) | 28.03 us | 43.54 us | 122.68 us | 318.47 us | 194.55 us | 5897.09 us | 17.10 us | 
| State Holder: Subscribe | — | 1.54 us | — | — | — | — | — | 
| State Holder: Unsubscribe | — | 0.04 us | — | — | — | — | — | 
| Recomputable View: Create | 1.23 us | — | 11.65 us | 1.99 us | 0.95 us | 5.58 us | 2.47 us | 
| Recomputable View: Read | 0.02 us | — | 0.24 us | 0.07 us | 0.04 us | 0.31 us | 0.01 us | 
| Recomputable View: Recompute | 0.21 us | — | 3.49 us | 0.59 us | 0.27 us | 2.75 us | 0.15 us | 
| Recomputable View: Chain | 0.41 us | — | 5.86 us | 0.80 us | 0.48 us | 5.70 us | 0.23 us | 
| Recomputable View: Chain - Many Dependents (1000) | 187.31 us | — | 2517.03 us | 240.63 us | 186.20 us | 347.84 us | 104.96 us | 
| Async Concurrency: Sequential | 4.37 us | 4.72 us | — | — | — | — | — | 

## Performance Comparison (vs Pureflow)

This table shows the percentage difference from Pureflow for each metric.

| Feature | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|
| State Holder: Create | -44.3% | 630.1% | 10.9% | -6.9% | 312.0% | -2.8% | 
| State Holder: Read | -42.1% | 878.9% | 45.8% | 32.1% | 143.0% | -42.7% | 
| State Holder: Write | 214.8% | 3074.8% | 905.6% | 34.8% | 6345.2% | -8.6% | 
| State Holder: Notify | 431.3% | 1204.2% | 512.1% | 163.7% | 8267.3% | -49.1% | 
| State Holder: Notify - Many Dependents (1000) | 55.3% | 337.7% | 1036.3% | 594.2% | 20940.9% | -39.0% | 
| State Holder: Subscribe | — | — | — | — | — | — | 
| State Holder: Unsubscribe | — | — | — | — | — | — | 
| Recomputable View: Create | — | 849.9% | 62.2% | -22.5% | 355.2% | 101.8% | 
| Recomputable View: Read | — | 850.8% | 170.3% | 41.6% | 1162.1% | -42.6% | 
| Recomputable View: Recompute | — | 1587.1% | 186.3% | 28.3% | 1229.1% | -27.6% | 
| Recomputable View: Chain | — | 1321.7% | 94.4% | 16.3% | 1283.9% | -44.2% | 
| Recomputable View: Chain - Many Dependents (1000) | — | 1243.8% | 28.5% | -0.6% | 85.7% | -44.0% | 
| Async Concurrency: Sequential | 8.1% | — | — | — | — | — | 

## Detailed Results

### Pureflow

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.41 |
| Computed.chain.many_dependents | 187.31 |
| Computed.create | 1.23 |
| Computed.read | 0.02 |
| Computed.recompute | 0.21 |
| Pipeline.sequential | 4.37 |
| Store.create | 0.92 |
| Store.notify | 0.11 |
| Store.notify.many_dependents | 28.03 |
| Store.read | 0.02 |
| Store.write | 0.04 |

### Bloc

| Benchmark | Time (μs) |
|-----------|-----------|
| Cubit.create | 0.51 |
| Cubit.notify | 0.56 |
| Cubit.notify.many_dependents | 43.54 |
| Cubit.read | 0.01 |
| Cubit.subscribe | 1.54 |
| Cubit.unsubscribe | 0.04 |
| Cubit.write | 0.11 |
| Sequential | 4.72 |

### Riverpod

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 5.86 |
| Computed.chain.many_dependents | 2517.03 |
| Computed.create | 11.65 |
| Computed.read | 0.24 |
| Computed.recompute | 3.49 |
| StateProvider.create | 6.73 |
| StateProvider.notify | 1.38 |
| StateProvider.notify.many_dependents | 122.68 |
| StateProvider.read | 0.24 |
| StateProvider.write | 1.13 |

### Signals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.80 |
| Computed.chain.many_dependents | 240.63 |
| Computed.create | 1.99 |
| Computed.read | 0.07 |
| Computed.recompute | 0.59 |
| Signal.create | 1.02 |
| Signal.notify | 0.65 |
| Signal.notify.many_dependents | 318.47 |
| Signal.read | 0.04 |
| Signal.write | 0.36 |

### AlienSignals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.48 |
| Computed.chain.many_dependents | 186.20 |
| Computed.create | 0.95 |
| Computed.read | 0.04 |
| Computed.recompute | 0.27 |
| Signal.create | 0.86 |
| Signal.notify | 0.28 |
| Signal.notify.many_dependents | 194.55 |
| Signal.read | 0.03 |
| Signal.write | 0.05 |

### MobX

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 5.70 |
| Computed.chain.many_dependents | 347.84 |
| Computed.create | 5.58 |
| Computed.read | 0.31 |
| Computed.recompute | 2.75 |
| Observable.create | 3.80 |
| Observable.notify | 8.89 |
| Observable.notify.many_dependents | 5897.09 |
| Observable.read | 0.06 |
| Observable.write | 2.29 |

### ValueNotifier

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.23 |
| Computed.chain.many_dependents | 104.96 |
| Computed.create | 2.47 |
| Computed.read | 0.01 |
| Computed.recompute | 0.15 |
| ValueNotifier.create | 0.90 |
| ValueNotifier.notify | 0.05 |
| ValueNotifier.notify.many_dependents | 17.10 |
| ValueNotifier.read | 0.01 |
| ValueNotifier.write | 0.03 |

---

*Generated automatically by `benchmark/bin/run_benchmarks.dart`*
