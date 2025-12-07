import 'dart:io';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/impls/bloc_benchmarks.dart' as bloc;
import 'package:benchmark/impls/listenable_benchmarks.dart' as listenable;
import 'package:benchmark/impls/mobx_benchmarks.dart' as mobx;
import 'package:benchmark/impls/pureflow_benchmarks.dart' as pureflow;
import 'package:benchmark/impls/riverpod_benchmarks.dart' as riverpod;
import 'package:benchmark/impls/signals_core_benchmarks.dart' as signals;

void main(List<String> args) async {
  print('Running all benchmarks...\n');

  print('Running bloc_benchmarks.dart...');
  final blocResults = await bloc.runBenchmark();
  print('  ✓ Completed (${blocResults.length} benchmarks)\n');

  // Run Pureflow benchmarks first (baseline)
  print('Running pureflow_benchmarks.dart...');
  final pureflowResults = await pureflow.runBenchmark();
  print('  ✓ Completed (${pureflowResults.length} benchmarks)\n');

  // Run other benchmarks
  print('Running signals_core_benchmarks.dart...');
  final signalsResults = await signals.runBenchmark();
  print('  ✓ Completed (${signalsResults.length} benchmarks)\n');

  print('Running riverpod_benchmarks.dart...');
  final riverpodResults = await riverpod.runBenchmark();
  print('  ✓ Completed (${riverpodResults.length} benchmarks)\n');

  print('Running listenable_benchmarks.dart...');
  final listenableResults = await listenable.runBenchmark();
  print('  ✓ Completed (${listenableResults.length} benchmarks)\n');

  print('Running mobx_benchmarks.dart...');
  final mobxResults = await mobx.runBenchmark();
  print('  ✓ Completed (${mobxResults.length} benchmarks)\n');

  // Combine all results
  final allResults = <BenchmarkResult>[];
  allResults.addAll(pureflowResults);
  allResults.addAll(signalsResults);
  allResults.addAll(riverpodResults);
  allResults.addAll(blocResults);
  allResults.addAll(listenableResults);
  allResults.addAll(mobxResults);

  print('Generating BENCHMARK_README.md...');
  await generateReport(allResults, pureflowResults);
  print('  ✓ Done!\n');
}

Future<void> generateReport(List<BenchmarkResult> results,
    List<BenchmarkResult> pureflowResults) async {
  // Group results by feature
  final featureGroups = <String, Map<String, double>>{};

  for (final result in results) {
    featureGroups.putIfAbsent(result.feature, () => {});
    featureGroups[result.feature]![result.library] = result.value;
  }

  // Create Pureflow baseline map by feature
  final pureflowBaseline = <String, double>{};
  for (final result in pureflowResults) {
    pureflowBaseline[result.feature] = result.value;
  }

  // Define library order
  final libraries = [
    'Pureflow',
    'Bloc',
    'Riverpod',
    'Signals',
    'MobX',
    'ValueNotifier'
  ];

  // Library URLs for hyperlinks
  final libraryUrls = {
    'Pureflow': 'https://pub.dev/packages/pureflow',
    'Bloc': 'https://pub.dev/packages/bloc',
    'Riverpod': 'https://pub.dev/packages/riverpod',
    'Signals': 'https://pub.dev/packages/signals_core',
    'MobX': 'https://pub.dev/packages/mobx',
    'ValueNotifier':
        'https://api.flutter.dev/flutter/foundation/ValueNotifier-class.html',
  };

  // Helper function to create library header with hyperlink
  String libraryHeader(String library) {
    final url = libraryUrls[library];
    if (url != null) {
      return '[$library]($url)';
    }
    return library;
  }

  // Build markdown table
  final buffer = StringBuffer();
  buffer.writeln('# Benchmark Results\n');
  buffer.writeln(
      'This document contains performance comparison results between Pureflow and other state management libraries.\n');
  buffer.writeln('## Results Summary\n');

  // Create table header with hyperlinks
  final headerRow = StringBuffer('| Feature | ');
  final separatorRow = StringBuffer('|---------|');
  for (final library in libraries) {
    headerRow.write('${libraryHeader(library)} | ');
    separatorRow.write('---|');
  }
  buffer.writeln(headerRow.toString());
  buffer.writeln(separatorRow.toString());

  // Sort features by category
  final sortedFeatures = featureGroups.keys.toList()
    ..sort((a, b) {
      final categoryOrder = {
        'State Holder': 1,
        'Recomputable View': 2,
        'Async Concurrency': 3,
      };
      final aCategory = a.split(':')[0];
      final bCategory = b.split(':')[0];
      return (categoryOrder[aCategory] ?? 999)
          .compareTo(categoryOrder[bCategory] ?? 999);
    });

  for (final feature in sortedFeatures) {
    final featureResults = featureGroups[feature]!;
    final row = StringBuffer('| $feature | ');

    // Add results for each library
    for (final libraryName in libraries) {
      final value = featureResults[libraryName];
      if (value != null) {
        // Format value with 2 decimal places
        row.write('${value.toStringAsFixed(2)} us | ');
      } else {
        row.write('— | ');
      }
    }

    buffer.writeln(row.toString());
  }

  buffer.writeln('\n## Performance Comparison (vs Pureflow)\n');
  buffer.writeln(
      'This table shows the percentage difference from Pureflow for each metric.\n');
  // Create comparison table header with hyperlinks (skip Pureflow)
  final comparisonHeaderRow = StringBuffer('| Feature | ');
  final comparisonSeparatorRow = StringBuffer('|---------|');
  for (final library in libraries.skip(1)) {
    comparisonHeaderRow.write('${libraryHeader(library)} | ');
    comparisonSeparatorRow.write('---|');
  }
  buffer.writeln(comparisonHeaderRow.toString());
  buffer.writeln(comparisonSeparatorRow.toString());

  for (final feature in sortedFeatures) {
    final featureResults = featureGroups[feature]!;
    final pureflowValue = pureflowBaseline[feature];
    final row = StringBuffer('| $feature | ');

    // Skip Pureflow in comparison table
    for (final libraryName in libraries.skip(1)) {
      final value = featureResults[libraryName];
      if (value != null && pureflowValue != null) {
        // Calculate percentage difference: ((value - pureflowValue) / pureflowValue) * 100
        final percentDiff = ((value - pureflowValue) / pureflowValue) * 100;
        row.write('${percentDiff.toStringAsFixed(1)}% | ');
      } else {
        row.write('— | ');
      }
    }

    buffer.writeln(row.toString());
  }

  buffer.writeln('\n## Detailed Results\n');

  // Group by library for detailed view
  final libraryGroups = <String, List<BenchmarkResult>>{};
  for (final result in results) {
    libraryGroups.putIfAbsent(result.library, () => []);
    libraryGroups[result.library]!.add(result);
  }

  for (final libraryName in libraries) {
    final libraryResults = libraryGroups[libraryName] ?? [];
    if (libraryResults.isEmpty) continue;

    buffer.writeln('### $libraryName\n');
    buffer.writeln('| Benchmark | Time (μs) |');
    buffer.writeln('|-----------|-----------|');

    libraryResults.sort((a, b) => a.name.compareTo(b.name));
    for (final result in libraryResults) {
      buffer.writeln('| ${result.name} | ${result.value.toStringAsFixed(2)} |');
    }
    buffer.writeln();
  }

  buffer.writeln('---\n');
  buffer.writeln(
      '*Generated automatically by `benchmark/bin/run_benchmarks.dart`*');

  // Write to file
  final file = File('benchmark/BENCHMARK_README.md');
  if (file.existsSync()) {
    await file.delete(recursive: true);
  }
  await file.create(recursive: true);
  await file.writeAsString(buffer.toString());
}
