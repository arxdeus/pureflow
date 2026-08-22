import 'package:benchmark/common/fair_benchmark_base.dart';
import 'package:test/test.dart';

class _CountingBenchmark extends BenchmarkBase {
  _CountingBenchmark()
      : super(
          'counting',
          warmupDurationMillis: 1,
          measureDurationMillis: 1,
        );

  int runs = 0;
  int setups = 0;
  int teardowns = 0;

  @override
  void setup() {
    setups++;
    runs = 0;
  }

  @override
  void run() {
    runs++;
  }

  @override
  void teardown() {
    teardowns++;
  }
}

class _AsyncLifecycleCountingBenchmark
    extends SyncRunAsyncLifecycleBenchmarkBase {
  _AsyncLifecycleCountingBenchmark()
      : super(
          'async lifecycle counting',
          warmupDurationMillis: 1,
          measureDurationMillis: 1,
        );

  int runs = 0;
  int setups = 0;
  int teardowns = 0;
  bool cleanupCompleted = true;

  @override
  Future<void> setup() async {
    expect(cleanupCompleted, isTrue);
    setups++;
    runs = 0;
    cleanupCompleted = false;
  }

  @override
  void run() {
    runs++;
  }

  @override
  Future<void> teardown() async {
    await Future<void>.delayed(Duration.zero);
    teardowns++;
    cleanupCompleted = true;
  }
}

void main() {
  test('one synchronous exercise represents one operation', () {
    final benchmark = _CountingBenchmark();

    benchmark.exercise();

    expect(benchmark.runs, 1);
  });

  test('measurement resets setup between warmup and measured work', () {
    final benchmark = _CountingBenchmark();

    benchmark.measure();

    expect(benchmark.setups, 2);
    expect(benchmark.teardowns, 2);
    expect(benchmark.runs, greaterThan(0));
  });

  test('synchronous work awaits asynchronous cleanup between phases', () async {
    final benchmark = _AsyncLifecycleCountingBenchmark();

    await benchmark.measure();

    expect(benchmark.setups, 2);
    expect(benchmark.teardowns, 2);
    expect(benchmark.cleanupCompleted, isTrue);
    expect(benchmark.runs, greaterThan(0));
  });
}
