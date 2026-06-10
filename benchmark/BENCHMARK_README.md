# Benchmark Results

This document contains performance comparison results between Pureflow and other state management libraries.

## Results Summary

| Feature | [Pureflow](https://pub.dev/packages/pureflow) | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|---|
| State Holder: Create | 1.64 us | 0.85 us | 7.93 us | 5.83 us | 0.96 us | 3.99 us | 0.65 us | 
| State Holder: Read | 0.02 us | 0.04 us | 0.24 us | 0.07 us | 0.07 us | 0.04 us | 0.04 us | 
| State Holder: Write | 0.10 us | 0.16 us | 1.24 us | 2.17 us | 0.05 us | 2.52 us | 0.06 us | 
| State Holder: Notify | 0.16 us | 0.65 us | 1.65 us | 2.58 us | 0.45 us | 9.14 us | 0.13 us | 
| State Holder: Notify - Many Dependents (1000) | 39.56 us | 55.27 us | 182.62 us | 385.27 us | 273.26 us | 6020.22 us | 31.73 us | 
| State Holder: Subscribe | — | 1.27 us | — | — | — | — | — | 
| State Holder: Unsubscribe | — | 0.05 us | — | — | — | — | — | 
| Recomputable View: Create | 2.34 us | — | 13.06 us | 9.17 us | 0.96 us | 4.48 us | 2.68 us | 
| Recomputable View: Read | 0.04 us | — | 0.25 us | 0.10 us | 0.07 us | 0.49 us | 0.04 us | 
| Recomputable View: Recompute | 0.33 us | — | 3.58 us | 4.30 us | 0.48 us | 3.36 us | 0.18 us | 
| Recomputable View: Chain | 0.54 us | — | 7.20 us | 6.36 us | 0.80 us | 4.85 us | 0.25 us | 
| Recomputable View: Chain - Many Dependents (1000) | 252.48 us | — | 2812.87 us | 1947.39 us | 266.94 us | 307.73 us | 99.46 us | 
| Async Concurrency: Sequential | 4.65 us | 5.04 us | — | — | — | — | — | 

## Performance Comparison (vs Pureflow)

This table shows the percentage difference from Pureflow for each metric.

| Feature | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|
| State Holder: Create | -48.3% | 383.2% | 255.1% | -41.3% | 143.5% | -60.6% | 
| State Holder: Read | 113.0% | 1091.4% | 249.4% | 224.6% | 118.6% | 116.6% | 
| State Holder: Write | 72.7% | 1206.1% | 2177.3% | -50.6% | 2552.6% | -33.9% | 
| State Holder: Notify | 295.1% | 901.7% | 1467.0% | 174.1% | 5455.2% | -21.2% | 
| State Holder: Notify - Many Dependents (1000) | 39.7% | 361.6% | 873.8% | 590.7% | 15116.2% | -19.8% | 
| State Holder: Subscribe | — | — | — | — | — | — | 
| State Holder: Unsubscribe | — | — | — | — | — | — | 
| Recomputable View: Create | — | 459.1% | 292.4% | -58.7% | 91.8% | 14.8% | 
| Recomputable View: Read | — | 474.3% | 133.9% | 59.0% | 1026.7% | -6.3% | 
| Recomputable View: Recompute | — | 985.0% | 1203.9% | 46.4% | 919.3% | -45.9% | 
| Recomputable View: Chain | — | 1241.9% | 1086.3% | 49.1% | 804.4% | -53.4% | 
| Recomputable View: Chain - Many Dependents (1000) | — | 1014.1% | 671.3% | 5.7% | 21.9% | -60.6% | 
| Async Concurrency: Sequential | 8.4% | — | — | — | — | — | 

## Detailed Results

### Pureflow

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.54 |
| Computed.chain.many_dependents | 252.48 |
| Computed.create | 2.34 |
| Computed.read | 0.04 |
| Computed.recompute | 0.33 |
| Pipeline.sequential | 4.65 |
| Store.create | 1.64 |
| Store.notify | 0.16 |
| Store.notify.many_dependents | 39.56 |
| Store.read | 0.02 |
| Store.write | 0.10 |

### Bloc

| Benchmark | Time (μs) |
|-----------|-----------|
| Cubit.create | 0.85 |
| Cubit.notify | 0.65 |
| Cubit.notify.many_dependents | 55.27 |
| Cubit.read | 0.04 |
| Cubit.subscribe | 1.27 |
| Cubit.unsubscribe | 0.05 |
| Cubit.write | 0.16 |
| Sequential | 5.04 |

### Riverpod

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 7.20 |
| Computed.chain.many_dependents | 2812.87 |
| Computed.create | 13.06 |
| Computed.read | 0.25 |
| Computed.recompute | 3.58 |
| StateProvider.create | 7.93 |
| StateProvider.notify | 1.65 |
| StateProvider.notify.many_dependents | 182.62 |
| StateProvider.read | 0.24 |
| StateProvider.write | 1.24 |

### Signals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 6.36 |
| Computed.chain.many_dependents | 1947.39 |
| Computed.create | 9.17 |
| Computed.read | 0.10 |
| Computed.recompute | 4.30 |
| Signal.create | 5.83 |
| Signal.notify | 2.58 |
| Signal.notify.many_dependents | 385.27 |
| Signal.read | 0.07 |
| Signal.write | 2.17 |

### AlienSignals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.80 |
| Computed.chain.many_dependents | 266.94 |
| Computed.create | 0.96 |
| Computed.read | 0.07 |
| Computed.recompute | 0.48 |
| Signal.create | 0.96 |
| Signal.notify | 0.45 |
| Signal.notify.many_dependents | 273.26 |
| Signal.read | 0.07 |
| Signal.write | 0.05 |

### MobX

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 4.85 |
| Computed.chain.many_dependents | 307.73 |
| Computed.create | 4.48 |
| Computed.read | 0.49 |
| Computed.recompute | 3.36 |
| Observable.create | 3.99 |
| Observable.notify | 9.14 |
| Observable.notify.many_dependents | 6020.22 |
| Observable.read | 0.04 |
| Observable.write | 2.52 |

### ValueNotifier

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.25 |
| Computed.chain.many_dependents | 99.46 |
| Computed.create | 2.68 |
| Computed.read | 0.04 |
| Computed.recompute | 0.18 |
| ValueNotifier.create | 0.65 |
| ValueNotifier.notify | 0.13 |
| ValueNotifier.notify.many_dependents | 31.73 |
| ValueNotifier.read | 0.04 |
| ValueNotifier.write | 0.06 |

---

*Generated automatically by `benchmark/bin/run_benchmarks.dart`*
