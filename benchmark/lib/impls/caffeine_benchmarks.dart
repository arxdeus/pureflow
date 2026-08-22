// ignore_for_file: unused_field, unused_local_variable

import 'dart:async';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/fair_benchmark_base.dart';
import 'package:caffeine/caffeine.dart' as cf;

// The same batch size is used by Bloc and Caffeine. Sensitivity checks at
// 16/32/64 operations showed per-operation scores had reached a stable range
// by 32 while keeping each harness exercise bounded.
const _asyncDeliveryBatchSize = 32;

int _expectedBatchSum(int first) =>
    _asyncDeliveryBatchSize * (2 * first + _asyncDeliveryBatchSize - 1) ~/ 2;

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
// 2. Writes are events. There is no synchronous setter, so Caffeine is not
//    included in the synchronous write row. Notify/recompute benchmarks await
//    native stream settlement and batch operations so one harness Completer
//    and await are amortized across [_asyncDeliveryBatchSize] updates.
//
// 3. There is no plain "addListener" API. Subscriptions go through
//    `scope.stream(store)`, which is a broadcast `Stream<T>`. Notify benchmarks
//    attach `StreamSubscription`s instead of raw callbacks.
//
// ============================================================================
// State Holder Benchmarks
// ============================================================================

class CaffeineStoreCreateBenchmark extends BenchmarkBase {
  int _result = 0;

  CaffeineStoreCreateBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Store.lifecycle',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final scope = cf.Scope();
    final s = cf.Store<int>.accum((ctx) => 42);
    _result = scope.read(s);
    scope.dispose();
  }
}

class CaffeineStoreReadBenchmark extends BenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  int _result = 0;

  CaffeineStoreReadBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Store.read', emitter: emitter ?? const PrintEmitter());

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

class CaffeineStoreNotifyBenchmark extends AsyncBenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  late cf.Event<int> setValue;
  late StreamSubscription<int> _sub;
  int _counter = 0;
  int _remaining = 0;
  int _lastValue = 0;
  late Completer<void> _batchDone;
  int _checksum = 0;

  CaffeineStoreNotifyBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Store.notify',
            emitter: emitter ?? const PrintEmitter(),
            operationsPerRun: _asyncDeliveryBatchSize);

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
    _batchDone = Completer<void>();
    _sub = scope.stream(store).listen((v) {
      _checksum += v;
      _lastValue = v;
      if (_remaining == 0) return;
      if (--_remaining == 0) {
        _batchDone.complete();
      } else {
        _fireNext();
      }
    });
  }

  void _fireNext() => scope.fire(setValue, ++_counter);

  @override
  Future<void> run() async {
    final first = _counter + 1;
    final checksumBefore = _checksum;
    _remaining = _asyncDeliveryBatchSize;
    _batchDone = Completer<void>();
    _fireNext();
    await _batchDone.future;

    final expectedLast = first + _asyncDeliveryBatchSize - 1;
    final actualSum = _checksum - checksumBefore;
    if (_lastValue != expectedLast || actualSum != _expectedBatchSum(first)) {
      throw StateError(
        'Wrong caffeine notifications: last=$_lastValue, sum=$actualSum',
      );
    }
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
  int _notified = 0;
  int _remaining = 0;
  int _lastValue = 0;
  late Completer<void> _batchDone;
  int _checksum = 0;

  CaffeineStoreNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Store.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter(),
            operationsPerRun: _asyncDeliveryBatchSize);

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
    _batchDone = Completer<void>();
    final stream = scope.stream(store);
    for (var i = 0; i < 1000; i++) {
      _subs.add(stream.listen((value) {
        _checksum += value;
        _lastValue = value;
        if (_remaining == 0 || ++_notified != 1000) return;
        _notified = 0;
        if (--_remaining == 0) {
          _batchDone.complete();
        } else {
          _fireNext();
        }
      }));
    }
  }

  void _fireNext() => scope.fire(setValue, ++_counter);

  @override
  Future<void> run() async {
    final first = _counter + 1;
    final checksumBefore = _checksum;
    _notified = 0;
    _remaining = _asyncDeliveryBatchSize;
    _batchDone = Completer<void>();
    _fireNext();
    await _batchDone.future;

    final expectedLast = first + _asyncDeliveryBatchSize - 1;
    final actualSum = _checksum - checksumBefore;
    final expectedSum = _expectedBatchSum(first) * 1000;
    if (_lastValue != expectedLast || actualSum != expectedSum) {
      throw StateError(
        'Wrong caffeine fan-out: last=$_lastValue, sum=$actualSum',
      );
    }
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
  int _result = 0;

  CaffeineComputedCreateBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Computed.lifecycle',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final scope = cf.Scope();
    final store = cf.Store<int>.accum((ctx) => 42);
    final derived = cf.Store<int>.derive((s) => store(s) * 2);
    _result = scope.read(derived);
    scope.dispose();
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
  int _remaining = 0;
  late StreamSubscription<int> _subscription;
  late Completer<void> _batchDone;
  int _computedChecksum = 0;

  CaffeineComputedRecomputeBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Computed.recompute',
            emitter: emitter ?? const PrintEmitter(),
            operationsPerRun: _asyncDeliveryBatchSize);

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
    _batchDone = Completer<void>();
    _subscription = scope.stream(computed).listen((value) {
      _result = value;
      _computedChecksum += value;
      if (_remaining == 0) return;
      if (--_remaining == 0) {
        _batchDone.complete();
      } else {
        _fireNext();
      }
    });
  }

  void _fireNext() => scope.fire(setValue, ++_counter);

  @override
  Future<void> run() async {
    final first = _counter + 1;
    final computedBefore = _computedChecksum;
    _remaining = _asyncDeliveryBatchSize;
    _batchDone = Completer<void>();
    _fireNext();
    await _batchDone.future;

    final sourceSum = _expectedBatchSum(first);
    final expectedLast = (first + _asyncDeliveryBatchSize - 1) * 2;
    if (_computedChecksum - computedBefore != sourceSum * 2 ||
        _result != expectedLast) {
      throw StateError('Wrong caffeine recompute batch.');
    }
  }

  @override
  Future<void> teardown() async {
    await _subscription.cancel();
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
  int _remaining = 0;
  late StreamSubscription<int> _subscription;
  late Completer<void> _batchDone;
  int _computedChecksum = 0;

  CaffeineComputedChainBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Computed.chain',
            emitter: emitter ?? const PrintEmitter(),
            operationsPerRun: _asyncDeliveryBatchSize);

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
    _batchDone = Completer<void>();
    _subscription = scope.stream(sum).listen((value) {
      _result = value;
      _computedChecksum += value;
      if (_remaining == 0) return;
      if (--_remaining == 0) {
        _batchDone.complete();
      } else {
        _fireNext();
      }
    });
  }

  void _fireNext() => scope.fire(setValue, ++_counter);

  @override
  Future<void> run() async {
    final first = _counter + 1;
    final computedBefore = _computedChecksum;
    _remaining = _asyncDeliveryBatchSize;
    _batchDone = Completer<void>();
    _fireNext();
    await _batchDone.future;

    final sourceSum = _expectedBatchSum(first);
    final expectedComputedSum = sourceSum * 2 + 10 * _asyncDeliveryBatchSize;
    final expectedLast = (first + _asyncDeliveryBatchSize - 1) * 2 + 10;
    if (_computedChecksum - computedBefore != expectedComputedSum ||
        _result != expectedLast) {
      throw StateError('Wrong caffeine chain batch.');
    }
  }

  @override
  Future<void> teardown() async {
    await _subscription.cancel();
    scope.dispose();
  }
}

class CaffeineComputedManyDependentsBenchmark extends AsyncBenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  late cf.Event<int> setValue;
  final List<cf.Store<int>> _computeds = [];
  int _counter = 0;
  int _remaining = 0;
  late StreamSubscription<int> _subscription;
  late Completer<void> _batchDone;
  int _sourceChecksum = 0;
  int _checksum = 0;

  CaffeineComputedManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Caffeine: Computed.many_dependents',
            emitter: emitter ?? const PrintEmitter(),
            operationsPerRun: _asyncDeliveryBatchSize);

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
    _batchDone = Completer<void>();
    _subscription = scope.stream(store).listen((value) {
      _sourceChecksum += value;
      if (_remaining > 0) scheduleMicrotask(_consumeSettledValues);
    });
  }

  void _fireNext() => scope.fire(setValue, ++_counter);

  void _consumeSettledValues() {
    // Source streams emit before sibling propagation. Waiting one microtask is
    // the stable post-flush barrier: subscribing to one sibling is unstable as
    // Caffeine retracks and reorders dependencies, while an aggregate derived
    // store would add 1000 tracked edges and change the workload substantially.
    for (final computed in _computeds) {
      _checksum += scope.read(computed);
    }
    if (--_remaining == 0) {
      _batchDone.complete();
    } else {
      _fireNext();
    }
  }

  @override
  Future<void> run() async {
    final first = _counter + 1;
    final sourceBefore = _sourceChecksum;
    final computedBefore = _checksum;
    _remaining = _asyncDeliveryBatchSize;
    _batchDone = Completer<void>();
    _fireNext();
    await _batchDone.future;

    final sourceSum = _expectedBatchSum(first);
    if (_sourceChecksum - sourceBefore != sourceSum ||
        _checksum - computedBefore != sourceSum * 2 * 1000) {
      throw StateError('Wrong caffeine computed fan-out batch.');
    }
  }

  @override
  Future<void> teardown() async {
    await _subscription.cancel();
    scope.dispose();
    _computeds.clear();
  }
}

// ============================================================================
// Async Configurable Concurrency Flow Benchmarks
// ============================================================================

/// Caffeine event handlers are `async*` generators. Each fired event runs the
/// handler to completion before the next state is observable. This benchmark
/// fires two events back-to-back per iteration and awaits both states via
/// `scope.stream`, mirroring Bloc's `sequential()` transformer benchmark and
/// Pureflow's `Pipeline.sequential` benchmark.
class CaffeineSequentialBenchmark extends AsyncBenchmarkBase {
  late cf.Scope scope;
  late cf.Store<int> store;
  late cf.Event<int> setValue;
  late StreamSubscription<int> _subscription;
  late Completer<int> _completer;
  int _counter = 0;
  final List<int> _received = [];
  int _checksum = 0;

  CaffeineSequentialBenchmark({ScoreEmitter? emitter})
      : super(
          'Caffeine: Sequential',
          emitter: emitter ?? const PrintEmitter(),
          operationsPerRun: 2,
        );

  @override
  Future<void> setup() async {
    scope = cf.Scope();
    setValue = const cf.Event<int>();
    store = cf.Store<int>.accum((ctx) {
      ctx.on(setValue, (v) async* {
        await Future<void>.delayed(Duration.zero);
        yield v;
      }, concurrency: cf.Concurrency.queue);
      return 0;
    });
    scope.read(store);
    _completer = Completer<int>();
    // Single persistent subscription — same pattern as the Bloc benchmark to
    // avoid racy per-iteration subscribe/cancel on a broadcast stream.
    _subscription = scope.stream(store).listen((state) {
      _received.add(state);
      _checksum += state;
      if (_received.length == 2 && !_completer.isCompleted) {
        _completer.complete(state);
      }
    });
  }

  @override
  Future<void> run() async {
    final first = ++_counter;
    final second = ++_counter;
    _received.clear();
    _completer = Completer<int>();
    scope
      ..fire(setValue, first)
      ..fire(setValue, second);
    await _completer.future;
    if (_received[0] != first || _received[1] != second) {
      throw StateError('Wrong caffeine order: $_received != [$first, $second]');
    }
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
  final emitter = CollectingScoreEmitter(_extractFeature, _extractTiming);

  // State Holder Benchmarks
  CaffeineStoreCreateBenchmark(emitter: emitter).report();
  CaffeineStoreReadBenchmark(emitter: emitter).report();
  await CaffeineStoreNotifyBenchmark(emitter: emitter).report();
  await CaffeineStoreNotifyManyDependentsBenchmark(emitter: emitter).report();

  // Recomputable View Benchmarks
  CaffeineComputedCreateBenchmark(emitter: emitter).report();
  CaffeineComputedReadBenchmark(emitter: emitter).report();
  await CaffeineComputedRecomputeBenchmark(emitter: emitter).report();
  await CaffeineComputedChainBenchmark(emitter: emitter).report();
  await CaffeineComputedManyDependentsBenchmark(emitter: emitter).report();

  // Async Configurable Concurrency Flow Benchmarks
  await CaffeineSequentialBenchmark(emitter: emitter).report();

  return emitter.results;
}

String _extractFeature(String benchmarkName) {
  if (benchmarkName.contains('Store.lifecycle')) {
    return 'State Holder: Lifecycle (Create + Use + Release)';
  }
  if (benchmarkName.contains('Store.read')) {
    return 'State Holder: Read';
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
  if (benchmarkName.contains('Sequential')) {
    return 'Async Concurrency: Sequential';
  }
  return benchmarkName;
}

BenchmarkTiming _extractTiming(String benchmarkName) {
  if (benchmarkName.contains('Store.notify') ||
      benchmarkName.contains('Computed.recompute') ||
      benchmarkName.contains('Computed.chain') ||
      benchmarkName.contains('Computed.many_dependents') ||
      benchmarkName.contains('Sequential')) {
    return BenchmarkTiming.asyncSettled;
  }
  return BenchmarkTiming.synchronous;
}

Future<void> main() async {
  await runBenchmark();
}
