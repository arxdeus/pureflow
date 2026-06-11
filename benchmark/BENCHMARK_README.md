# Benchmark Results

This document contains performance comparison results between Pureflow and other state management libraries.

## Results Summary

| Feature | [Pureflow](https://pub.dev/packages/pureflow) | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|---|
| State Holder: Create | 0.76 us | 0.77 us | 7.72 us | 5.17 us | 0.82 us | 3.89 us | 0.75 us | 
| State Holder: Read | 0.02 us | 0.04 us | 0.24 us | 0.07 us | 0.07 us | 0.04 us | 0.04 us | 
| State Holder: Write | 0.05 us | 0.16 us | 1.25 us | 2.09 us | 0.05 us | 2.46 us | 0.07 us | 
| State Holder: Notify | 0.12 us | 0.61 us | 1.63 us | 2.53 us | 0.46 us | 8.85 us | 0.13 us | 
| State Holder: Notify - Many Dependents (1000) | 38.73 us | 54.17 us | 243.80 us | 372.29 us | 268.54 us | 5857.73 us | 32.88 us | 
| State Holder: Subscribe | — | 1.15 us | — | — | — | — | — | 
| State Holder: Unsubscribe | — | 0.04 us | — | — | — | — | — | 
| Recomputable View: Create | 1.05 us | — | 12.67 us | 7.85 us | 1.03 us | 4.86 us | 3.04 us | 
| Recomputable View: Read | 0.04 us | — | 0.25 us | 0.10 us | 0.07 us | 0.48 us | 0.04 us | 
| Recomputable View: Recompute | 0.24 us | — | 3.46 us | 4.08 us | 0.46 us | 3.37 us | 0.17 us | 
| Recomputable View: Chain | 0.45 us | — | 6.65 us | 6.21 us | 0.79 us | 4.76 us | 0.25 us | 
| Recomputable View: Chain - Many Dependents (1000) | 210.12 us | — | 3168.51 us | 1876.05 us | 271.85 us | 312.31 us | 98.71 us | 
| Async Concurrency: Sequential | 4.58 us | 4.94 us | — | — | — | — | — | 

## Performance Comparison (vs Pureflow)

This table shows the percentage difference from Pureflow for each metric.

| Feature | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|
| State Holder: Create | 2.5% | 922.3% | 583.7% | 9.2% | 414.4% | -1.4% | 
| State Holder: Read | 92.2% | 1103.8% | 272.0% | 253.7% | 112.9% | 100.6% | 
| State Holder: Write | 234.6% | 2494.4% | 4242.6% | -0.6% | 5008.4% | 42.0% | 
| State Holder: Notify | 400.6% | 1234.3% | 1968.1% | 273.7% | 7137.2% | 5.1% | 
| State Holder: Notify - Many Dependents (1000) | 39.9% | 529.4% | 861.2% | 593.3% | 15023.4% | -15.1% | 
| State Holder: Subscribe | — | — | — | — | — | — | 
| State Holder: Unsubscribe | — | — | — | — | — | — | 
| Recomputable View: Create | — | 1101.2% | 645.0% | -2.0% | 360.8% | 188.6% | 
| Recomputable View: Read | — | 469.0% | 139.5% | 68.2% | 1001.6% | -7.5% | 
| Recomputable View: Recompute | — | 1358.9% | 1619.0% | 93.8% | 1318.1% | -28.5% | 
| Recomputable View: Chain | — | 1389.6% | 1292.1% | 76.7% | 966.6% | -44.5% | 
| Recomputable View: Chain - Many Dependents (1000) | — | 1408.0% | 792.9% | 29.4% | 48.6% | -53.0% | 
| Async Concurrency: Sequential | 7.8% | — | — | — | — | — | 

## Detailed Results

### Pureflow

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.45 |
| Computed.chain.many_dependents | 210.12 |
| Computed.create | 1.05 |
| Computed.read | 0.04 |
| Computed.recompute | 0.24 |
| Pipeline.sequential | 4.58 |
| Store.create | 0.76 |
| Store.notify | 0.12 |
| Store.notify.many_dependents | 38.73 |
| Store.read | 0.02 |
| Store.write | 0.05 |

### Bloc

| Benchmark | Time (μs) |
|-----------|-----------|
| Cubit.create | 0.77 |
| Cubit.notify | 0.61 |
| Cubit.notify.many_dependents | 54.17 |
| Cubit.read | 0.04 |
| Cubit.subscribe | 1.15 |
| Cubit.unsubscribe | 0.04 |
| Cubit.write | 0.16 |
| Sequential | 4.94 |

### Riverpod

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 6.65 |
| Computed.chain.many_dependents | 3168.51 |
| Computed.create | 12.67 |
| Computed.read | 0.25 |
| Computed.recompute | 3.46 |
| StateProvider.create | 7.72 |
| StateProvider.notify | 1.63 |
| StateProvider.notify.many_dependents | 243.80 |
| StateProvider.read | 0.24 |
| StateProvider.write | 1.25 |

### Signals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 6.21 |
| Computed.chain.many_dependents | 1876.05 |
| Computed.create | 7.85 |
| Computed.read | 0.10 |
| Computed.recompute | 4.08 |
| Signal.create | 5.17 |
| Signal.notify | 2.53 |
| Signal.notify.many_dependents | 372.29 |
| Signal.read | 0.07 |
| Signal.write | 2.09 |

### AlienSignals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.79 |
| Computed.chain.many_dependents | 271.85 |
| Computed.create | 1.03 |
| Computed.read | 0.07 |
| Computed.recompute | 0.46 |
| Signal.create | 0.82 |
| Signal.notify | 0.46 |
| Signal.notify.many_dependents | 268.54 |
| Signal.read | 0.07 |
| Signal.write | 0.05 |

### MobX

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 4.76 |
| Computed.chain.many_dependents | 312.31 |
| Computed.create | 4.86 |
| Computed.read | 0.48 |
| Computed.recompute | 3.37 |
| Observable.create | 3.89 |
| Observable.notify | 8.85 |
| Observable.notify.many_dependents | 5857.73 |
| Observable.read | 0.04 |
| Observable.write | 2.46 |

### ValueNotifier

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.25 |
| Computed.chain.many_dependents | 98.71 |
| Computed.create | 3.04 |
| Computed.read | 0.04 |
| Computed.recompute | 0.17 |
| ValueNotifier.create | 0.75 |
| ValueNotifier.notify | 0.13 |
| ValueNotifier.notify.many_dependents | 32.88 |
| ValueNotifier.read | 0.04 |
| ValueNotifier.write | 0.07 |

---

*Generated automatically by `benchmark/bin/run_benchmarks.dart`*
