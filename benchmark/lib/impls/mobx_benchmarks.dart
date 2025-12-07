// ignore_for_file: unused_field, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:mobx/mobx.dart';

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class MobxObservableCreateBenchmark extends BenchmarkBase {
  MobxObservableCreateBenchmark({ScoreEmitter? emitter})
      : super('MobX: Observable.create',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    Observable(42);
    // MobX Observable doesn't have explicit dispose, but we can clear reactions
  }
}

class MobxObservableReadBenchmark extends BenchmarkBase {
  late final Observable<int> observable;
  int _result = 0;

  MobxObservableReadBenchmark({ScoreEmitter? emitter})
      : super('MobX: Observable.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(42);
  }

  @override
  void run() {
    _result = observable.value;
  }

  @override
  void teardown() {
    // MobX Observable doesn't need explicit disposal
  }
}

class MobxObservableWriteBenchmark extends BenchmarkBase {
  late final Observable<int> observable;
  int _counter = 0;

  MobxObservableWriteBenchmark({ScoreEmitter? emitter})
      : super('MobX: Observable.write',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(0);
  }

  @override
  void run() {
    runInAction(() {
      observable.value = ++_counter;
    });
  }

  @override
  void teardown() {
    // MobX Observable doesn't need explicit disposal
  }
}

class MobxObservableNotifyBenchmark extends BenchmarkBase {
  late final Observable<int> observable;
  int _counter = 0;
  int _notifications = 0;
  late final ReactionDisposer disposer;

  MobxObservableNotifyBenchmark({ScoreEmitter? emitter})
      : super('MobX: Observable.notify',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(0);
    disposer = reaction((_) => observable.value, (_) {
      _notifications++;
    });
  }

  @override
  void run() {
    runInAction(() {
      observable.value = ++_counter;
    });
  }

  @override
  void teardown() {
    disposer();
  }
}

class MobxObservableNotifyManyDependentsBenchmark extends BenchmarkBase {
  late final Observable<int> observable;
  final List<ReactionDisposer> _disposers = [];
  int _counter = 0;

  MobxObservableNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('MobX: Observable.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(0);
    for (var i = 0; i < 1000; i++) {
      final disposer = reaction((_) => observable.value, (_) {
        // Just track that notification happened
      });
      _disposers.add(disposer);
    }
  }

  @override
  void run() {
    runInAction(() {
      observable.value = ++_counter;
    });
  }

  @override
  void teardown() {
    for (final disposer in _disposers) {
      disposer();
    }
  }
}

// ============================================================================
// Recomputable View Benchmarks
// ============================================================================

class MobxComputedCreateBenchmark extends BenchmarkBase {
  late final Observable<int> observable;

  MobxComputedCreateBenchmark({ScoreEmitter? emitter})
      : super('MobX: Computed.create',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(42);
  }

  @override
  void run() {
    Computed(() => observable.value * 2);
    // MobX Computed doesn't need explicit disposal
  }

  @override
  void teardown() {
    // MobX Observable doesn't need explicit disposal
  }
}

class MobxComputedReadBenchmark extends BenchmarkBase {
  late final Observable<int> observable;
  late final Computed<int> computed;
  int _result = 0;

  MobxComputedReadBenchmark({ScoreEmitter? emitter})
      : super('MobX: Computed.read', emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(42);
    computed = Computed(() => observable.value * 2);
  }

  @override
  void run() {
    _result = computed.value;
  }

  @override
  void teardown() {
    // MobX doesn't need explicit disposal
  }
}

class MobxComputedRecomputeBenchmark extends BenchmarkBase {
  late final Observable<int> observable;
  late final Computed<int> computed;
  int _counter = 0;
  int _result = 0;

  MobxComputedRecomputeBenchmark({ScoreEmitter? emitter})
      : super('MobX: Computed.recompute',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(0);
    computed = Computed(() => observable.value * 2);
  }

  @override
  void run() {
    runInAction(() {
      observable.value = ++_counter;
    });
    _result = computed.value;
  }

  @override
  void teardown() {
    // MobX doesn't need explicit disposal
  }
}

class MobxComputedChainBenchmark extends BenchmarkBase {
  late final Observable<int> observable;
  late final Computed<int> doubled;
  late final Computed<int> sum;
  int _counter = 0;
  int _result = 0;

  MobxComputedChainBenchmark({ScoreEmitter? emitter})
      : super('MobX: Computed.chain', emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(0);
    doubled = Computed(() => observable.value * 2);
    sum = Computed(() => doubled.value + 10);
  }

  @override
  void run() {
    runInAction(() {
      observable.value = ++_counter;
    });
    _result = sum.value;
  }

  @override
  void teardown() {
    // MobX doesn't need explicit disposal
  }
}

class MobxComputedChainManyDependentsBenchmark extends BenchmarkBase {
  late final Observable<int> observable;
  final List<Computed<int>> _computeds = [];
  int _counter = 0;

  MobxComputedChainManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('MobX: Computed.chain.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(0);
    for (var i = 0; i < 1000; i++) {
      final computed = Computed(() => observable.value * 2);
      _computeds.add(computed);
    }
  }

  @override
  void run() {
    runInAction(() {
      observable.value = ++_counter;
    });
    // Access all computeds to trigger recomputation
    for (final computed in _computeds) {
      final _ = computed.value;
    }
  }

  @override
  void teardown() {
    // MobX Computed doesn't need explicit disposal
  }
}

// ============================================================================
// Main
// ============================================================================

Future<List<BenchmarkResult>> runBenchmark() async {
  // Create custom emitter to collect results
  final emitter = CollectingScoreEmitter(_extractFeature);

  // State Holder Benchmarks
  MobxObservableCreateBenchmark(emitter: emitter).report();
  MobxObservableReadBenchmark(emitter: emitter).report();
  MobxObservableWriteBenchmark(emitter: emitter).report();
  MobxObservableNotifyBenchmark(emitter: emitter).report();
  MobxObservableNotifyManyDependentsBenchmark(emitter: emitter).report();

  // Recomputable View Benchmarks
  MobxComputedCreateBenchmark(emitter: emitter).report();
  MobxComputedReadBenchmark(emitter: emitter).report();
  MobxComputedRecomputeBenchmark(emitter: emitter).report();
  MobxComputedChainBenchmark(emitter: emitter).report();
  MobxComputedChainManyDependentsBenchmark(emitter: emitter).report();

  return emitter.results;
}

String _extractFeature(String benchmarkName) {
  if (benchmarkName.contains('Observable.create')) {
    return 'State Holder: Create';
  }
  if (benchmarkName.contains('Observable.read')) {
    return 'State Holder: Read';
  }
  if (benchmarkName.contains('Observable.write')) {
    return 'State Holder: Write';
  }
  if (benchmarkName.contains('Observable.notify.many_dependents')) {
    return 'State Holder: Notify - Many Dependents (1000)';
  }
  if (benchmarkName.contains('Observable.notify')) {
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
  return benchmarkName;
}

Future<void> main() async {
  await runBenchmark();
}
