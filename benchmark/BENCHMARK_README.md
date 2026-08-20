# Benchmark Results

This document contains performance comparison results between Pureflow and other state management libraries.

## Results Summary

| Feature | [Pureflow](https://pub.dev/packages/pureflow) | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [Caffeine](https://pub.dev/packages/caffeine) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|---|---|
| State Holder: Create | 0.88 us | 0.87 us | 81.21 us | 132.43 us | 0.84 us | 18.03 us | 5.71 us | 1.10 us | 
| State Holder: Read | 0.02 us | 0.04 us | 4.36 us | 0.10 us | 0.07 us | 0.55 us | 0.04 us | 0.04 us | 
| State Holder: Write | 0.05 us | 0.15 us | 25.26 us | 1.79 us | 0.04 us | 4.61 us | 6.07 us | 0.07 us | 
| State Holder: Notify | 0.13 us | 0.61 us | 24.77 us | 2.31 us | 0.45 us | 4.68 us | 9.75 us | 0.12 us | 
| State Holder: Notify - Many Dependents (1000) | 39.10 us | 54.49 us | 1012.45 us | 406.71 us | 257.07 us | 24.68 us | 6684.44 us | 30.59 us | 
| Recomputable View: Create | 1.87 us | — | 172.72 us | 237.18 us | 2.32 us | 11.26 us | 7.98 us | 5.59 us | 
| Recomputable View: Read | 0.04 us | — | 8.68 us | 0.10 us | 0.07 us | 0.82 us | 0.27 us | 0.04 us | 
| Recomputable View: Recompute | 0.22 us | — | 69.00 us | 3.81 us | 0.47 us | 4.89 us | 2.90 us | 0.17 us | 
| Recomputable View: Chain | 0.45 us | — | 81.88 us | 6.00 us | 0.74 us | 5.25 us | 5.05 us | 0.25 us | 
| Recomputable View: Chain - Many Dependents (1000) | 184.47 us | — | 1226234.00 us | 1989.30 us | 268.50 us | 393.73 us | 293.76 us | 99.81 us | 
| Async Concurrency: Sequential | 4.55 us | 5.03 us | — | — | — | 4.80 us | — | — | 

## Performance Comparison (vs Pureflow)

This table shows the percentage difference from Pureflow for each metric.

| Feature | [Bloc](https://pub.dev/packages/bloc) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [Caffeine](https://pub.dev/packages/caffeine) | [MobX](https://pub.dev/packages/mobx) | [ValueNotifier](https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html) | 
|---------|---|---|---|---|---|---|---|
| State Holder: Create | -1.0% | 9151.7% | 14988.0% | -3.8% | 1953.7% | 550.0% | 24.9% | 
| State Holder: Read | 93.3% | 22225.8% | 407.9% | 250.9% | 2693.5% | 103.5% | 91.4% | 
| State Holder: Write | 219.8% | 52372.1% | 3612.7% | -8.5% | 9484.1% | 12507.4% | 41.1% | 
| State Holder: Notify | 349.8% | 18260.1% | 1610.6% | 231.7% | 3365.9% | 7128.1% | -11.8% | 
| State Holder: Notify - Many Dependents (1000) | 39.3% | 2489.1% | 940.1% | 557.4% | -36.9% | 16993.8% | -21.8% | 
| Recomputable View: Create | — | 9148.7% | 12600.8% | 24.0% | 502.9% | 327.4% | 199.2% | 
| Recomputable View: Read | — | 20220.4% | 142.4% | 69.6% | 1827.8% | 531.7% | -8.7% | 
| Recomputable View: Recompute | — | 31124.4% | 1626.2% | 114.6% | 2114.9% | 1214.2% | -22.6% | 
| Recomputable View: Chain | — | 18257.5% | 1245.4% | 65.1% | 1077.8% | 1032.3% | -43.6% | 
| Recomputable View: Chain - Many Dependents (1000) | — | 664619.6% | 978.4% | 45.5% | 113.4% | 59.2% | -45.9% | 
| Async Concurrency: Sequential | 10.5% | — | — | — | 5.4% | — | — | 

## Detailed Results

### Pureflow

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.45 |
| Computed.chain.many_dependents | 184.47 |
| Computed.create | 1.87 |
| Computed.read | 0.04 |
| Computed.recompute | 0.22 |
| Pipeline.sequential | 4.55 |
| Store.create | 0.88 |
| Store.notify | 0.13 |
| Store.notify.many_dependents | 39.10 |
| Store.read | 0.02 |
| Store.write | 0.05 |

### Bloc

| Benchmark | Time (μs) |
|-----------|-----------|
| Cubit.create | 0.87 |
| Cubit.notify | 0.61 |
| Cubit.notify.many_dependents | 54.49 |
| Cubit.read | 0.04 |
| Cubit.write | 0.15 |
| Sequential | 5.03 |

### Riverpod

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 81.88 |
| Computed.chain.many_dependents | 1226234.00 |
| Computed.create | 172.72 |
| Computed.read | 8.68 |
| Computed.recompute | 69.00 |
| StateProvider.create | 81.21 |
| StateProvider.notify | 24.77 |
| StateProvider.notify.many_dependents | 1012.45 |
| StateProvider.read | 4.36 |
| StateProvider.write | 25.26 |

### Signals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 6.00 |
| Computed.chain.many_dependents | 1989.30 |
| Computed.create | 237.18 |
| Computed.read | 0.10 |
| Computed.recompute | 3.81 |
| Signal.create | 132.43 |
| Signal.notify | 2.31 |
| Signal.notify.many_dependents | 406.71 |
| Signal.read | 0.10 |
| Signal.write | 1.79 |

### AlienSignals

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.74 |
| Computed.chain.many_dependents | 268.50 |
| Computed.create | 2.32 |
| Computed.read | 0.07 |
| Computed.recompute | 0.47 |
| Signal.create | 0.84 |
| Signal.notify | 0.45 |
| Signal.notify.many_dependents | 257.07 |
| Signal.read | 0.07 |
| Signal.write | 0.04 |

### Caffeine

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 5.25 |
| Computed.chain.many_dependents | 393.73 |
| Computed.create | 11.26 |
| Computed.read | 0.82 |
| Computed.recompute | 4.89 |
| Sequential | 4.80 |
| Store.create | 18.03 |
| Store.notify | 4.68 |
| Store.notify.many_dependents | 24.68 |
| Store.read | 0.55 |
| Store.write | 4.61 |

### MobX

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 5.05 |
| Computed.chain.many_dependents | 293.76 |
| Computed.create | 7.98 |
| Computed.read | 0.27 |
| Computed.recompute | 2.90 |
| Observable.create | 5.71 |
| Observable.notify | 9.75 |
| Observable.notify.many_dependents | 6684.44 |
| Observable.read | 0.04 |
| Observable.write | 6.07 |

### ValueNotifier

| Benchmark | Time (μs) |
|-----------|-----------|
| Computed.chain | 0.25 |
| Computed.chain.many_dependents | 99.81 |
| Computed.create | 5.59 |
| Computed.read | 0.04 |
| Computed.recompute | 0.17 |
| ValueNotifier.create | 1.10 |
| ValueNotifier.notify | 0.12 |
| ValueNotifier.notify.many_dependents | 30.59 |
| ValueNotifier.read | 0.04 |
| ValueNotifier.write | 0.07 |

---

*Generated automatically by `benchmark/bin/run_benchmarks.dart`*
