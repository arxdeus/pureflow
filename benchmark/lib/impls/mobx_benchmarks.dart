// ignore_for_file: unused_field, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/fair_benchmark_base.dart';
import 'package:mobx/mobx.dart';

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class MobxObservableCreateBenchmark extends BenchmarkBase {
  int _result = 0;

  MobxObservableCreateBenchmark({ScoreEmitter? emitter})
      : super('MobX: Observable.lifecycle',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    // Observable has no native disposal API. Keeping references local bounds
    // the usable create/evaluate lifecycle to this run.
    final observable = Observable(42);
    _result = observable.value;
  }
}

class MobxObservableReadBenchmark extends BenchmarkBase {
  late Observable<int> observable;
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

/// A plain unobserved Observable supports direct assignment natively.
class MobxObservableWriteBenchmark extends BenchmarkBase {
  late Observable<int> observable;
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
    observable.value = ++_counter;
  }

  @override
  void teardown() {
    // MobX Observable has no explicit disposal API.
  }
}

/// Note: MobX `reaction()` uses a selector function `(_) => observable.value`
/// that runs first to determine if the effect should fire — 2 function calls
/// per notification vs 1 for plain addListener callbacks.
/// Observed writes use MobX's native `runInAction()` transaction boundary.
class MobxObservableNotifyBenchmark extends BenchmarkBase {
  late Observable<int> observable;
  int _counter = 0;
  int _checksum = 0;
  late ReactionDisposer disposer;

  MobxObservableNotifyBenchmark({ScoreEmitter? emitter})
      : super('MobX: Observable.notify',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(0);
    disposer = reaction((_) => observable.value, (int value) {
      _checksum += value;
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

/// Note: Same `reaction()` + `runInAction()` overhead as Notify, multiplied
/// by 1000 dependents.
class MobxObservableNotifyManyDependentsBenchmark extends BenchmarkBase {
  late Observable<int> observable;
  final List<ReactionDisposer> _disposers = [];
  int _counter = 0;
  int _checksum = 0;

  MobxObservableNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('MobX: Observable.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(0);
    for (var i = 0; i < 1000; i++) {
      final disposer = reaction((_) => observable.value, (int value) {
        _checksum += value;
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
    _disposers.clear();
  }
}

// ============================================================================
// Recomputable View Benchmarks
// ============================================================================

class MobxComputedCreateBenchmark extends BenchmarkBase {
  int _result = 0;

  MobxComputedCreateBenchmark({ScoreEmitter? emitter})
      : super('MobX: Computed.lifecycle',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    // Computed has no native disposal API. Local references bound its usable
    // source/create/evaluate lifecycle to this run.
    final observable = Observable(42);
    final computed = Computed(() => observable.value * 2, keepAlive: true);
    _result = computed.value;
  }
}

class MobxComputedReadBenchmark extends BenchmarkBase {
  late Observable<int> observable;
  late Computed<int> computed;
  int _result = 0;

  MobxComputedReadBenchmark({ScoreEmitter? emitter})
      : super('MobX: Computed.read', emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(42);
    computed = Computed(() => observable.value * 2, keepAlive: true);
    _result = computed.value;
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

/// Note: `runInAction()` wraps the write (closure allocation + transaction
/// overhead). The read triggers lazy recomputation with dirty-flag check.
class MobxComputedRecomputeBenchmark extends BenchmarkBase {
  late Observable<int> observable;
  late Computed<int> computed;
  int _counter = 0;
  int _result = 0;

  MobxComputedRecomputeBenchmark({ScoreEmitter? emitter})
      : super('MobX: Computed.recompute',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(0);
    computed = Computed(() => observable.value * 2, keepAlive: true);
    _result = computed.value;
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

/// Note: `runInAction()` wraps the write. Chain propagation is lazy — each
/// Computed checks its dirty flag on read.
class MobxComputedChainBenchmark extends BenchmarkBase {
  late Observable<int> observable;
  late Computed<int> doubled;
  late Computed<int> sum;
  int _counter = 0;
  int _result = 0;

  MobxComputedChainBenchmark({ScoreEmitter? emitter})
      : super('MobX: Computed.chain', emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(0);
    doubled = Computed(() => observable.value * 2, keepAlive: true);
    sum = Computed(() => doubled.value + 10, keepAlive: true);
    _result = sum.value;
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

/// Note: `runInAction()` wraps the write, then 1000 Computed values are
/// read, each checking its dirty flag and lazily recomputing.
class MobxComputedManyDependentsBenchmark extends BenchmarkBase {
  late Observable<int> observable;
  final List<Computed<int>> _computeds = [];
  int _counter = 0;
  int _checksum = 0;

  MobxComputedManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('MobX: Computed.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    observable = Observable(0);
    for (var i = 0; i < 1000; i++) {
      final computed = Computed(() => observable.value * 2, keepAlive: true);
      _computeds.add(computed);
      _checksum += computed.value;
    }
  }

  @override
  void run() {
    runInAction(() {
      observable.value = ++_counter;
    });
    // Access all computeds to trigger recomputation
    for (final computed in _computeds) {
      _checksum += computed.value;
    }
  }

  @override
  void teardown() {
    // MobX Computed doesn't need explicit disposal
    _computeds.clear();
  }
}

// ============================================================================
// Main
// ============================================================================

Future<List<BenchmarkResult>> runBenchmark() async {
  // Create custom emitter to collect results
  final emitter = CollectingScoreEmitter(_extractFeature, _extractTiming);

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
  MobxComputedManyDependentsBenchmark(emitter: emitter).report();

  return emitter.results;
}

String _extractFeature(String benchmarkName) {
  if (benchmarkName.contains('Observable.lifecycle')) {
    return 'State Holder: Lifecycle (Create + Use + Release)';
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
  return benchmarkName;
}

BenchmarkTiming _extractTiming(String benchmarkName) {
  return BenchmarkTiming.synchronous;
}

Future<void> main() async {
  await runBenchmark();
}
