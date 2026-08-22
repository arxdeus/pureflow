# Benchmark Results

All values are median microseconds per logical operation across 3 isolated AOT trials. Dispersion is median absolute deviation (MAD). Lower is better.

## Methodology

- Synchronous operations and asynchronously settled operations are reported in separate tables and are never ranked against each other.
- Every score is normalized to one logical operation within its timing domain.
- Each library runs in a fresh AOT process for every trial.
- Library order is shuffled independently per trial with seed `1337`.
- Executable benchmark inputs are fingerprinted before compilation and verified unchanged after all trials.
- `benchmark_harness` warms each benchmark for at least 100 ms and measures it for at least 2 seconds.
- Setup and teardown run again after warmup so measured state starts clean.
- Lifecycle rows create and use a native object or graph, perform native cleanup where available, and otherwise release local ownership.
- Notify rows complete only after the native listener workload consumed the delivered value.
- Sequential rows enqueue two operations concurrently, verify their order, and divide elapsed time by two.
- Native architectural costs are retained. No compatibility layers or emulated package capabilities are used.

## Provenance

| Property | Value |
|---|---|
| Generated | `2026-08-23T00:30:00.353097Z` |
| Benchmark source snapshot | `633752ce913cce6f10a9ee68903883b0daa93a41` |
| Runtime | AOT executable |
| Dart | `3.13.0 (stable) (Wed Aug 5 00:28:05 2026 -0700) on "macos_arm64"` |
| OS | `macos Version 26.4.1 (Build 25E253)` |
| CPU | `Apple M5 Pro` |
| Logical processors | 15 |
| Trials | 3 |
| Random seed | 1337 |

### Package versions

| Package | Version |
|---|---|
| `alien_signals` | `2.3.1` |
| `benchmark_harness` | `2.4.0` |
| `bloc` | `9.2.1` |
| `bloc_concurrency` | `0.3.0` |
| `bloc_signals` | `1.0.1` |
| `caffeine` | `3.0.0` |
| `mobx` | `2.6.0` |
| `pureflow` | `1.2.0` |
| `riverpod` | `3.3.2` |
| `signals_core` | `7.0.0` |

## Synchronous Results Summary

| Feature | [Pureflow](https://pub.dev/packages/pureflow) | [Bloc](https://pub.dev/packages/bloc) | [BlocSignals](https://pub.dev/packages/bloc_signals) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [Caffeine](https://pub.dev/packages/caffeine) | [MobX](https://pub.dev/packages/mobx) |
|---|---|---|---|---|---|---|---|---|
| State Holder: Lifecycle (Create + Use + Release) | 0.0100 ± 0.0000 μs | — | — | 2.04 ± 0.10 μs | 0.0374 ± 0.0000 μs | 0.0092 ± 0.0000 μs | 0.32 ± 0.0005 μs | 0.0920 ± 0.0001 μs |
| State Holder: Read | 0.0057 ± 0.0000 μs | 0.0037 ± 0.0000 μs | 0.0102 ± 0.0001 μs | 0.17 ± 0.0162 μs | 0.0078 ± 0.0000 μs | 0.0077 ± 0.0000 μs | 0.0433 ± 0.0001 μs | 0.0160 ± 0.0000 μs |
| State Holder: Write | 0.0061 ± 0.0000 μs | 0.0124 ± 0.0000 μs | 0.0477 ± 0.0000 μs | 0.68 ± 0.0420 μs | 0.0170 ± 0.0000 μs | 0.0083 ± 0.0000 μs | — | 0.0459 ± 0.0001 μs |
| State Holder: Notify | 0.0127 ± 0.0001 μs | — | 0.0758 ± 0.0004 μs | 0.66 ± 0.0042 μs | 0.0394 ± 0.0000 μs | 0.0280 ± 0.0001 μs | — | 0.97 ± 0.0093 μs |
| State Holder: Notify - Many Dependents (1000) | 3.26 ± 0.0044 μs | — | 30.06 ± 0.36 μs | 25.86 ± 0.84 μs | 30.30 ± 0.0152 μs | 20.39 ± 0.0337 μs | — | 638.03 ± 2.70 μs |
| Recomputable View: Lifecycle (Create + Evaluate + Release) | 0.0435 ± 0.0002 μs | — | — | 3.06 ± 0.0820 μs | 0.0936 ± 0.0003 μs | 0.0346 ± 0.0001 μs | 0.57 ± 0.0029 μs | 0.39 ± 0.0018 μs |
| Recomputable View: Read | 0.0059 ± 0.0000 μs | — | — | 0.25 ± 0.0169 μs | 0.0108 ± 0.0000 μs | 0.0081 ± 0.0001 μs | 0.0530 ± 0.0000 μs | 0.0143 ± 0.0000 μs |
| Recomputable View: Recompute | 0.0206 ± 0.0001 μs | — | — | 1.69 ± 0.0357 μs | 0.0312 ± 0.0002 μs | 0.0264 ± 0.0001 μs | — | 0.52 ± 0.0011 μs |
| Recomputable View: Chain | 0.0399 ± 0.0005 μs | — | — | 2.82 ± 0.15 μs | 0.0559 ± 0.0003 μs | 0.0476 ± 0.0001 μs | — | 0.82 ± 0.0008 μs |
| Recomputable View: Many Dependents (1000) | 17.25 ± 0.0042 μs | — | — | 11128.48 ± 15.28 μs | 23.72 ± 0.39 μs | 18.14 ± 0.10 μs | — | 226.68 ± 2.39 μs |

## Synchronous Performance Comparison (vs Pureflow median)

Percentages compare medians only within the synchronous timing domain. Positive values are slower than Pureflow and negative values are faster.

| Feature | [Bloc](https://pub.dev/packages/bloc) | [BlocSignals](https://pub.dev/packages/bloc_signals) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [Caffeine](https://pub.dev/packages/caffeine) | [MobX](https://pub.dev/packages/mobx) |
|---|---|---|---|---|---|---|---|
| State Holder: Lifecycle (Create + Use + Release) | — | — | 20318.6% | 273.8% | -7.9% | 3051.2% | 819.1% |
| State Holder: Read | -34.4% | 79.7% | 2814.8% | 37.1% | 35.9% | 660.3% | 180.6% |
| State Holder: Write | 102.4% | 677.5% | 11052.8% | 177.2% | 36.1% | — | 647.2% |
| State Holder: Notify | — | 495.9% | 5104.5% | 209.7% | 120.2% | — | 7495.3% |
| State Holder: Notify - Many Dependents (1000) | — | 821.9% | 693.1% | 829.3% | 525.4% | — | 19466.5% |
| Recomputable View: Lifecycle (Create + Evaluate + Release) | — | — | 6934.4% | 115.1% | -20.5% | 1206.2% | 785.5% |
| Recomputable View: Read | — | — | 4206.2% | 83.8% | 38.7% | 804.8% | 144.2% |
| Recomputable View: Recompute | — | — | 8099.6% | 51.4% | 27.8% | — | 2424.0% |
| Recomputable View: Chain | — | — | 6971.6% | 40.1% | 19.3% | — | 1948.6% |
| Recomputable View: Many Dependents (1000) | — | — | 64413.1% | 37.5% | 5.2% | — | 1214.1% |

## Asynchronously Settled Results Summary

| Feature | [Pureflow](https://pub.dev/packages/pureflow) | [Bloc](https://pub.dev/packages/bloc) | [BlocSignals](https://pub.dev/packages/bloc_signals) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [Caffeine](https://pub.dev/packages/caffeine) | [MobX](https://pub.dev/packages/mobx) |
|---|---|---|---|---|---|---|---|---|
| State Holder: Lifecycle (Create + Use + Release) | — | 0.64 ± 0.0013 μs | 1.24 ± 0.0074 μs | — | — | — | — | — |
| State Holder: Notify | — | 0.0592 ± 0.0007 μs | — | — | — | — | 0.79 ± 0.0016 μs | — |
| State Holder: Notify - Many Dependents (1000) | — | 40.38 ± 0.44 μs | — | — | — | — | 16.10 ± 0.0065 μs | — |
| Recomputable View: Recompute | — | — | — | — | — | — | 1.08 ± 0.0061 μs | — |
| Recomputable View: Chain | — | — | — | — | — | — | 1.34 ± 0.0103 μs | — |
| Recomputable View: Many Dependents (1000) | — | — | — | — | — | — | 347.05 ± 0.68 μs | — |
| Async Concurrency: Sequential | 4.41 ± 0.0105 μs | 4.54 ± 0.0482 μs | 4.91 ± 0.0333 μs | — | — | — | 4.44 ± 0.0484 μs | — |

## Asynchronously Settled Performance Comparison (vs Pureflow median)

Percentages compare medians only within the async settled timing domain. Positive values are slower than Pureflow and negative values are faster.

| Feature | [Bloc](https://pub.dev/packages/bloc) | [BlocSignals](https://pub.dev/packages/bloc_signals) | [Riverpod](https://pub.dev/packages/riverpod) | [Signals](https://pub.dev/packages/signals_core) | [AlienSignals](https://pub.dev/packages/alien_signals) | [Caffeine](https://pub.dev/packages/caffeine) | [MobX](https://pub.dev/packages/mobx) |
|---|---|---|---|---|---|---|---|
| Async Concurrency: Sequential | 2.9% | 11.4% | — | — | — | 0.7% | — |

## Detailed Results

### Pureflow

| Benchmark | Timing | Median (μs/op) | MAD | Min | Max | Samples |
|---|---|---:|---:|---:|---:|---|
| Computed.chain | Synchronous | 0.0399 | 0.0005 | 0.0394 | 0.0406 | 0.0406, 0.0399, 0.0394 |
| Computed.lifecycle | Synchronous | 0.0435 | 0.0002 | 0.0432 | 0.0437 | 0.0435, 0.0437, 0.0432 |
| Computed.many_dependents | Synchronous | 17.25 | 0.0042 | 17.25 | 17.60 | 17.25, 17.25, 17.60 |
| Computed.read | Synchronous | 0.0059 | 0.0000 | 0.0058 | 0.0059 | 0.0059, 0.0059, 0.0058 |
| Computed.recompute | Synchronous | 0.0206 | 0.0001 | 0.0202 | 0.0207 | 0.0206, 0.0207, 0.0202 |
| Store.lifecycle | Synchronous | 0.0100 | 0.0000 | 0.0100 | 0.0100 | 0.0100, 0.0100, 0.0100 |
| Store.notify | Synchronous | 0.0127 | 0.0001 | 0.0126 | 0.0129 | 0.0126, 0.0129, 0.0127 |
| Store.notify.many_dependents | Synchronous | 3.26 | 0.0044 | 3.26 | 3.31 | 3.26, 3.31, 3.26 |
| Store.read | Synchronous | 0.0057 | 0.0000 | 0.0057 | 0.0058 | 0.0057, 0.0058, 0.0057 |
| Store.write | Synchronous | 0.0061 | 0.0000 | 0.0061 | 0.0061 | 0.0061, 0.0061, 0.0061 |
| Pipeline.sequential | Async settled | 4.41 | 0.0105 | 4.34 | 4.42 | 4.41, 4.34, 4.42 |

### Bloc

| Benchmark | Timing | Median (μs/op) | MAD | Min | Max | Samples |
|---|---|---:|---:|---:|---:|---|
| Cubit.read | Synchronous | 0.0037 | 0.0000 | 0.0037 | 0.0037 | 0.0037, 0.0037, 0.0037 |
| Cubit.write | Synchronous | 0.0124 | 0.0000 | 0.0124 | 0.0126 | 0.0126, 0.0124, 0.0124 |
| Cubit.lifecycle | Async settled | 0.64 | 0.0013 | 0.63 | 0.64 | 0.64, 0.64, 0.63 |
| Cubit.notify | Async settled | 0.0592 | 0.0007 | 0.0585 | 0.0612 | 0.0592, 0.0612, 0.0585 |
| Cubit.notify.many_dependents | Async settled | 40.38 | 0.44 | 39.94 | 41.38 | 41.38, 40.38, 39.94 |
| Sequential | Async settled | 4.54 | 0.0482 | 4.41 | 4.58 | 4.54, 4.41, 4.58 |

### BlocSignals

| Benchmark | Timing | Median (μs/op) | MAD | Min | Max | Samples |
|---|---|---:|---:|---:|---:|---|
| CubitSignal.notify | Synchronous | 0.0758 | 0.0004 | 0.0754 | 0.0762 | 0.0758, 0.0754, 0.0762 |
| CubitSignal.notify.many_dependents | Synchronous | 30.06 | 0.36 | 29.70 | 30.54 | 30.06, 30.54, 29.70 |
| CubitSignal.read | Synchronous | 0.0102 | 0.0001 | 0.0101 | 0.0108 | 0.0102, 0.0101, 0.0108 |
| CubitSignal.write | Synchronous | 0.0477 | 0.0000 | 0.0475 | 0.0477 | 0.0477, 0.0475, 0.0477 |
| CubitSignal.lifecycle | Async settled | 1.24 | 0.0074 | 1.23 | 1.25 | 1.25, 1.23, 1.24 |
| Sequential | Async settled | 4.91 | 0.0333 | 4.88 | 4.95 | 4.91, 4.95, 4.88 |

### Riverpod

| Benchmark | Timing | Median (μs/op) | MAD | Min | Max | Samples |
|---|---|---:|---:|---:|---:|---|
| Computed.chain | Synchronous | 2.82 | 0.15 | 2.67 | 3.01 | 2.67, 2.82, 3.01 |
| Computed.lifecycle | Synchronous | 3.06 | 0.0820 | 2.87 | 3.14 | 2.87, 3.06, 3.14 |
| Computed.many_dependents | Synchronous | 11128.48 | 15.28 | 10821.35 | 11143.75 | 10821.35, 11143.75, 11128.48 |
| Computed.read | Synchronous | 0.25 | 0.0169 | 0.24 | 0.28 | 0.24, 0.25, 0.28 |
| Computed.recompute | Synchronous | 1.69 | 0.0357 | 1.65 | 1.73 | 1.69, 1.65, 1.73 |
| NotifierProvider.lifecycle | Synchronous | 2.04 | 0.10 | 1.94 | 2.20 | 1.94, 2.04, 2.20 |
| NotifierProvider.notify | Synchronous | 0.66 | 0.0042 | 0.66 | 0.73 | 0.66, 0.66, 0.73 |
| NotifierProvider.notify.many_dependents | Synchronous | 25.86 | 0.84 | 25.03 | 30.91 | 25.03, 25.86, 30.91 |
| NotifierProvider.read | Synchronous | 0.17 | 0.0162 | 0.15 | 0.18 | 0.15, 0.17, 0.18 |
| NotifierProvider.write | Synchronous | 0.68 | 0.0420 | 0.64 | 0.73 | 0.64, 0.68, 0.73 |

### Signals

| Benchmark | Timing | Median (μs/op) | MAD | Min | Max | Samples |
|---|---|---:|---:|---:|---:|---|
| Computed.chain | Synchronous | 0.0559 | 0.0003 | 0.0556 | 0.0562 | 0.0559, 0.0562, 0.0556 |
| Computed.lifecycle | Synchronous | 0.0936 | 0.0003 | 0.0932 | 0.0948 | 0.0936, 0.0932, 0.0948 |
| Computed.many_dependents | Synchronous | 23.72 | 0.39 | 23.04 | 24.11 | 23.72, 23.04, 24.11 |
| Computed.read | Synchronous | 0.0108 | 0.0000 | 0.0107 | 0.0108 | 0.0108, 0.0108, 0.0107 |
| Computed.recompute | Synchronous | 0.0312 | 0.0002 | 0.0310 | 0.0329 | 0.0312, 0.0310, 0.0329 |
| Signal.lifecycle | Synchronous | 0.0374 | 0.0000 | 0.0374 | 0.0378 | 0.0374, 0.0374, 0.0378 |
| Signal.notify | Synchronous | 0.0394 | 0.0000 | 0.0393 | 0.0394 | 0.0394, 0.0393, 0.0394 |
| Signal.notify.many_dependents | Synchronous | 30.30 | 0.0152 | 30.29 | 30.87 | 30.29, 30.87, 30.30 |
| Signal.read | Synchronous | 0.0078 | 0.0000 | 0.0076 | 0.0079 | 0.0078, 0.0076, 0.0079 |
| Signal.write | Synchronous | 0.0170 | 0.0000 | 0.0168 | 0.0171 | 0.0170, 0.0171, 0.0168 |

### AlienSignals

| Benchmark | Timing | Median (μs/op) | MAD | Min | Max | Samples |
|---|---|---:|---:|---:|---:|---|
| Computed.chain | Synchronous | 0.0476 | 0.0001 | 0.0475 | 0.0481 | 0.0475, 0.0481, 0.0476 |
| Computed.lifecycle | Synchronous | 0.0346 | 0.0001 | 0.0345 | 0.0350 | 0.0346, 0.0345, 0.0350 |
| Computed.many_dependents | Synchronous | 18.14 | 0.10 | 18.04 | 18.39 | 18.39, 18.04, 18.14 |
| Computed.read | Synchronous | 0.0081 | 0.0001 | 0.0080 | 0.0082 | 0.0082, 0.0081, 0.0080 |
| Computed.recompute | Synchronous | 0.0264 | 0.0001 | 0.0262 | 0.0272 | 0.0272, 0.0264, 0.0262 |
| Signal.lifecycle | Synchronous | 0.0092 | 0.0000 | 0.0092 | 0.0093 | 0.0092, 0.0093, 0.0092 |
| Signal.notify | Synchronous | 0.0280 | 0.0001 | 0.0279 | 0.0284 | 0.0284, 0.0280, 0.0279 |
| Signal.notify.many_dependents | Synchronous | 20.39 | 0.0337 | 19.84 | 20.43 | 20.39, 20.43, 19.84 |
| Signal.read | Synchronous | 0.0077 | 0.0000 | 0.0077 | 0.0078 | 0.0077, 0.0078, 0.0077 |
| Signal.write | Synchronous | 0.0083 | 0.0000 | 0.0083 | 0.0084 | 0.0083, 0.0083, 0.0084 |

### Caffeine

| Benchmark | Timing | Median (μs/op) | MAD | Min | Max | Samples |
|---|---|---:|---:|---:|---:|---|
| Computed.lifecycle | Synchronous | 0.57 | 0.0029 | 0.57 | 0.57 | 0.57, 0.57, 0.57 |
| Computed.read | Synchronous | 0.0530 | 0.0000 | 0.0527 | 0.0530 | 0.0527, 0.0530, 0.0530 |
| Store.lifecycle | Synchronous | 0.32 | 0.0005 | 0.32 | 0.32 | 0.32, 0.32, 0.32 |
| Store.read | Synchronous | 0.0433 | 0.0001 | 0.0427 | 0.0434 | 0.0427, 0.0433, 0.0434 |
| Computed.chain | Async settled | 1.34 | 0.0103 | 1.33 | 1.35 | 1.35, 1.33, 1.34 |
| Computed.many_dependents | Async settled | 347.05 | 0.68 | 342.96 | 347.74 | 342.96, 347.74, 347.05 |
| Computed.recompute | Async settled | 1.08 | 0.0061 | 1.07 | 1.09 | 1.09, 1.07, 1.08 |
| Sequential | Async settled | 4.44 | 0.0484 | 4.38 | 4.49 | 4.49, 4.38, 4.44 |
| Store.notify | Async settled | 0.79 | 0.0016 | 0.79 | 0.80 | 0.80, 0.79, 0.79 |
| Store.notify.many_dependents | Async settled | 16.10 | 0.0065 | 15.97 | 16.10 | 16.10, 15.97, 16.10 |

### MobX

| Benchmark | Timing | Median (μs/op) | MAD | Min | Max | Samples |
|---|---|---:|---:|---:|---:|---|
| Computed.chain | Synchronous | 0.82 | 0.0008 | 0.82 | 0.82 | 0.82, 0.82, 0.82 |
| Computed.lifecycle | Synchronous | 0.39 | 0.0018 | 0.38 | 0.39 | 0.39, 0.38, 0.39 |
| Computed.many_dependents | Synchronous | 226.68 | 2.39 | 224.29 | 230.81 | 226.68, 224.29, 230.81 |
| Computed.read | Synchronous | 0.0143 | 0.0000 | 0.0143 | 0.0143 | 0.0143, 0.0143, 0.0143 |
| Computed.recompute | Synchronous | 0.52 | 0.0011 | 0.52 | 0.52 | 0.52, 0.52, 0.52 |
| Observable.lifecycle | Synchronous | 0.0920 | 0.0001 | 0.0916 | 0.0922 | 0.0916, 0.0920, 0.0922 |
| Observable.notify | Synchronous | 0.97 | 0.0093 | 0.96 | 1.00 | 1.00, 0.97, 0.96 |
| Observable.notify.many_dependents | Synchronous | 638.03 | 2.70 | 635.34 | 645.79 | 638.03, 635.34, 645.79 |
| Observable.read | Synchronous | 0.0160 | 0.0000 | 0.0159 | 0.0160 | 0.0160, 0.0160, 0.0159 |
| Observable.write | Synchronous | 0.0459 | 0.0001 | 0.0454 | 0.0459 | 0.0459, 0.0454, 0.0459 |

---

*Generated automatically by `benchmark/bin/run_benchmarks.dart`.*
