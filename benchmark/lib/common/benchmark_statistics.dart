import 'package:benchmark/common/benchmark_result.dart';

/// Aggregated measurements for one benchmark across isolated trials.
class BenchmarkStatistics {
  BenchmarkStatistics({
    required this.name,
    required this.library,
    required this.feature,
    required this.timing,
    required List<double> samples,
  }) : samples = List<double>.unmodifiable(samples) {
    if (samples.isEmpty) {
      throw ArgumentError.value(samples, 'samples', 'must not be empty');
    }
  }

  final String name;
  final String library;
  final String feature;
  final BenchmarkTiming timing;
  final List<double> samples;

  late final double median = _median(samples);

  late final double medianAbsoluteDeviation = _median(
    samples.map((sample) => (sample - median).abs()).toList(),
  );

  late final double minimum = samples.reduce((a, b) => a < b ? a : b);
  late final double maximum = samples.reduce((a, b) => a > b ? a : b);

  static double _median(List<double> values) {
    final sorted = values.toList()..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[middle];
    }
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }
}
