# Benchmark Results

This document contains performance comparison results between Pureflow and other state management libraries.

## Results Summary

| Feature | [Pureflow](https://pub.dev/packages/pureflow) | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|
| State Holder: Create | 0.69 us | 0.33 us | 4.94 us | 0.74 us | 2.88 us | 0.38 us | 
| State Holder: Read | 0.02 us | 0.01 us | 0.16 us | 0.03 us | 0.03 us | 0.01 us | 
| State Holder: Write | 0.03 us | 0.08 us | 0.85 us | 0.28 us | 1.77 us | 0.02 us | 
| State Holder: Notify | 0.07 us | 0.43 us | 1.03 us | 0.52 us | 6.91 us | 0.04 us | 
| State Holder: Notify - Many Dependents (1000) | 17.66 us | 29.22 us | 84.66 us | 238.90 us | 4706.42 us | 13.85 us | 
| State Holder: Subscribe | — | 1.05 us | — | — | — | — | 
| State Holder: Unsubscribe | — | 0.03 us | — | — | — | — | 
| Recomputable View: Create | 0.66 us | — | 8.72 us | 1.01 us | 4.02 us | 2.27 us | 
| Recomputable View: Read | 0.02 us | — | 0.16 us | 0.04 us | 0.23 us | 0.01 us | 
| Recomputable View: Recompute | 0.16 us | — | 2.64 us | 0.46 us | 2.15 us | 0.11 us | 
| Recomputable View: Chain | 0.30 us | — | 4.46 us | 0.63 us | 5.03 us | 0.19 us | 
| Recomputable View: Chain - Many Dependents (1000) | 150.49 us | — | 1744.84 us | 170.11 us | 231.14 us | 78.17 us | 
| Async Concurrency: Sequential | 2.92 us | 3.07 us | — | — | — | — | 

## Performance Comparison (vs Pureflow)

This table shows the percentage difference from Pureflow for each metric.

| Feature | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|
| State Holder: Create | -51.7% | 621.0% | 8.1% | 319.7% | -44.8% | 
| State Holder: Read | -38.9% | 825.3% | 56.6% | 88.8% | -38.8% | 
| State Holder: Write | 207.7% | 3181.6% | 980.5% | 6747.8% | -11.3% | 
| State Holder: Notify | 519.5% | 1371.3% | 645.7% | 9790.5% | -44.3% | 
| State Holder: Notify - Many Dependents (1000) | 65.5% | 379.4% | 1253.0% | 26555.0% | -21.6% | 
| State Holder: Subscribe | — | — | — | — | — | 
| State Holder: Unsubscribe | — | — | — | — | — | 
| Recomputable View: Create | — | 1221.6% | 53.4% | 508.8% | 243.6% | 
| Recomputable View: Read | — | 793.1% | 155.9% | 1208.0% | -39.0% | 
| Recomputable View: Recompute | — | 1515.6% | 182.2% | 1212.7% | -35.1% | 
| Recomputable View: Chain | — | 1378.5% | 107.8% | 1566.6% | -38.4% | 
| Recomputable View: Chain - Many Dependents (1000) | — | 1059.4% | 13.0% | 53.6% | -48.1% | 
| Async Concurrency: Sequential | 5.1% | — | — | — | — | 

## Detailed Results

### Pureflow

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.30 |
| Computed.chain.many_dependents | 150.49 |
| Computed.create | 0.66 |
| Computed.read | 0.02 |
| Computed.recompute | 0.16 |
| Pipeline.sequential | 2.92 |
| Store.create | 0.69 |
| Store.notify | 0.07 |
| Store.notify.many_dependents | 17.66 |
| Store.read | 0.02 |
| Store.write | 0.03 |

### Bloc

| Benchmark | Time (μs) |
|-----------|-----------|
| Cubit.create | 0.33 |
| Cubit.notify | 0.43 |
| Cubit.notify.many_dependents | 29.22 |
| Cubit.read | 0.01 |
| Cubit.subscribe | 1.05 |
| Cubit.unsubscribe | 0.03 |
| Cubit.write | 0.08 |
| Sequential | 3.07 |

### Riverpod

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 4.46 |
| Computed.chain.many_dependents | 1744.84 |
| Computed.create | 8.72 |
| Computed.read | 0.16 |
| Computed.recompute | 2.64 |
| StateProvider.create | 4.94 |
| StateProvider.notify | 1.03 |
| StateProvider.notify.many_dependents | 84.66 |
| StateProvider.read | 0.16 |
| StateProvider.write | 0.85 |

### Signals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.63 |
| Computed.chain.many_dependents | 170.11 |
| Computed.create | 1.01 |
| Computed.read | 0.04 |
| Computed.recompute | 0.46 |
| Signal.create | 0.74 |
| Signal.notify | 0.52 |
| Signal.notify.many_dependents | 238.90 |
| Signal.read | 0.03 |
| Signal.write | 0.28 |

### MobX

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 5.03 |
| Computed.chain.many_dependents | 231.14 |
| Computed.create | 4.02 |
| Computed.read | 0.23 |
| Computed.recompute | 2.15 |
| Observable.create | 2.88 |
| Observable.notify | 6.91 |
| Observable.notify.many_dependents | 4706.42 |
| Observable.read | 0.03 |
| Observable.write | 1.77 |

### ValueNotifier

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.19 |
| Computed.chain.many_dependents | 78.17 |
| Computed.create | 2.27 |
| Computed.read | 0.01 |
| Computed.recompute | 0.11 |
| ValueNotifier.create | 0.38 |
| ValueNotifier.notify | 0.04 |
| ValueNotifier.notify.many_dependents | 13.85 |
| ValueNotifier.read | 0.01 |
| ValueNotifier.write | 0.02 |

---

*Generated automatically by `benchmark/bin/run_benchmarks.dart`*
