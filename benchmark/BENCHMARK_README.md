# Benchmark Results

This document contains performance comparison results between Pureflow and other state management libraries.

## Results Summary

| Feature | [Pureflow](https://pub.dev/packages/pureflow) | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [Caffeine](https://pub.dev/packages/caffeine) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|---|---|
| State Holder: Create | 0.82 us | 0.66 us | 7.50 us | 5.94 us | 0.95 us | 9.82 us | 3.54 us | 0.74 us | 
| State Holder: Read | 0.02 us | 0.04 us | 0.24 us | 0.07 us | 0.07 us | 0.53 us | 0.04 us | 0.04 us | 
| State Holder: Write | 0.05 us | 0.16 us | 1.24 us | 2.10 us | 0.05 us | 4.53 us | 2.54 us | 0.07 us | 
| State Holder: Notify | 0.13 us | 0.65 us | 1.60 us | 2.54 us | 0.42 us | 4.63 us | 9.14 us | 0.13 us | 
| State Holder: Notify - Many Dependents (1000) | 38.23 us | 56.64 us | 191.91 us | 378.84 us | 268.17 us | 26.53 us | 6090.76 us | 30.70 us | 
| Recomputable View: Create | 0.93 us | — | 12.74 us | 9.42 us | 0.97 us | 12.09 us | 4.98 us | 5.02 us | 
| Recomputable View: Read | 0.05 us | — | 0.25 us | 0.11 us | 0.07 us | 0.63 us | 0.30 us | 0.04 us | 
| Recomputable View: Recompute | 0.26 us | — | 3.48 us | 4.09 us | 0.50 us | 4.94 us | 2.91 us | 0.18 us | 
| Recomputable View: Chain | 0.45 us | — | 6.75 us | 6.13 us | 0.75 us | 5.12 us | 4.93 us | 0.25 us | 
| Recomputable View: Chain - Many Dependents (1000) | 209.15 us | — | 3046.52 us | 1876.50 us | 271.22 us | 369.83 us | 309.54 us | 104.73 us | 
| Async Concurrency: Sequential | 4.48 us | 4.89 us | — | — | — | 4.73 us | — | — | 

## Performance Comparison (vs Pureflow)

This table shows the percentage difference from Pureflow for each metric.

| Feature | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [Caffeine](https://pub.dev/packages/caffeine) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|---|
| State Holder: Create | -18.8% | 819.4% | 627.9% | 16.3% | 1104.2% | 333.5% | -9.0% | 
| State Holder: Read | 118.9% | 1138.2% | 285.7% | 258.7% | 2617.5% | 122.3% | 126.1% | 
| State Holder: Write | 238.0% | 2486.1% | 4298.4% | -5.4% | 9370.4% | 5223.9% | 43.9% | 
| State Holder: Notify | 392.6% | 1110.7% | 1828.5% | 222.0% | 3416.7% | 6837.0% | -3.3% | 
| State Holder: Notify - Many Dependents (1000) | 48.2% | 402.0% | 890.9% | 601.4% | -30.6% | 15831.1% | -19.7% | 
| Recomputable View: Create | — | 1262.9% | 907.2% | 3.5% | 1193.0% | 432.5% | 436.7% | 
| Recomputable View: Read | — | 450.0% | 133.9% | 63.1% | 1285.1% | 569.1% | -8.2% | 
| Recomputable View: Recompute | — | 1257.7% | 1495.9% | 94.9% | 1828.5% | 1036.2% | -29.6% | 
| Recomputable View: Chain | — | 1414.4% | 1274.5% | 69.2% | 1049.0% | 1006.7% | -44.7% | 
| Recomputable View: Chain - Many Dependents (1000) | — | 1356.6% | 797.2% | 29.7% | 76.8% | 48.0% | -49.9% | 
| Async Concurrency: Sequential | 9.2% | — | — | — | 5.6% | — | — | 

## Detailed Results

### Pureflow

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.45 |
| Computed.chain.many_dependents | 209.15 |
| Computed.create | 0.93 |
| Computed.read | 0.05 |
| Computed.recompute | 0.26 |
| Pipeline.sequential | 4.48 |
| Store.create | 0.82 |
| Store.notify | 0.13 |
| Store.notify.many_dependents | 38.23 |
| Store.read | 0.02 |
| Store.write | 0.05 |

### Bloc

| Benchmark | Time (μs) |
|-----------|-----------|
| Cubit.create | 0.66 |
| Cubit.notify | 0.65 |
| Cubit.notify.many_dependents | 56.64 |
| Cubit.read | 0.04 |
| Cubit.write | 0.16 |
| Sequential | 4.89 |

### Riverpod

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 6.75 |
| Computed.chain.many_dependents | 3046.52 |
| Computed.create | 12.74 |
| Computed.read | 0.25 |
| Computed.recompute | 3.48 |
| StateProvider.create | 7.50 |
| StateProvider.notify | 1.60 |
| StateProvider.notify.many_dependents | 191.91 |
| StateProvider.read | 0.24 |
| StateProvider.write | 1.24 |

### Signals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 6.13 |
| Computed.chain.many_dependents | 1876.50 |
| Computed.create | 9.42 |
| Computed.read | 0.11 |
| Computed.recompute | 4.09 |
| Signal.create | 5.94 |
| Signal.notify | 2.54 |
| Signal.notify.many_dependents | 378.84 |
| Signal.read | 0.07 |
| Signal.write | 2.10 |

### AlienSignals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.75 |
| Computed.chain.many_dependents | 271.22 |
| Computed.create | 0.97 |
| Computed.read | 0.07 |
| Computed.recompute | 0.50 |
| Signal.create | 0.95 |
| Signal.notify | 0.42 |
| Signal.notify.many_dependents | 268.17 |
| Signal.read | 0.07 |
| Signal.write | 0.05 |

### Caffeine

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 5.12 |
| Computed.chain.many_dependents | 369.83 |
| Computed.create | 12.09 |
| Computed.read | 0.63 |
| Computed.recompute | 4.94 |
| Sequential | 4.73 |
| Store.create | 9.82 |
| Store.notify | 4.63 |
| Store.notify.many_dependents | 26.53 |
| Store.read | 0.53 |
| Store.write | 4.53 |

### MobX

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 4.93 |
| Computed.chain.many_dependents | 309.54 |
| Computed.create | 4.98 |
| Computed.read | 0.30 |
| Computed.recompute | 2.91 |
| Observable.create | 3.54 |
| Observable.notify | 9.14 |
| Observable.notify.many_dependents | 6090.76 |
| Observable.read | 0.04 |
| Observable.write | 2.54 |

### ValueNotifier

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.25 |
| Computed.chain.many_dependents | 104.73 |
| Computed.create | 5.02 |
| Computed.read | 0.04 |
| Computed.recompute | 0.18 |
| ValueNotifier.create | 0.74 |
| ValueNotifier.notify | 0.13 |
| ValueNotifier.notify.many_dependents | 30.70 |
| ValueNotifier.read | 0.04 |
| ValueNotifier.write | 0.07 |

---

*Generated automatically by `benchmark/bin/run_benchmarks.dart`*
