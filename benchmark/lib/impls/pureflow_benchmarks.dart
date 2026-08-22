// ignore_for_file: unused_field, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/fair_benchmark_base.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:pureflow/pureflow.dart' as pf;

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class PureflowStoreCreateBenchmark extends BenchmarkBase {
  int _result = 0;

  PureflowStoreCreateBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Store.lifecycle',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final store = pf.Store<int>(42);
    _result = store.value;
    store.dispose();
  }
}

class PureflowStoreReadBenchmark extends BenchmarkBase {
  late pf.Store<int> store;
  int _result = 0;

  PureflowStoreReadBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Store.read', emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(42);
  }

  @override
  void run() {
    _result = store.value;
  }

  @override
  void teardown() {
    store.dispose();
  }
}

class PureflowStoreWriteBenchmark extends BenchmarkBase {
  late pf.Store<int> store;
  int _counter = 0;

  PureflowStoreWriteBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Store.write',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(0);
  }

  @override
  void run() {
    store.value = ++_counter;
  }

  @override
  void teardown() {
    store.dispose();
  }
}

class PureflowStoreNotifyBenchmark extends BenchmarkBase {
  late pf.Store<int> store;
  int _counter = 0;
  int _checksum = 0;

  PureflowStoreNotifyBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Store.notify',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(0);
    store.addListener(() {
      _checksum += store.value;
    });
  }

  @override
  void run() {
    store.value = ++_counter;
  }

  @override
  void teardown() {
    store.dispose();
  }
}

class PureflowStoreNotifyManyDependentsBenchmark extends BenchmarkBase {
  late pf.Store<int> store;
  final List<void Function()> _listeners = [];
  int _counter = 0;
  int _checksum = 0;

  PureflowStoreNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Store.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(0);
    for (var i = 0; i < 1000; i++) {
      void listener() {
        _checksum += store.value;
      }

      store.addListener(listener);
      _listeners.add(listener);
    }
  }

  @override
  void run() {
    store.value = ++_counter;
  }

  @override
  void teardown() {
    for (final listener in _listeners) {
      store.removeListener(listener);
    }
    _listeners.clear();
    store.dispose();
  }
}

// ============================================================================
// Recomputable View Benchmarks
// ============================================================================

class PureflowComputedCreateBenchmark extends BenchmarkBase {
  int _result = 0;

  PureflowComputedCreateBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Computed.lifecycle',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final store = pf.Store<int>(42);
    final computed = pf.Computed(() => store.value * 2);
    _result = computed.value;
    computed.dispose();
    store.dispose();
  }
}

class PureflowComputedReadBenchmark extends BenchmarkBase {
  late pf.Store<int> store;
  late pf.Computed<int> computed;
  int _result = 0;

  PureflowComputedReadBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Computed.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(42);
    computed = pf.Computed(() => store.value * 2);
    _result = computed.value;
  }

  @override
  void run() {
    _result = computed.value;
  }

  @override
  void teardown() {
    computed.dispose();
    store.dispose();
  }
}

class PureflowComputedRecomputeBenchmark extends BenchmarkBase {
  late pf.Store<int> store;
  late pf.Computed<int> computed;
  int _counter = 0;
  int _result = 0;

  PureflowComputedRecomputeBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Computed.recompute',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(0);
    computed = pf.Computed(() => store.value * 2);
    _result = computed.value;
  }

  @override
  void run() {
    store.value = ++_counter;
    _result = computed.value;
  }

  @override
  void teardown() {
    computed.dispose();
    store.dispose();
  }
}

class PureflowComputedChainBenchmark extends BenchmarkBase {
  late pf.Store<int> store;
  late pf.Computed<int> doubled;
  late pf.Computed<int> sum;
  int _counter = 0;
  int _result = 0;

  PureflowComputedChainBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Computed.chain',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(0);
    doubled = pf.Computed(() => store.value * 2);
    sum = pf.Computed(() => doubled.value + 10);
    _result = sum.value;
  }

  @override
  void run() {
    store.value = ++_counter;
    _result = sum.value;
  }

  @override
  void teardown() {
    sum.dispose();
    doubled.dispose();
    store.dispose();
  }
}

class PureflowComputedManyDependentsBenchmark extends BenchmarkBase {
  late pf.Store<int> store;
  final List<pf.Computed<int>> _computeds = [];
  int _counter = 0;
  int _checksum = 0;

  PureflowComputedManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Computed.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(0);
    for (var i = 0; i < 1000; i++) {
      final computed = pf.Computed(() => store.value * 2);
      _computeds.add(computed);
      _checksum += computed.value;
    }
  }

  @override
  void run() {
    store.value = ++_counter;
    for (final computed in _computeds) {
      _checksum += computed.value;
    }
  }

  @override
  void teardown() {
    for (final computed in _computeds) {
      computed.dispose();
    }
    _computeds.clear();
    store.dispose();
  }
}

// ============================================================================
// Async Configurable Concurrency Flow Benchmarks
// ============================================================================

class PureflowPipelineSequentialBenchmark extends AsyncBenchmarkBase {
  late pf.Pipeline pipeline;
  int _counter = 0;
  final List<int> _completionOrder = [];

  PureflowPipelineSequentialBenchmark({ScoreEmitter? emitter})
      : super(
          'Pureflow: Pipeline.sequential',
          emitter: emitter ?? const PrintEmitter(),
          operationsPerRun: 2,
        );

  @override
  Future<void> setup() async {
    pipeline = pf.Pipeline(transformer: sequential());
  }

  @override
  Future<void> run() async {
    final first = ++_counter;
    final second = ++_counter;
    _completionOrder.clear();

    final firstFuture = pipeline.run((context) async {
      await Future<void>.delayed(Duration.zero);
      _completionOrder.add(first);
      return first;
    });
    final secondFuture = pipeline.run((context) async {
      await Future<void>.delayed(Duration.zero);
      _completionOrder.add(second);
      return second;
    });
    final results = await Future.wait([firstFuture, secondFuture]);

    if (results[0] != first || results[1] != second) {
      throw StateError('Wrong pipeline values: $results != [$first, $second]');
    }
    if (_completionOrder.length != 2 ||
        _completionOrder[0] != first ||
        _completionOrder[1] != second) {
      throw StateError(
        'Pipeline operations completed out of order: $_completionOrder',
      );
    }
  }

  @override
  Future<void> teardown() async {
    await pipeline.dispose();
  }
}

// ============================================================================
// Main
// ============================================================================

Future<List<BenchmarkResult>> runBenchmark() async {
  // Create custom emitter to collect results
  final emitter = CollectingScoreEmitter(_extractFeature, _extractTiming);

  // State Holder Benchmarks
  PureflowStoreCreateBenchmark(emitter: emitter).report();
  PureflowStoreReadBenchmark(emitter: emitter).report();
  PureflowStoreWriteBenchmark(emitter: emitter).report();
  PureflowStoreNotifyBenchmark(emitter: emitter).report();
  PureflowStoreNotifyManyDependentsBenchmark(emitter: emitter).report();

  // Recomputable View Benchmarks
  PureflowComputedCreateBenchmark(emitter: emitter).report();
  PureflowComputedReadBenchmark(emitter: emitter).report();
  PureflowComputedRecomputeBenchmark(emitter: emitter).report();
  PureflowComputedChainBenchmark(emitter: emitter).report();
  PureflowComputedManyDependentsBenchmark(emitter: emitter).report();

  // Async Configurable Concurrency Flow Benchmarks
  await PureflowPipelineSequentialBenchmark(emitter: emitter).report();

  return emitter.results;
}

String _extractFeature(String benchmarkName) {
  if (benchmarkName.contains('Store.lifecycle')) {
    return 'State Holder: Lifecycle (Create + Use + Release)';
  }
  if (benchmarkName.contains('Store.read')) {
    return 'State Holder: Read';
  }
  if (benchmarkName.contains('Store.write')) {
    return 'State Holder: Write';
  }
  if (benchmarkName.contains('Store.notify.many_dependents')) {
    return 'State Holder: Notify - Many Dependents (1000)';
  }
  if (benchmarkName.contains('Store.notify')) {
    return 'State Holder: Notify';
  }
  if (benchmarkName.contains('Computed.lifecycle')) {
    return 'Recomputable View: Lifecycle (Create + Evaluate + Release)';
  }
  if (benchmarkName.contains('Computed.read')) {
    return 'Recomputable View: Read';
  }
  if (benchmarkName.contains('Computed.recompute')) {
    return 'Recomputable View: Recompute';
  }
  if (benchmarkName.contains('Computed.many_dependents')) {
    return 'Recomputable View: Many Dependents (1000)';
  }
  if (benchmarkName.contains('Computed.chain')) {
    return 'Recomputable View: Chain';
  }
  if (benchmarkName.contains('Pipeline.sequential')) {
    return 'Async Concurrency: Sequential';
  }
  return benchmarkName;
}

BenchmarkTiming _extractTiming(String benchmarkName) {
  if (benchmarkName.contains('Pipeline.sequential')) {
    return BenchmarkTiming.asyncSettled;
  }
  return BenchmarkTiming.synchronous;
}

Future<void> main() async {
  await runBenchmark();
}
