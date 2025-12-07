import 'package:benchmark_harness/benchmark_harness.dart';

/// Custom ScoreEmitter that collects results instead of printing
class CollectingScoreEmitter implements ScoreEmitter {
  final List<BenchmarkResult> results = [];
  final String Function(String benchmarkName) extractFeature;

  CollectingScoreEmitter(this.extractFeature);

  @override
  void emit(String testName, double value) {
    // Parse testName format: "Library: BenchmarkName"
    final parts = testName.split(':');
    if (parts.length >= 2) {
      final library = parts[0].trim();
      final benchmarkName = parts.sublist(1).join(':').trim();
      final feature = extractFeature(benchmarkName);

      results.add(BenchmarkResult(
        name: benchmarkName,
        library: library,
        feature: feature,
        value: value,
      ));
    }
  }
}

/// Benchmark result structure
class BenchmarkResult {
  final String name;
  final String library;
  final String feature;
  final double value; // in microseconds

  BenchmarkResult({
    required this.name,
    required this.library,
    required this.feature,
    required this.value,
  });
}
