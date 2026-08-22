import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/benchmark_statistics.dart';

/// Combines repeated isolated trials and verifies that every trial measured the
/// exact same benchmark identities.
List<BenchmarkStatistics> aggregateBenchmarkTrials(
  List<List<BenchmarkResult>> trials,
) {
  if (trials.isEmpty) {
    throw ArgumentError.value(trials, 'trials', 'must not be empty');
  }

  String keyOf(BenchmarkResult result) =>
      '${result.library}\u0000${result.name}\u0000${result.feature}\u0000'
      '${result.timing.name}';

  final expectedKeys = trials.first.map(keyOf).toSet();
  final grouped = <String, List<BenchmarkResult>>{};

  for (var trialIndex = 0; trialIndex < trials.length; trialIndex++) {
    final trial = trials[trialIndex];
    final trialKeys = trial.map(keyOf).toSet();
    if (trialKeys.length != trial.length ||
        trialKeys.length != expectedKeys.length ||
        !trialKeys.containsAll(expectedKeys)) {
      throw StateError(
        'Trial ${trialIndex + 1} did not contain the expected benchmark set.',
      );
    }

    for (final result in trial) {
      grouped.putIfAbsent(keyOf(result), () => []).add(result);
    }
  }

  final statistics = grouped.values.map((results) {
    final first = results.first;
    return BenchmarkStatistics(
      name: first.name,
      library: first.library,
      feature: first.feature,
      timing: first.timing,
      samples: results.map((result) => result.value).toList(),
    );
  }).toList()
    ..sort((a, b) {
      final libraryComparison = a.library.compareTo(b.library);
      return libraryComparison != 0
          ? libraryComparison
          : a.name.compareTo(b.name);
    });

  return statistics;
}
