// ignore_for_file: unused_field, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';
import 'dart:math';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:pureflow/pureflow.dart' as pf;

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class PureflowStoreCreateBenchmark extends BenchmarkBase {
  PureflowStoreCreateBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Store.create',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final store = pf.Store<int>(42);
    store.dispose();
  }
}

class PureflowStoreReadBenchmark extends BenchmarkBase {
  late final pf.Store<int> store;
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
  late final pf.Store<int> store;
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
  late final pf.Store<int> store;
  int _counter = 0;
  int _notifications = 0;

  PureflowStoreNotifyBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Store.notify',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(0);
    store.addListener(() {
      _notifications++;
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
  late final pf.Store<int> store;
  final List<void Function()> _listeners = [];
  int _counter = 0;

  PureflowStoreNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Store.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(0);
    for (var i = 0; i < 1000; i++) {
      void listener() {
        // Just track that notification happened
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
    store.dispose();
  }
}

// ============================================================================
// Recomputable View Benchmarks
// ============================================================================

class PureflowComputedCreateBenchmark extends BenchmarkBase {
  late final pf.Store<int> store;

  PureflowComputedCreateBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Computed.create',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(42);
  }

  @override
  void run() {
    final computed = pf.Computed(() => store.value * 2);
    computed.dispose();
  }

  @override
  void teardown() {
    store.dispose();
  }
}

class PureflowComputedReadBenchmark extends BenchmarkBase {
  late final pf.Store<int> store;
  late final pf.Computed<int> computed;
  int _result = 0;

  PureflowComputedReadBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Computed.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(42);
    computed = pf.Computed(() => store.value * 2);
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
  late final pf.Store<int> store;
  late final pf.Computed<int> computed;
  int _counter = 0;
  int _result = 0;

  PureflowComputedRecomputeBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Computed.recompute',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(0);
    computed = pf.Computed(() => store.value * 2);
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
  late final pf.Store<int> store;
  late final pf.Computed<int> doubled;
  late final pf.Computed<int> sum;
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

class PureflowComputedChainManyDependentsBenchmark extends BenchmarkBase {
  late final pf.Store<int> store;
  final List<pf.Computed<int>> _computeds = [];
  int _counter = 0;

  PureflowComputedChainManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Computed.chain.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    store = pf.Store<int>(0);
    for (var i = 0; i < 1000; i++) {
      final computed = pf.Computed(() => store.value * 2);
      _computeds.add(computed);
    }
  }

  @override
  void run() {
    store.value = ++_counter;
    // Access all computeds to trigger recomputation
    for (final computed in _computeds) {
      final _ = computed.value;
    }
  }

  @override
  void teardown() {
    for (final computed in _computeds) {
      computed.dispose();
    }
    store.dispose();
  }
}

// ============================================================================
// Async Configurable Concurrency Flow Benchmarks
// ============================================================================

class PureflowPipelineSequentialBenchmark extends AsyncBenchmarkBase {
  late final pf.Pipeline pipeline;

  PureflowPipelineSequentialBenchmark({ScoreEmitter? emitter})
      : super('Pureflow: Pipeline.sequential',
            emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    pipeline = pf.Pipeline(transformer: concurrent());
  }

  @override
  Future<void> run() async {
    final value = Random().nextInt(100);

    final result = await pipeline.run((context) async {
      await Future<void>.delayed(Duration.zero);
      return value;
    });
    assert(value == result, 'Wrong pipeline value: $value');
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
  final emitter = CollectingScoreEmitter(_extractFeature);

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
  PureflowComputedChainManyDependentsBenchmark(emitter: emitter).report();

  // Async Configurable Concurrency Flow Benchmarks
  await PureflowPipelineSequentialBenchmark(emitter: emitter).report();

  return emitter.results;
}

String _extractFeature(String benchmarkName) {
  if (benchmarkName.contains('Store.create')) {
    return 'State Holder: Create';
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
  if (benchmarkName.contains('Computed.create')) {
    return 'Recomputable View: Create';
  }
  if (benchmarkName.contains('Computed.read')) {
    return 'Recomputable View: Read';
  }
  if (benchmarkName.contains('Computed.recompute')) {
    return 'Recomputable View: Recompute';
  }
  if (benchmarkName.contains('Computed.chain.many_dependents')) {
    return 'Recomputable View: Chain - Many Dependents (1000)';
  }
  if (benchmarkName.contains('Computed.chain')) {
    return 'Recomputable View: Chain';
  }
  if (benchmarkName.contains('Pipeline.sequential')) {
    return 'Async Concurrency: Sequential';
  }
  return benchmarkName;
}

Future<void> main() async {
  await runBenchmark();
}
