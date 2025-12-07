// ignore_for_file: unused_field, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:signals_core/signals_core.dart' as sig;

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class SignalsCoreStoreCreateBenchmark extends BenchmarkBase {
  SignalsCoreStoreCreateBenchmark({ScoreEmitter? emitter})
      : super('Signals: Signal.create',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final s = sig.signal(42);
    s.dispose();
  }
}

class SignalsCoreStoreReadBenchmark extends BenchmarkBase {
  late final sig.Signal<int> s;
  int _result = 0;

  SignalsCoreStoreReadBenchmark({ScoreEmitter? emitter})
      : super('Signals: Signal.read', emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(42);
  }

  @override
  void run() {
    _result = s.value;
  }

  @override
  void teardown() {
    s.dispose();
  }
}

class SignalsCoreStoreWriteBenchmark extends BenchmarkBase {
  late final sig.Signal<int> s;
  int _counter = 0;

  SignalsCoreStoreWriteBenchmark({ScoreEmitter? emitter})
      : super('Signals: Signal.write',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(0);
  }

  @override
  void run() {
    s.value = ++_counter;
  }

  @override
  void teardown() {
    s.dispose();
  }
}

class SignalsCoreStoreNotifyBenchmark extends BenchmarkBase {
  late final sig.Signal<int> s;
  int _counter = 0;
  int _notifications = 0;
  late final sig.EffectCleanup cleanup;

  SignalsCoreStoreNotifyBenchmark({ScoreEmitter? emitter})
      : super('Signals: Signal.notify',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(0);
    cleanup = sig.effect(() {
      final _ = s.value;
      _notifications++;
    });
  }

  @override
  void run() {
    s.value = ++_counter;
  }

  @override
  void teardown() {
    cleanup();
    s.dispose();
  }
}

class SignalsCoreStoreNotifyManyDependentsBenchmark extends BenchmarkBase {
  late final sig.Signal<int> s;
  final List<sig.EffectCleanup> _cleanups = [];
  int _counter = 0;

  SignalsCoreStoreNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Signals: Signal.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(0);
    for (var i = 0; i < 1000; i++) {
      final cleanup = sig.effect(() {
        final _ = s.value;
      });
      _cleanups.add(cleanup);
    }
  }

  @override
  void run() {
    s.value = ++_counter;
  }

  @override
  void teardown() {
    for (final cleanup in _cleanups) {
      cleanup();
    }
    s.dispose();
  }
}

// ============================================================================
// Recomputable View Benchmarks
// ============================================================================

class SignalsCoreComputedCreateBenchmark extends BenchmarkBase {
  late final sig.Signal<int> s;

  SignalsCoreComputedCreateBenchmark({ScoreEmitter? emitter})
      : super('Signals: Computed.create',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(42);
  }

  @override
  void run() {
    final c = sig.computed(() => s.value * 2);
    c.dispose();
  }

  @override
  void teardown() {
    s.dispose();
  }
}

class SignalsCoreComputedReadBenchmark extends BenchmarkBase {
  late final sig.Signal<int> s;
  late final sig.Computed<int> c;
  int _result = 0;

  SignalsCoreComputedReadBenchmark({ScoreEmitter? emitter})
      : super('Signals: Computed.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(42);
    c = sig.computed(() => s.value * 2);
  }

  @override
  void run() {
    _result = c.value;
  }

  @override
  void teardown() {
    c.dispose();
    s.dispose();
  }
}

class SignalsCoreComputedRecomputeBenchmark extends BenchmarkBase {
  late final sig.Signal<int> s;
  late final sig.Computed<int> c;
  int _counter = 0;
  int _result = 0;

  SignalsCoreComputedRecomputeBenchmark({ScoreEmitter? emitter})
      : super('Signals: Computed.recompute',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(0);
    c = sig.computed(() => s.value * 2);
  }

  @override
  void run() {
    s.value = ++_counter;
    _result = c.value;
  }

  @override
  void teardown() {
    c.dispose();
    s.dispose();
  }
}

class SignalsCoreComputedChainBenchmark extends BenchmarkBase {
  late final sig.Signal<int> s;
  late final sig.Computed<int> doubled;
  late final sig.Computed<int> sum;
  int _counter = 0;
  int _result = 0;

  SignalsCoreComputedChainBenchmark({ScoreEmitter? emitter})
      : super('Signals: Computed.chain',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(0);
    doubled = sig.computed(() => s.value * 2);
    sum = sig.computed(() => doubled.value + 10);
  }

  @override
  void run() {
    s.value = ++_counter;
    _result = sum.value;
  }

  @override
  void teardown() {
    sum.dispose();
    doubled.dispose();
    s.dispose();
  }
}

class SignalsCoreComputedChainManyDependentsBenchmark extends BenchmarkBase {
  late final sig.Signal<int> s;
  final List<sig.Computed<int>> _computeds = [];
  int _counter = 0;

  SignalsCoreComputedChainManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Signals: Computed.chain.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(0);
    for (var i = 0; i < 1000; i++) {
      final computed = sig.computed(() => s.value * 2);
      _computeds.add(computed);
    }
  }

  @override
  void run() {
    s.value = ++_counter;
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
    s.dispose();
  }
}

// ============================================================================
// Main
// ============================================================================

Future<List<BenchmarkResult>> runBenchmark() async {
  // Create custom emitter to collect results
  final emitter = CollectingScoreEmitter(_extractFeature);

  // State Holder Benchmarks
  SignalsCoreStoreCreateBenchmark(emitter: emitter).report();
  SignalsCoreStoreReadBenchmark(emitter: emitter).report();
  SignalsCoreStoreWriteBenchmark(emitter: emitter).report();
  SignalsCoreStoreNotifyBenchmark(emitter: emitter).report();
  SignalsCoreStoreNotifyManyDependentsBenchmark(emitter: emitter).report();

  // Recomputable View Benchmarks
  SignalsCoreComputedCreateBenchmark(emitter: emitter).report();
  SignalsCoreComputedReadBenchmark(emitter: emitter).report();
  SignalsCoreComputedRecomputeBenchmark(emitter: emitter).report();
  SignalsCoreComputedChainBenchmark(emitter: emitter).report();
  SignalsCoreComputedChainManyDependentsBenchmark(emitter: emitter).report();

  return emitter.results;
}

String _extractFeature(String benchmarkName) {
  if (benchmarkName.contains('Signal.create')) {
    return 'State Holder: Create';
  }
  if (benchmarkName.contains('Signal.read')) {
    return 'State Holder: Read';
  }
  if (benchmarkName.contains('Signal.write')) {
    return 'State Holder: Write';
  }
  if (benchmarkName.contains('Signal.notify.many_dependents')) {
    return 'State Holder: Notify - Many Dependents (1000)';
  }
  if (benchmarkName.contains('Signal.notify')) {
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
