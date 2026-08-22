import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/benchmark_trial_aggregation.dart';
import 'package:test/test.dart';

BenchmarkResult _result(
  double value, {
  String name = 'Store.read',
  BenchmarkTiming timing = BenchmarkTiming.synchronous,
}) {
  return BenchmarkResult(
    name: name,
    library: 'Example',
    feature: 'State Holder: Read',
    timing: timing,
    value: value,
  );
}

void main() {
  test('aggregates matching isolated trials by benchmark identity', () {
    final statistics = aggregateBenchmarkTrials([
      [_result(3)],
      [_result(1)],
      [_result(2)],
    ]);

    expect(statistics, hasLength(1));
    expect(statistics.single.samples, [3, 1, 2]);
    expect(statistics.single.median, 2);
    expect(statistics.single.timing, BenchmarkTiming.synchronous);
  });

  test('rejects trials with missing benchmark results', () {
    expect(
      () => aggregateBenchmarkTrials([
        [_result(1)],
        [_result(2, name: 'Store.write')],
      ]),
      throwsStateError,
    );
  });

  test('rejects trials that change a benchmark timing domain', () {
    expect(
      () => aggregateBenchmarkTrials([
        [_result(1)],
        [_result(2, timing: BenchmarkTiming.asyncSettled)],
      ]),
      throwsStateError,
    );
  });
}
