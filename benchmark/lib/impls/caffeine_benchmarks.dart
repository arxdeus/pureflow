// ignore_for_file: unused_field, unused_local_variable

import 'dart:async';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:caffeine/caffeine.dart' as cf;

// ============================================================================
// Notes on Caffeine's model
// ============================================================================
//
// Caffeine has structural differences from synchronous state-management libs:
//
// 1. Stores are lazy. `Store.accum`/`Store.derive` are descriptors — actual
//    instances are created on first `scope.read`. We force instantiation in
//    `setup`/`run` via `scope.read` to make timings comparable.
//
// 2. Writes are events. There is no synchronous setter — state changes are
//    driven by `scope.fire(event, value)` and handlers are `async*` generators.
//    State settles after a microtask. The write/notify/recompute benchmarks
//    therefore use `AsyncBenchmarkBase` and await one microtask per `run()`,
//    which is inherent to caffeine's design (not extra harness overhead).
//
// 3. There is no plain "addListener" API. Subscriptions go through
//    `scope.stream(store)`, which is a broadcast `Stream<T>`. Notify benchmarks
//    attach `StreamSubscription`s instead of raw callbacks.
//
// ============================================================================
// State Holder Benchmarks
// ============================================================================

class CaffeineStoreCreateBenchmark extends BenchmarkBase {
  late cf.Scope scope;
  int _i = 0;
  final List<cf.Store<int>> _stores = [];

  CaffeineStoreCreateBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Store.create',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    scope = cf.Scope();
  }

  @override
  void run() {
    // Construct a fresh store descriptor and force instantiation by reading
    // it through a freshly-forked scope so the cost includes both the
    // descriptor allocation and runtime materialization.
    final s = cf.Store<int>.accum((ctx) => 42 + (_i++));
    final fork = scope.fork(overrides: {s});
    fork.read(s);
    _stores.add(s);
  }

  @override
  void teardown() {
    scope.dispose();
    _stores.clear();
  }
}

class CaffeineStoreReadBenchmark extends BenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  int _result = 0;

  CaffeineStoreReadBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Store.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    scope = cf.Scope();
    store = cf.Store<int>.accum((ctx) => 42);
    // Force instantiation so we measure the steady-state read path.
    scope.read(store);
  }

  @override
  void run() {
    _result = scope.read(store);
  }

  @override
  void teardown() {
    scope.dispose();
  }
}

class CaffeineStoreWriteBenchmark extends AsyncBenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  late cf.Event<int> setValue;
  int _counter = 0;

  CaffeineStoreWriteBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Store.write',
            emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    scope = cf.Scope();
    setValue = const cf.Event<int>();
    store = cf.Store<int>.accum((ctx) {
      ctx.on(setValue, (v) async* {
        yield v;
      });
      return 0;
    });
    scope.read(store);
  }

  @override
  Future<void> run() async {
    scope.fire(setValue, ++_counter);
    // Drain the microtask queue so the async* handler completes and
    // the new state is committed before the next iteration.
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> teardown() async {
    scope.dispose();
  }
}

class CaffeineStoreNotifyBenchmark extends AsyncBenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  late cf.Event<int> setValue;
  late StreamSubscription<int> _sub;
  int _counter = 0;
  int _lastValue = 0;

  CaffeineStoreNotifyBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Store.notify',
            emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    scope = cf.Scope();
    setValue = const cf.Event<int>();
    store = cf.Store<int>.accum((ctx) {
      ctx.on(setValue, (v) async* {
        yield v;
      });
      return 0;
    });
    scope.read(store);
    _sub = scope.stream(store).listen((v) => _lastValue = v);
  }

  @override
  Future<void> run() async {
    scope.fire(setValue, ++_counter);
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> teardown() async {
    await _sub.cancel();
    scope.dispose();
  }
}

class CaffeineStoreNotifyManyDependentsBenchmark extends AsyncBenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  late cf.Event<int> setValue;
  final List<StreamSubscription<int>> _subs = [];
  int _counter = 0;

  CaffeineStoreNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Store.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    scope = cf.Scope();
    setValue = const cf.Event<int>();
    store = cf.Store<int>.accum((ctx) {
      ctx.on(setValue, (v) async* {
        yield v;
      });
      return 0;
    });
    scope.read(store);
    final stream = scope.stream(store);
    for (var i = 0; i < 1000; i++) {
      _subs.add(stream.listen((_) {}));
    }
  }

  @override
  Future<void> run() async {
    scope.fire(setValue, ++_counter);
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> teardown() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    scope.dispose();
  }
}

// ============================================================================
// Recomputable View Benchmarks
// ============================================================================

class CaffeineComputedCreateBenchmark extends BenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  final List<cf.Store<int>> _computeds = [];

  CaffeineComputedCreateBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Computed.create',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    scope = cf.Scope();
    store = cf.Store<int>.accum((ctx) => 42);
    scope.read(store);
  }

  @override
  void run() {
    final derived = cf.Store<int>.derive((s) => store(s) * 2);
    // Force instantiation so the cost includes registering dependencies.
    scope.read(derived);
    _computeds.add(derived);
  }

  @override
  void teardown() {
    scope.dispose();
    _computeds.clear();
  }
}

class CaffeineComputedReadBenchmark extends BenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  late cf.Store<int> computed;
  int _result = 0;

  CaffeineComputedReadBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Computed.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    scope = cf.Scope();
    store = cf.Store<int>.accum((ctx) => 42);
    computed = cf.Store<int>.derive((s) => store(s) * 2);
    scope.read(store);
    scope.read(computed);
  }

  @override
  void run() {
    _result = scope.read(computed);
  }

  @override
  void teardown() {
    scope.dispose();
  }
}

class CaffeineComputedRecomputeBenchmark extends AsyncBenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  late cf.Store<int> computed;
  late cf.Event<int> setValue;
  int _counter = 0;
  int _result = 0;

  CaffeineComputedRecomputeBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Computed.recompute',
            emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    scope = cf.Scope();
    setValue = const cf.Event<int>();
    store = cf.Store<int>.accum((ctx) {
      ctx.on(setValue, (v) async* {
        yield v;
      });
      return 0;
    });
    computed = cf.Store<int>.derive((s) => store(s) * 2);
    scope.read(store);
    scope.read(computed);
  }

  @override
  Future<void> run() async {
    scope.fire(setValue, ++_counter);
    await Future<void>.delayed(Duration.zero);
    _result = scope.read(computed);
  }

  @override
  Future<void> teardown() async {
    scope.dispose();
  }
}

class CaffeineComputedChainBenchmark extends AsyncBenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  late cf.Store<int> doubled;
  late cf.Store<int> sum;
  late cf.Event<int> setValue;
  int _counter = 0;
  int _result = 0;

  CaffeineComputedChainBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Computed.chain',
            emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    scope = cf.Scope();
    setValue = const cf.Event<int>();
    store = cf.Store<int>.accum((ctx) {
      ctx.on(setValue, (v) async* {
        yield v;
      });
      return 0;
    });
    doubled = cf.Store<int>.derive((s) => store(s) * 2);
    sum = cf.Store<int>.derive((s) => doubled(s) + 10);
    scope.read(store);
    scope.read(doubled);
    scope.read(sum);
  }

  @override
  Future<void> run() async {
    scope.fire(setValue, ++_counter);
    await Future<void>.delayed(Duration.zero);
    _result = scope.read(sum);
  }

  @override
  Future<void> teardown() async {
    scope.dispose();
  }
}

class CaffeineComputedChainManyDependentsBenchmark extends AsyncBenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  late cf.Event<int> setValue;
  final List<cf.Store<int>> _computeds = [];
  int _counter = 0;

  CaffeineComputedChainManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Computed.chain.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    scope = cf.Scope();
    setValue = const cf.Event<int>();
    store = cf.Store<int>.accum((ctx) {
      ctx.on(setValue, (v) async* {
        yield v;
      });
      return 0;
    });
    scope.read(store);
    for (var i = 0; i < 1000; i++) {
      final derived = cf.Store<int>.derive((s) => store(s) * 2);
      scope.read(derived);
      _computeds.add(derived);
    }
  }

  @override
  Future<void> run() async {
    scope.fire(setValue, ++_counter);
    await Future<void>.delayed(Duration.zero);
    for (final c in _computeds) {
      final _ = scope.read(c);
    }
  }

  @override
  Future<void> teardown() async {
    scope.dispose();
    _computeds.clear();
  }
}

// ============================================================================
// Async Configurable Concurrency Flow Benchmarks
// ============================================================================

/// Caffeine event handlers are `async*` generators. Each fired event runs the
/// handler to completion before the next state is observable. This benchmark
/// fires one event per iteration and awaits the resulting state via
/// `scope.stream`, mirroring Bloc's `sequential()` transformer benchmark and
/// Pureflow's `Pipeline.sequential` benchmark.
class CaffeineSequentialBenchmark extends AsyncBenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  late cf.Event<int> setValue;
  late StreamSubscription<int> _subscription;
  late Completer<int> _completer;
  int _counter = 0;

  CaffeineSequentialBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Sequential',
            emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    scope = cf.Scope();
    setValue = const cf.Event<int>();
    store = cf.Store<int>.accum((ctx) {
      ctx.on(setValue, (v) async* {
        await Future<void>.delayed(Duration.zero);
        yield v;
      });
      return 0;
    });
    scope.read(store);
    _completer = Completer<int>();
    // Single persistent subscription — same pattern as the Bloc benchmark to
    // avoid racy per-iteration subscribe/cancel on a broadcast stream.
    _subscription = scope.stream(store).listen((state) {
      if (!_completer.isCompleted) {
        _completer.complete(state);
      }
    });
  }

  @override
  Future<void> run() async {
    final value = ++_counter;
    _completer = Completer<int>();
    scope.fire(setValue, value);
    final newValue = await _completer.future;
    assert(value == newValue, 'Wrong caffeine value: $value != $newValue');
  }

  @override
  Future<void> teardown() async {
    await _subscription.cancel();
    scope.dispose();
  }
}

// ============================================================================
// Main
// ============================================================================

Future<List<BenchmarkResult>> runBenchmark() async {
  final emitter = CollectingScoreEmitter(_extractFeature);

  // State Holder Benchmarks
  CaffeineStoreCreateBenchmark(emitter: emitter).report();
  CaffeineStoreReadBenchmark(emitter: emitter).report();
  await CaffeineStoreWriteBenchmark(emitter: emitter).report();
  await CaffeineStoreNotifyBenchmark(emitter: emitter).report();
  await CaffeineStoreNotifyManyDependentsBenchmark(emitter: emitter).report();

  // Recomputable View Benchmarks
  CaffeineComputedCreateBenchmark(emitter: emitter).report();
  CaffeineComputedReadBenchmark(emitter: emitter).report();
  await CaffeineComputedRecomputeBenchmark(emitter: emitter).report();
  await CaffeineComputedChainBenchmark(emitter: emitter).report();
  await CaffeineComputedChainManyDependentsBenchmark(emitter: emitter).report();

  // Async Configurable Concurrency Flow Benchmarks
  await CaffeineSequentialBenchmark(emitter: emitter).report();

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
  if (benchmarkName.contains('Sequential')) {
    return 'Async Concurrency: Sequential';
  }
  return benchmarkName;
}

Future<void> main() async {
  await runBenchmark();
}
