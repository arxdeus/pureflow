# Benchmarks

This package compares the native state-management capabilities used by Pureflow and peer Dart packages. The canonical generated report is [BENCHMARK_README.md](BENCHMARK_README.md).

## Run

From the repository root:

```bash
make benchmark
```

The runner fingerprints the executable benchmark inputs, compiles an AOT worker, executes each library in a fresh process for three randomized trials, verifies that the inputs stayed unchanged, aggregates medians and median absolute deviations, records provenance, and regenerates the canonical report.

Custom odd trial counts and deterministic shuffle seeds are supported:

```bash
dart run benchmark/bin/run_benchmarks.dart --trials=5 --seed=2026
```

## Fairness contract

- Every score is reported in microseconds per logical operation.
- Synchronous and asynchronously settled results use separate tables and are
  never compared or ranked against each other.
- Each harness reports one normalized logical operation within its own timing
  domain.
- Batched workloads declare their operation count and are normalized automatically.
- Every library runs in a fresh AOT process for each trial.
- Library order is shuffled independently per trial.
- Setup and teardown are repeated after warmup so measured state starts clean.
- Results use the median, MAD, minimum, maximum, and raw trial samples.
- Lifecycle benchmarks create and use a native object or graph, perform native cleanup where the package exposes it, and otherwise release local ownership.
- Notify benchmarks finish only after the native listeners consume the delivered value.
- Many-dependent benchmarks use exactly 1000 direct dependents.
- Sequential benchmarks enqueue two operations concurrently, verify ordering, and report time per queued operation.
- Correctness sinks consume reads and notifications so measured work cannot be removed as unused.
- Only native package capabilities are included. Missing capabilities are shown as unavailable rather than emulated.

Architectural costs are intentionally retained within each timing domain. For
example, Riverpod uses a `ProviderContainer`, Bloc delivers stream events
asynchronously, and signal libraries retrack effects according to their native
implementation. Equivalent outcomes are compared only when they share the same
synchronous or asynchronously settled completion semantics.

## Native implementations

### State holder

| Package | Native implementation |
|---|---|
| Pureflow | `Store<T>` |
| Bloc | `Cubit<T>` |
| BlocSignals | `CubitSignal<T>` |
| Riverpod | `NotifierProvider<Notifier<T>, T>` |
| Signals | `Signal<T>` |
| AlienSignals | `WritableSignal<T>` |
| Caffeine | `Store<T>` via `Store.accum()` |
| MobX | `Observable<T>` |

Measured operations are lifecycle, read, write where the package exposes a
synchronous native setter, notification to one listener, and notification to
1000 listeners. Caffeine has no synchronous setter, so its write cell is
unavailable; its event-driven state changes are measured in the notification
rows after native stream settlement. Asynchronous notification and
recomputation rows batch 32 logical updates per harness exercise and normalize
the score per update, amortizing the single completion allocation and await.

### Recomputable view

| Package | Native implementation |
|---|---|
| Pureflow | `Computed<T>` |
| Bloc | Unavailable |
| BlocSignals | Not included because its derived values are provided by `signals_core` |
| Riverpod | `Provider<T>` with `ref.watch()` |
| Signals | `Computed<T>` |
| AlienSignals | `Computed<T>` |
| Caffeine | `Store<T>` via `Store.derive()` |
| MobX | `Computed<T>` |

Measured operations are lifecycle, cached read, dependency update plus recomputation, a two-level computed chain, and 1000 direct computed dependents.

### Sequential async concurrency

| Package | Native implementation |
|---|---|
| Pureflow | `Pipeline` with `sequential()` |
| Bloc | `Bloc` with `sequential()` |
| BlocSignals | `BlocSignal` with `sequential()` |
| Caffeine | Event handler with `Concurrency.queue` |
| Other packages | Unavailable or outside the package's native capability set |

Flutter's `ValueNotifier` is not included because the benchmark worker is a
standalone Dart AOT executable and cannot execute Flutter framework code in the
same runtime. A local reimplementation would not be a native comparison, so no
substitute is used.
