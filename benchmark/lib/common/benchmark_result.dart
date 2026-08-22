import 'package:benchmark_harness/benchmark_harness.dart';

enum BenchmarkTiming {
  synchronous('Synchronous'),
  asyncSettled('Async settled');

  const BenchmarkTiming(this.label);

  final String label;
}

/// Custom ScoreEmitter that collects results instead of printing
class CollectingScoreEmitter implements ScoreEmitter {
  final List<BenchmarkResult> results = [];
  final String Function(String benchmarkName) extractFeature;
  final BenchmarkTiming Function(String benchmarkName) extractTiming;

  CollectingScoreEmitter(this.extractFeature, this.extractTiming);

  @override
  void emit(String testName, double value) {
    // Parse testName format: "Library: BenchmarkName"
    final parts = testName.split(':');
    if (parts.length >= 2) {
      final library = parts[0].trim();
      final benchmarkName = parts.sublist(1).join(':').trim();
      final feature = extractFeature(benchmarkName);
      final timing = extractTiming(benchmarkName);

      results.add(BenchmarkResult(
        name: benchmarkName,
        library: library,
        feature: feature,
        timing: timing,
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
  final BenchmarkTiming timing;
  final double value; // in microseconds

  BenchmarkResult({
    required this.name,
    required this.library,
    required this.feature,
    required this.timing,
    required this.value,
  });

  factory BenchmarkResult.fromJson(Map<String, Object?> json) {
    return BenchmarkResult(
      name: json['name']! as String,
      library: json['library']! as String,
      feature: json['feature']! as String,
      timing: BenchmarkTiming.values.byName(json['timing']! as String),
      value: (json['value']! as num).toDouble(),
    );
  }

  Map<String, Object> toJson() => {
        'name': name,
        'library': library,
        'feature': feature,
        'timing': timing.name,
        'value': value,
      };
}
