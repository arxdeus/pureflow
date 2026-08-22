import 'package:benchmark/common/benchmark_result.dart';
import 'package:test/test.dart';

void main() {
  test('serializes and restores the benchmark timing domain', () {
    final result = BenchmarkResult(
      name: 'Cubit.notify',
      library: 'Bloc',
      feature: 'State Holder: Notify',
      timing: BenchmarkTiming.asyncSettled,
      value: 1.25,
    );

    expect(BenchmarkResult.fromJson(result.toJson()).timing,
        BenchmarkTiming.asyncSettled);
    expect(result.toJson()['timing'], 'asyncSettled');
  });

  test('collecting emitter classifies each benchmark timing domain', () {
    final emitter = CollectingScoreEmitter(
      (_) => 'State Holder: Notify',
      (_) => BenchmarkTiming.asyncSettled,
    );

    emitter.emit('Bloc: Cubit.notify', 2);

    expect(emitter.results.single.timing, BenchmarkTiming.asyncSettled);
  });
}
