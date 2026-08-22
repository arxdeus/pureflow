import 'dart:convert';
import 'dart:io';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/impls/alien_signals_benchmarks.dart' as alien_signals;
import 'package:benchmark/impls/bloc_benchmarks.dart' as bloc;
import 'package:benchmark/impls/bloc_signals_benchmarks.dart' as bloc_signals;
import 'package:benchmark/impls/caffeine_benchmarks.dart' as caffeine;
import 'package:benchmark/impls/mobx_benchmarks.dart' as mobx;
import 'package:benchmark/impls/pureflow_benchmarks.dart' as pureflow;
import 'package:benchmark/impls/riverpod_benchmarks.dart' as riverpod;
import 'package:benchmark/impls/signals_core_benchmarks.dart' as signals;

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: benchmark_worker <library>');
    exitCode = 64;
    return;
  }

  final results = await _runLibrary(arguments.single);
  stdout.writeln(jsonEncode(results.map((result) => result.toJson()).toList()));
}

Future<List<BenchmarkResult>> _runLibrary(String library) {
  return switch (library) {
    'pureflow' => pureflow.runBenchmark(),
    'bloc' => bloc.runBenchmark(),
    'bloc_signals' => bloc_signals.runBenchmark(),
    'riverpod' => riverpod.runBenchmark(),
    'signals' => signals.runBenchmark(),
    'alien_signals' => alien_signals.runBenchmark(),
    'caffeine' => caffeine.runBenchmark(),
    'mobx' => mobx.runBenchmark(),
    _ => Future.error(ArgumentError.value(library, 'library', 'unknown')),
  };
}
