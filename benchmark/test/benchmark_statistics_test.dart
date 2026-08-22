import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/benchmark_statistics.dart';
import 'package:test/test.dart';

void main() {
  group('BenchmarkStatistics', () {
    test('uses the median and median absolute deviation', () {
      final statistics = BenchmarkStatistics(
        name: 'Store.read',
        library: 'Example',
        feature: 'State Holder: Read',
        timing: BenchmarkTiming.synchronous,
        samples: const [12, 10, 11, 100, 9],
      );

      expect(statistics.median, 11);
      expect(statistics.medianAbsoluteDeviation, 1);
      expect(statistics.minimum, 9);
      expect(statistics.maximum, 100);
      expect(statistics.timing, BenchmarkTiming.synchronous);
    });

    test('averages the middle pair for even sample counts', () {
      final statistics = BenchmarkStatistics(
        name: 'Store.read',
        library: 'Example',
        feature: 'State Holder: Read',
        timing: BenchmarkTiming.synchronous,
        samples: const [4, 1, 3, 2],
      );

      expect(statistics.median, 2.5);
      expect(statistics.medianAbsoluteDeviation, 1);
    });

    test('rejects empty samples', () {
      expect(
        () => BenchmarkStatistics(
          name: 'Store.read',
          library: 'Example',
          feature: 'State Holder: Read',
          timing: BenchmarkTiming.synchronous,
          samples: const [],
        ),
        throwsArgumentError,
      );
    });
  });
}
