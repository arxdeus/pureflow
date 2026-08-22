import 'dart:io';

import 'package:test/test.dart';

void main() {
  final implementationDirectory = Directory('lib/impls');
  final implementationFiles = implementationDirectory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('_benchmarks.dart'))
      .toList();

  test('all implementations use the per-operation fair harness', () {
    expect(implementationFiles, isNotEmpty);
    for (final file in implementationFiles) {
      final source = file.readAsStringSync();
      expect(
        source,
        contains('package:benchmark/common/fair_benchmark_base.dart'),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('package:benchmark_harness/benchmark_harness.dart')),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('late final')),
        reason: '${file.path} must support setup before warmup and measurement',
      );
    }
  });

  test('feature names describe bounded lifecycle and direct fan-out work', () {
    for (final file in implementationFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('Computed.chain.many_dependents')),
          reason: file.path);
      expect(source, isNot(contains('Recomputable View: Chain - Many')),
          reason: file.path);
      expect(source, isNot(contains("return 'State Holder: Create'")),
          reason: file.path);
      expect(source, isNot(contains("return 'Recomputable View: Create'")),
          reason: file.path);
      expect(source, isNot(contains('Native Cleanup')), reason: file.path);
    }
  });

  test('lifecycle rows consume the native initial value', () {
    final pureflow =
        File('lib/impls/pureflow_benchmarks.dart').readAsStringSync();
    expect(pureflow, contains('_result = store.value;'));

    final signals =
        File('lib/impls/signals_core_benchmarks.dart').readAsStringSync();
    expect(signals, contains('_result = s.value;'));
  });

  test('equivalent dependent rows use the same addition sink', () {
    for (final file in implementationFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('0x3fffffff')), reason: file.path);
      expect(source, isNot(contains('_checksum <<')), reason: file.path);
    }
  });

  test('Bloc synchronous operations await native cleanup outside timing', () {
    for (final path in [
      'lib/impls/bloc_benchmarks.dart',
      'lib/impls/bloc_signals_benchmarks.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('SyncRunAsyncLifecycleBenchmarkBase'),
          reason: path);
      expect(source, isNot(contains('unawaited(')), reason: path);
      expect(source, contains('await cubit.close()'), reason: path);
    }
  });

  test('non-native ValueNotifier emulation is not benchmarked', () {
    expect(File('lib/impls/listenable_benchmarks.dart').existsSync(), isFalse);
    expect(File('lib/common/listenable.dart').existsSync(), isFalse);
  });

  test('sequential workloads enqueue and normalize two operations', () {
    for (final path in [
      'lib/impls/pureflow_benchmarks.dart',
      'lib/impls/bloc_benchmarks.dart',
      'lib/impls/bloc_signals_benchmarks.dart',
      'lib/impls/caffeine_benchmarks.dart',
    ]) {
      expect(File(path).readAsStringSync(), contains('operationsPerRun: 2'),
          reason: path);
    }
    expect(
      File('lib/impls/caffeine_benchmarks.dart').readAsStringSync(),
      contains('concurrency: cf.Concurrency.queue'),
    );
  });

  test('Riverpod and MobX labels match their native semantics', () {
    final riverpod =
        File('lib/impls/riverpod_benchmarks.dart').readAsStringSync();
    expect(riverpod, isNot(contains('StateProvider')));
    expect(riverpod, contains('NotifierProvider'));

    final mobx = File('lib/impls/mobx_benchmarks.dart').readAsStringSync();
    expect(mobx, contains('keepAlive: true'));
  });

  test('async delivery amortizes harness synchronization overhead', () {
    final caffeine =
        File('lib/impls/caffeine_benchmarks.dart').readAsStringSync();
    expect(caffeine, contains('const _asyncDeliveryBatchSize = 32;'));
    expect(
      'operationsPerRun: _asyncDeliveryBatchSize'.allMatches(caffeine).length,
      5,
    );
    expect(caffeine, isNot(contains('CaffeineStoreWriteBenchmark')));
    expect(caffeine, isNot(contains("'Caffeine: Store.write'")));
    expect('scheduleMicrotask('.allMatches(caffeine).length, 1);

    final bloc = File('lib/impls/bloc_benchmarks.dart').readAsStringSync();
    expect(bloc, contains('const _asyncDeliveryBatchSize = 32;'));
    expect(
      'operationsPerRun: _asyncDeliveryBatchSize'.allMatches(bloc).length,
      2,
    );
  });

  test('synchronous and async-settled results are never ranked together', () {
    final readme = File('README.md').readAsStringSync();
    expect(readme, contains('never compared or ranked against each other'));

    final reportRenderer =
        File('lib/common/benchmark_report.dart').readAsStringSync();
    expect(reportRenderer, contains(r'## $title Results Summary'));
    expect(reportRenderer, contains('BenchmarkTiming.synchronous'));
    expect(reportRenderer, contains('BenchmarkTiming.asyncSettled'));
  });

  test('runner rejects results if compiled benchmark source changes', () {
    final runner = File('bin/run_benchmarks.dart').readAsStringSync();
    expect(runner, contains('final initialSnapshot'));
    expect(runner, contains('final finalSnapshot'));
    expect(runner, contains('finalSnapshot.fingerprint != '));
    expect(runner, contains('Benchmark source files changed while benchmarks'));
    expect(runner, contains('sourceFingerprint'));
    expect(runner, contains('_normalizePackageConfiguration'));
    expect(runner, contains('jsonDecode(await file.readAsString())'));
    expect(runner, contains("'--cached'"));
    expect(runner, isNot(contains("'rev-parse'")));
    expect(runner, isNot(contains("'diff', '--no-ext-diff'")));
  });
}
