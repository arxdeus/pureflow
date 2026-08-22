import 'package:benchmark_harness/benchmark_harness.dart' as harness;

export 'package:benchmark_harness/benchmark_harness.dart'
    show PrintEmitter, ScoreEmitter;

/// A synchronous benchmark whose reported score represents one [run] call.
///
/// `benchmark_harness` executes synchronous [run] methods ten times per
/// exercise, while its async harness executes once. Overriding [exercise]
/// keeps every score in this package in microseconds per operation.
abstract class BenchmarkBase extends harness.BenchmarkBase {
  const BenchmarkBase(
    super.name, {
    super.emitter,
    this.operationsPerRun = 1,
    this.warmupDurationMillis = 100,
    this.measureDurationMillis = 2000,
  })  : assert(operationsPerRun > 0, 'operationsPerRun must be positive'),
        assert(warmupDurationMillis > 0, 'warmup duration must be positive'),
        assert(measureDurationMillis > 0, 'measure duration must be positive');

  final int operationsPerRun;
  final int warmupDurationMillis;
  final int measureDurationMillis;

  @override
  void exercise() {
    run();
  }

  @override
  double measure() {
    setup();
    try {
      harness.BenchmarkBase.measureFor(warmup, warmupDurationMillis);
    } finally {
      teardown();
    }

    setup();
    try {
      return harness.BenchmarkBase.measureFor(exercise, measureDurationMillis) /
          operationsPerRun;
    } finally {
      teardown();
    }
  }
}

/// A synchronous benchmark with lifecycle work that must be awaited.
///
/// This keeps Future creation and scheduling out of the timed operation while
/// still guaranteeing that asynchronous native teardown completes before the
/// next phase starts.
abstract class SyncRunAsyncLifecycleBenchmarkBase {
  const SyncRunAsyncLifecycleBenchmarkBase(
    this.name, {
    this.emitter = const harness.PrintEmitter(),
    this.operationsPerRun = 1,
    this.warmupDurationMillis = 100,
    this.measureDurationMillis = 2000,
  })  : assert(operationsPerRun > 0, 'operationsPerRun must be positive'),
        assert(warmupDurationMillis > 0, 'warmup duration must be positive'),
        assert(measureDurationMillis > 0, 'measure duration must be positive');

  final String name;
  final harness.ScoreEmitter emitter;
  final int operationsPerRun;
  final int warmupDurationMillis;
  final int measureDurationMillis;

  Future<void> setup() async {}

  void run();

  void warmup() {
    run();
  }

  void exercise() {
    run();
  }

  Future<void> teardown() async {}

  Future<double> measure() async {
    await setup();
    try {
      harness.BenchmarkBase.measureFor(warmup, warmupDurationMillis);
    } finally {
      await teardown();
    }

    await setup();
    try {
      return harness.BenchmarkBase.measureFor(
            exercise,
            measureDurationMillis,
          ) /
          operationsPerRun;
    } finally {
      await teardown();
    }
  }

  Future<void> report() async {
    emitter.emit(name, await measure());
  }
}

/// Async counterpart that also reports microseconds per logical operation.
abstract class AsyncBenchmarkBase extends harness.AsyncBenchmarkBase {
  const AsyncBenchmarkBase(
    super.name, {
    super.emitter,
    this.operationsPerRun = 1,
    this.warmupDurationMillis = 100,
    this.measureDurationMillis = 2000,
  })  : assert(operationsPerRun > 0, 'operationsPerRun must be positive'),
        assert(warmupDurationMillis > 0, 'warmup duration must be positive'),
        assert(measureDurationMillis > 0, 'measure duration must be positive');

  final int operationsPerRun;
  final int warmupDurationMillis;
  final int measureDurationMillis;

  @override
  Future<double> measure() async {
    await setup();
    try {
      await harness.AsyncBenchmarkBase.measureFor(
        warmup,
        warmupDurationMillis,
      );
    } finally {
      await teardown();
    }

    await setup();
    try {
      return await harness.AsyncBenchmarkBase.measureFor(
            exercise,
            measureDurationMillis,
          ) /
          operationsPerRun;
    } finally {
      await teardown();
    }
  }
}
