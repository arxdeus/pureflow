import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/benchmark_statistics.dart';

class BenchmarkLibrarySpec {
  const BenchmarkLibrarySpec(this.displayName, this.url);

  final String displayName;
  final String url;

  String get header => '[$displayName]($url)';
}

class BenchmarkReportProvenance {
  const BenchmarkReportProvenance({
    required this.generatedAt,
    required this.sourceFingerprint,
    required this.dartVersion,
    required this.operatingSystem,
    required this.cpu,
    required this.logicalProcessors,
    required this.trials,
    required this.seed,
    required this.packageVersions,
  });

  final String generatedAt;
  final String sourceFingerprint;
  final String dartVersion;
  final String operatingSystem;
  final String cpu;
  final int logicalProcessors;
  final int trials;
  final int seed;
  final Map<String, String> packageVersions;
}

String renderBenchmarkReport({
  required List<BenchmarkStatistics> statistics,
  required BenchmarkReportProvenance provenance,
  required List<BenchmarkLibrarySpec> libraries,
  required List<String> featureOrder,
}) {
  final byTimingAndFeature =
      <BenchmarkTiming, Map<String, Map<String, BenchmarkStatistics>>>{};
  final byLibrary = <String, List<BenchmarkStatistics>>{};
  for (final result in statistics) {
    byTimingAndFeature
        .putIfAbsent(result.timing, () => {})
        .putIfAbsent(result.feature, () => {})[result.library] = result;
    byLibrary.putIfAbsent(result.library, () => []).add(result);
  }

  List<String> orderedFeatures(BenchmarkTiming timing) {
    final features = byTimingAndFeature[timing]?.keys.toList() ?? <String>[];
    features.sort((a, b) {
      final aIndex = featureOrder.indexOf(a);
      final bIndex = featureOrder.indexOf(b);
      if (aIndex == -1 && bIndex == -1) return a.compareTo(b);
      if (aIndex == -1) return 1;
      if (bIndex == -1) return -1;
      return aIndex.compareTo(bIndex);
    });
    return features;
  }

  final buffer = StringBuffer()
    ..writeln('# Benchmark Results')
    ..writeln()
    ..writeln(
      'All values are median microseconds per logical operation across '
      '${provenance.trials} isolated AOT trials. Dispersion is median absolute '
      'deviation (MAD). Lower is better.',
    )
    ..writeln()
    ..writeln('## Methodology')
    ..writeln()
    ..writeln(
      '- Synchronous operations and asynchronously settled operations are '
      'reported in separate tables and are never ranked against each other.',
    )
    ..writeln(
      '- Every score is normalized to one logical operation within its timing '
      'domain.',
    )
    ..writeln('- Each library runs in a fresh AOT process for every trial.')
    ..writeln(
      '- Library order is shuffled independently per trial with seed '
      '`${provenance.seed}`.',
    )
    ..writeln(
      '- Executable benchmark inputs are fingerprinted before compilation and '
      'verified unchanged after all trials.',
    )
    ..writeln(
      '- `benchmark_harness` warms each benchmark for at least 100 ms and '
      'measures it for at least 2 seconds.',
    )
    ..writeln(
      '- Setup and teardown run again after warmup so measured state starts '
      'clean.',
    )
    ..writeln(
      '- Lifecycle rows create and use a native object or graph, perform native '
      'cleanup where available, and otherwise release local ownership.',
    )
    ..writeln(
      '- Notify rows complete only after the native listener workload consumed '
      'the delivered value.',
    )
    ..writeln(
      '- Sequential rows enqueue two operations concurrently, verify their '
      'order, and divide elapsed time by two.',
    )
    ..writeln(
      '- Native architectural costs are retained. No compatibility layers or '
      'emulated package capabilities are used.',
    )
    ..writeln()
    ..writeln('## Provenance')
    ..writeln()
    ..writeln('| Property | Value |')
    ..writeln('|---|---|')
    ..writeln('| Generated | `${provenance.generatedAt}` |')
    ..writeln(
      '| Benchmark source snapshot | `${provenance.sourceFingerprint}` |',
    )
    ..writeln('| Runtime | AOT executable |')
    ..writeln('| Dart | `${_escapeCell(provenance.dartVersion)}` |')
    ..writeln('| OS | `${_escapeCell(provenance.operatingSystem)}` |')
    ..writeln('| CPU | `${_escapeCell(provenance.cpu)}` |')
    ..writeln('| Logical processors | ${provenance.logicalProcessors} |')
    ..writeln('| Trials | ${provenance.trials} |')
    ..writeln('| Random seed | ${provenance.seed} |')
    ..writeln()
    ..writeln('### Package versions')
    ..writeln()
    ..writeln('| Package | Version |')
    ..writeln('|---|---|');
  for (final entry in provenance.packageVersions.entries) {
    buffer.writeln('| `${entry.key}` | `${entry.value}` |');
  }

  _writeDomainSummary(
    buffer: buffer,
    timing: BenchmarkTiming.synchronous,
    title: 'Synchronous',
    features: orderedFeatures(BenchmarkTiming.synchronous),
    byFeature: byTimingAndFeature[BenchmarkTiming.synchronous] ?? const {},
    libraries: libraries,
  );
  _writeDomainSummary(
    buffer: buffer,
    timing: BenchmarkTiming.asyncSettled,
    title: 'Asynchronously Settled',
    features: orderedFeatures(BenchmarkTiming.asyncSettled),
    byFeature: byTimingAndFeature[BenchmarkTiming.asyncSettled] ?? const {},
    libraries: libraries,
  );

  buffer
    ..writeln()
    ..writeln('## Detailed Results')
    ..writeln();
  for (final library in libraries) {
    final results = byLibrary[library.displayName] ?? <BenchmarkStatistics>[];
    if (results.isEmpty) continue;
    results.sort((a, b) {
      final timingComparison = a.timing.index.compareTo(b.timing.index);
      return timingComparison != 0
          ? timingComparison
          : a.name.compareTo(b.name);
    });
    buffer
      ..writeln('### ${library.displayName}')
      ..writeln()
      ..writeln(
        '| Benchmark | Timing | Median (μs/op) | MAD | Min | Max | Samples |',
      )
      ..writeln('|---|---|---:|---:|---:|---:|---|');
    for (final result in results) {
      buffer.writeln(
        '| ${result.name} | ${result.timing.label} | '
        '${_formatMicros(result.median)} | '
        '${_formatMicros(result.medianAbsoluteDeviation)} | '
        '${_formatMicros(result.minimum)} | '
        '${_formatMicros(result.maximum)} | '
        '${result.samples.map(_formatMicros).join(', ')} |',
      );
    }
    buffer.writeln();
  }

  buffer
    ..writeln('---')
    ..writeln()
    ..writeln(
      '*Generated automatically by `benchmark/bin/run_benchmarks.dart`.*',
    );
  return buffer.toString();
}

void _writeDomainSummary({
  required StringBuffer buffer,
  required BenchmarkTiming timing,
  required String title,
  required List<String> features,
  required Map<String, Map<String, BenchmarkStatistics>> byFeature,
  required List<BenchmarkLibrarySpec> libraries,
}) {
  buffer
    ..writeln()
    ..writeln('## $title Results Summary')
    ..writeln()
    ..writeln(
      '| Feature | ${libraries.map((library) => library.header).join(' | ')} |',
    )
    ..writeln('|---|${List.filled(libraries.length, '---').join('|')}|');
  for (final feature in features) {
    final cells = libraries.map((library) {
      final result = byFeature[feature]?[library.displayName];
      return result == null
          ? '—'
          : '${_formatMicros(result.median)} ± '
              '${_formatMicros(result.medianAbsoluteDeviation)} μs';
    });
    buffer.writeln('| $feature | ${cells.join(' | ')} |');
  }

  final comparableFeatures = features
      .where((feature) => byFeature[feature]?['Pureflow'] != null)
      .toList();
  buffer
    ..writeln()
    ..writeln('## $title Performance Comparison (vs Pureflow median)')
    ..writeln()
    ..writeln(
      'Percentages compare medians only within the ${timing.label.toLowerCase()} '
      'timing domain. Positive values are slower than Pureflow and negative '
      'values are faster.',
    )
    ..writeln();
  if (comparableFeatures.isEmpty) {
    buffer.writeln('No same-domain Pureflow baseline is available.');
    return;
  }

  buffer
    ..writeln(
      '| Feature | ${libraries.skip(1).map((library) => library.header).join(' | ')} |',
    )
    ..writeln('|---|${List.filled(libraries.length - 1, '---').join('|')}|');
  for (final feature in comparableFeatures) {
    final baseline = byFeature[feature]!['Pureflow']!;
    final cells = libraries.skip(1).map((library) {
      final result = byFeature[feature]?[library.displayName];
      if (result == null) return '—';
      final difference =
          ((result.median - baseline.median) / baseline.median) * 100;
      return '${difference.toStringAsFixed(1)}%';
    });
    buffer.writeln('| $feature | ${cells.join(' | ')} |');
  }
}

String _escapeCell(String value) =>
    value.replaceAll('|', r'\|').replaceAll('\n', ' ');

String _formatMicros(double value) =>
    value.abs() < 0.1 ? value.toStringAsFixed(4) : value.toStringAsFixed(2);
