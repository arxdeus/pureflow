// ignore_for_file: unused_field, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/fair_benchmark_base.dart';
import 'package:signals_core/signals_core.dart' as sig;

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class SignalsCoreStoreCreateBenchmark extends BenchmarkBase {
  int _result = 0;

  SignalsCoreStoreCreateBenchmark({ScoreEmitter? emitter})
      : super('Signals: Signal.lifecycle',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final s = sig.signal(42);
    _result = s.value;
    s.dispose();
  }
}

class SignalsCoreStoreReadBenchmark extends BenchmarkBase {
  late sig.Signal<int> s;
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
  late sig.Signal<int> s;
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
  late sig.Signal<int> s;
  int _counter = 0;
  int _notifications = 0;
  late sig.EffectCleanup cleanup;

  SignalsCoreStoreNotifyBenchmark({ScoreEmitter? emitter})
      : super('Signals: Signal.notify',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(0);
    cleanup = sig.effect(() {
      _notifications += s.value;
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
  late sig.Signal<int> s;
  final List<sig.EffectCleanup> _cleanups = [];
  int _counter = 0;
  int _checksum = 0;

  SignalsCoreStoreNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Signals: Signal.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(0);
    for (var i = 0; i < 1000; i++) {
      final cleanup = sig.effect(() {
        _checksum += s.value;
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
    _cleanups.clear();
    s.dispose();
  }
}

// ============================================================================
// Recomputable View Benchmarks
// ============================================================================

class SignalsCoreComputedCreateBenchmark extends BenchmarkBase {
  int _result = 0;

  SignalsCoreComputedCreateBenchmark({ScoreEmitter? emitter})
      : super('Signals: Computed.lifecycle',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final s = sig.signal(42);
    final c = sig.computed(() => s.value * 2);
    _result = c.value;
    c.dispose();
    s.dispose();
  }
}

class SignalsCoreComputedReadBenchmark extends BenchmarkBase {
  late sig.Signal<int> s;
  late sig.Computed<int> c;
  int _result = 0;

  SignalsCoreComputedReadBenchmark({ScoreEmitter? emitter})
      : super('Signals: Computed.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(42);
    c = sig.computed(() => s.value * 2);
    _result = c.value;
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
  late sig.Signal<int> s;
  late sig.Computed<int> c;
  int _counter = 0;
  int _result = 0;

  SignalsCoreComputedRecomputeBenchmark({ScoreEmitter? emitter})
      : super('Signals: Computed.recompute',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(0);
    c = sig.computed(() => s.value * 2);
    _result = c.value;
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
  late sig.Signal<int> s;
  late sig.Computed<int> doubled;
  late sig.Computed<int> sum;
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
    _result = sum.value;
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

class SignalsCoreComputedManyDependentsBenchmark extends BenchmarkBase {
  late sig.Signal<int> s;
  final List<sig.Computed<int>> _computeds = [];
  int _counter = 0;
  int _checksum = 0;

  SignalsCoreComputedManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Signals: Computed.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = sig.signal(0);
    for (var i = 0; i < 1000; i++) {
      final computed = sig.computed(() => s.value * 2);
      _computeds.add(computed);
      _checksum += computed.value;
    }
  }

  @override
  void run() {
    s.value = ++_counter;
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
    s.dispose();
  }
}

// ============================================================================
// Main
// ============================================================================

Future<List<BenchmarkResult>> runBenchmark() async {
  // Create custom emitter to collect results
  final emitter = CollectingScoreEmitter(_extractFeature, _extractTiming);

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
  SignalsCoreComputedManyDependentsBenchmark(emitter: emitter).report();

  return emitter.results;
}

String _extractFeature(String benchmarkName) {
  if (benchmarkName.contains('Signal.lifecycle')) {
    return 'State Holder: Lifecycle (Create + Use + Release)';
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
