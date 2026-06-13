# Benchmark Results

This document contains performance comparison results between Pureflow and other state management libraries.

## Results Summary

| Feature | [Pureflow](https://pub.dev/packages/pureflow) | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [Caffeine](https://pub.dev/packages/caffeine) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|---|---|
| State Holder: Create | 0.89 us | 1.45 us | 100.26 us | 146.53 us | 0.66 us | 13.61 us | 4.29 us | 0.89 us | 
| State Holder: Read | 0.02 us | 0.04 us | 4.79 us | 0.10 us | 0.07 us | 0.54 us | 0.04 us | 0.04 us | 
| State Holder: Write | 0.05 us | 0.17 us | 24.17 us | 1.68 us | 0.04 us | 4.47 us | 2.42 us | 0.07 us | 
| State Holder: Notify | 0.13 us | 0.70 us | 24.96 us | 2.24 us | 0.44 us | 4.56 us | 9.36 us | 0.13 us | 
| State Holder: Notify - Many Dependents (1000) | 38.64 us | 61.28 us | 1123.94 us | 432.48 us | 262.51 us | 25.62 us | 6268.04 us | 31.20 us | 
| Recomputable View: Create | 1.12 us | — | 187.99 us | 258.77 us | 1.21 us | 12.15 us | 4.08 us | 3.15 us | 
| Recomputable View: Read | 0.04 us | — | 8.92 us | 0.11 us | 0.07 us | 0.70 us | 2.30 us | 0.04 us | 
| Recomputable View: Recompute | 0.25 us | — | 53.89 us | 3.65 us | 0.48 us | 4.87 us | 2.95 us | 0.18 us | 
| Recomputable View: Chain | 0.45 us | — | 106.77 us | 5.66 us | 0.78 us | 5.21 us | 5.14 us | 0.25 us | 
| Recomputable View: Chain - Many Dependents (1000) | 215.23 us | — | 1227808.00 us | 1844.11 us | 280.58 us | 388.31 us | 308.30 us | 102.44 us | 
| Async Concurrency: Sequential | 4.45 us | 5.13 us | — | — | — | 4.70 us | — | — | 

## Performance Comparison (vs Pureflow)

This table shows the percentage difference from Pureflow for each metric.

| Feature | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [Caffeine](https://pub.dev/packages/caffeine) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|---|
| State Holder: Create | 63.0% | 11142.2% | 16330.6% | -26.0% | 1426.4% | 381.0% | -0.7% | 
| State Holder: Read | 93.8% | 24608.0% | 415.2% | 254.3% | 2696.2% | 91.6% | 96.1% | 
| State Holder: Write | 255.6% | 50292.5% | 3402.3% | -12.4% | 9227.2% | 4948.2% | 40.3% | 
| State Holder: Notify | 454.9% | 19742.1% | 1681.3% | 250.6% | 3521.9% | 7337.9% | 3.8% | 
| State Holder: Notify - Many Dependents (1000) | 58.6% | 2808.5% | 1019.2% | 579.3% | -33.7% | 16120.4% | -19.3% | 
| Recomputable View: Create | — | 16728.1% | 23063.7% | 8.3% | 987.7% | 265.4% | 182.2% | 
| Recomputable View: Read | — | 20227.5% | 148.7% | 68.5% | 1494.2% | 5128.8% | -12.6% | 
| Recomputable View: Recompute | — | 21314.9% | 1351.0% | 89.1% | 1837.0% | 1074.0% | -29.0% | 
| Recomputable View: Chain | — | 23778.1% | 1166.7% | 73.4% | 1065.0% | 1049.4% | -44.0% | 
| Recomputable View: Chain - Many Dependents (1000) | — | 570358.9% | 756.8% | 30.4% | 80.4% | 43.2% | -52.4% | 
| Async Concurrency: Sequential | 15.3% | — | — | — | 5.6% | — | — | 

## Detailed Results

### Pureflow

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.45 |
| Computed.chain.many_dependents | 215.23 |
| Computed.create | 1.12 |
| Computed.read | 0.04 |
| Computed.recompute | 0.25 |
| Pipeline.sequential | 4.45 |
| Store.create | 0.89 |
| Store.notify | 0.13 |
| Store.notify.many_dependents | 38.64 |
| Store.read | 0.02 |
| Store.write | 0.05 |

### Bloc

| Benchmark | Time (μs) |
|-----------|-----------|
| Cubit.create | 1.45 |
| Cubit.notify | 0.70 |
| Cubit.notify.many_dependents | 61.28 |
| Cubit.read | 0.04 |
| Cubit.write | 0.17 |
| Sequential | 5.13 |

### Riverpod

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 106.77 |
| Computed.chain.many_dependents | 1227808.00 |
| Computed.create | 187.99 |
| Computed.read | 8.92 |
| Computed.recompute | 53.89 |
| StateProvider.create | 100.26 |
| StateProvider.notify | 24.96 |
| StateProvider.notify.many_dependents | 1123.94 |
| StateProvider.read | 4.79 |
| StateProvider.write | 24.17 |

### Signals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 5.66 |
| Computed.chain.many_dependents | 1844.11 |
| Computed.create | 258.77 |
| Computed.read | 0.11 |
| Computed.recompute | 3.65 |
| Signal.create | 146.53 |
| Signal.notify | 2.24 |
| Signal.notify.many_dependents | 432.48 |
| Signal.read | 0.10 |
| Signal.write | 1.68 |

### AlienSignals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.78 |
| Computed.chain.many_dependents | 280.58 |
| Computed.create | 1.21 |
| Computed.read | 0.07 |
| Computed.recompute | 0.48 |
| Signal.create | 0.66 |
| Signal.notify | 0.44 |
| Signal.notify.many_dependents | 262.51 |
| Signal.read | 0.07 |
| Signal.write | 0.04 |

### Caffeine

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 5.21 |
| Computed.chain.many_dependents | 388.31 |
| Computed.create | 12.15 |
| Computed.read | 0.70 |
| Computed.recompute | 4.87 |
| Sequential | 4.70 |
| Store.create | 13.61 |
| Store.notify | 4.56 |
| Store.notify.many_dependents | 25.62 |
| Store.read | 0.54 |
| Store.write | 4.47 |

### MobX

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 5.14 |
| Computed.chain.many_dependents | 308.30 |
| Computed.create | 4.08 |
| Computed.read | 2.30 |
| Computed.recompute | 2.95 |
| Observable.create | 4.29 |
| Observable.notify | 9.36 |
| Observable.notify.many_dependents | 6268.04 |
| Observable.read | 0.04 |
| Observable.write | 2.42 |

### ValueNotifier

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.25 |
| Computed.chain.many_dependents | 102.44 |
| Computed.create | 3.15 |
| Computed.read | 0.04 |
| Computed.recompute | 0.18 |
| ValueNotifier.create | 0.89 |
| ValueNotifier.notify | 0.13 |
| ValueNotifier.notify.many_dependents | 31.20 |
| ValueNotifier.read | 0.04 |
| ValueNotifier.write | 0.07 |

---

*Generated automatically by `benchmark/bin/run_benchmarks.dart`*
