# Benchmark Suite

Comprehensive benchmarks comparing Pureflow with popular state management solutions (BLoC, Riverpod, MobX, and Listenable/ValueNotifier).

## Structure

```
benchmark/
├── lib/
│   ├── store/          # Store functionality benchmarks
│   ├── computed/       # Computed/derived state benchmarks
│   ├── equality/       # Equality checking benchmarks
│   ├── pipeline/       # Async event processing benchmarks
│   ├── common/         # Shared test data and utilities
│   └── value_notifier/ # Listenable implementation
├── bin/
│   └── run_all_benchmarks.dart  # Comparison script
└── pubspec.yaml
```

## Prerequisites

1. Install dependencies:
```bash
cd benchmark
dart pub get
```

2. For MobX benchmarks, generate code:
```bash
dart run build_runner build
```

## Running Benchmarks

### Run Individual Benchmark

Run a specific benchmark file:
```bash
dart run lib/store/pureflow_store_benchmark.dart
```

Or from the benchmark directory:
```bash
dart run lib/computed/bloc_computed_benchmark.dart
```

### Run All Benchmarks and Generate Comparison Report

Use the comparison script to run all benchmarks and generate a markdown report:

```bash
dart run bin/run_all_benchmarks.dart
```

Or from the benchmark directory:
```bash
dart run bin/run_all_benchmarks.dart
```

This will:
1. Run all benchmark files for each solution (Pureflow, BLoC, Riverpod, MobX, Listenable)
2. Parse the results from benchmark_harness output
3. Generate `BENCHMARK_REPORT.md` with comparison tables

## Benchmark Categories

### Store Benchmarks (`lib/store/`)
Tests core store functionality:
- **Create store** - Instantiation performance
- **Read value** - Getter performance
- **Set value (different)** - Setter with different values
- **Set value (same)** - Setter with same value (equality check)
- **Add listener** - Listener registration
- **Notify listeners** - Notification dispatch
- **Remove listener** - Listener removal
- **Dependency tracking** - Performance when accessed from computed

### Computed Benchmarks (`lib/computed/`)
Tests derived/computed state:
- **Create computed** - Instantiation performance
- **Read computed** - Getter performance (lazy evaluation)
- **Recompute** - Performance when dependencies change
- **Dependency chain** - Multiple levels of computed dependencies
- **Equality check** - Equality checking in computed values

### Equality Benchmarks (`lib/equality/`)
Tests equality checking performance:
- **Primitive types** (int, String) - Same/different value scenarios
- **Complex objects** - Custom class equality comparison
- **Collections** (List, Map) - Deep equality comparison
- **Isolated equality check** - Pure equality check time
- **Set with equality** - Full set operation including equality overhead

### Pipeline Benchmarks (`lib/pipeline/`)
Tests async event processing:
- **Sequential** - One task at a time execution
- **Concurrent** - Parallel task execution
- **Cancellation** - Task cancellation/restart behavior

## Output Format

The comparison report (`BENCHMARK_REPORT.md`) contains markdown tables showing:

- **Benchmark name** - The specific operation being measured
- **Results for each solution** - Pureflow, BLoC, Riverpod, MobX, Listenable
- **Performance metrics** - Time in microseconds (us), milliseconds (ms), etc.

**Lower values indicate better performance.**

Example table:
```
| Benchmark | Pureflow | BLoC | Riverpod | MobX | Listenable |
|-----------|----------|------|----------|------|------------|
| Store.read | 0.5 us | 1.2 us | 0.8 us | 2.1 us | 0.6 us |
```

## Notes

- ✅ All benchmarks use **identical logic** for fair comparison
- ⚠️ Results may vary based on system configuration and load
- 🔧 MobX requires code generation before running benchmarks
- ℹ️ Some BLoC warnings about `emit` usage are expected in benchmarks
- 📊 Each benchmark file contains multiple benchmarks that run sequentially

## Benchmark Solutions

- **Pureflow** - The library being benchmarked
- **BLoC** - Using `bloc` package (Cubit pattern)
- **Riverpod** - Using `riverpod` package (StateProvider)
- **MobX** - Using `mobx` package (Observable pattern)
- **Listenable** - Using Flutter's `ValueNotifier` pattern

## Troubleshooting

### MobX Code Generation Errors
If MobX benchmarks fail, ensure code generation is complete:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Missing Dependencies
Ensure all dependencies are installed:
```bash
dart pub get
```

### Benchmark Not Found
Make sure you're running from the correct directory or use absolute paths.
