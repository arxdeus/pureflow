// ignore_for_file: unused_field, unused_local_variable

import 'dart:async';

import 'package:alien_signals/alien_signals.dart' as alien;
import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark_harness/benchmark_harness.dart';

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class AlienSignalsStoreCreateBenchmark extends BenchmarkBase {
  final List<alien.WritableSignal<int>> _signals = [];

  AlienSignalsStoreCreateBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Signal.create',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    _signals.add(alien.signal(42));
  }

  @override
  void teardown() {
    // No explicit dispose in alien_signals; signals are GC'd.
    _signals.clear();
  }
}

class AlienSignalsStoreReadBenchmark extends BenchmarkBase {
  late final alien.WritableSignal<int> s;
  int _result = 0;

  AlienSignalsStoreReadBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Signal.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(42);
  }

  @override
  void run() {
    _result = s();
  }
}

class AlienSignalsStoreWriteBenchmark extends BenchmarkBase {
  late final alien.WritableSignal<int> s;
  int _counter = 0;

  AlienSignalsStoreWriteBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Signal.write',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(0);
  }

  @override
  void run() {
    s.set(++_counter);
  }
}

/// Note: alien_signals has no plain listener API — `effect()` is the only
/// subscription primitive. Each notification re-runs the effect closure with
/// full dependency re-tracking (unlink + relink), and writes go through the
/// propagate → queue → flush machinery. This overhead is inherent to
/// alien_signals' design, unlike plain `addListener` callbacks
/// (Pureflow, ValueNotifier).
class AlienSignalsStoreNotifyBenchmark extends BenchmarkBase {
  late final alien.WritableSignal<int> s;
  int _counter = 0;
  int _notifications = 0;
  late final alien.Effect _stop;

  AlienSignalsStoreNotifyBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Signal.notify',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(0);
    _stop = alien.effect(() {
      final _ = s();
      _notifications++;
    });
  }

  @override
  void run() {
    s.set(++_counter);
  }

  @override
  void teardown() {
    _stop();
  }
}

/// Note: Same `effect()` re-tracking overhead as Notify, multiplied by
/// 1000 dependents.
class AlienSignalsStoreNotifyManyDependentsBenchmark extends BenchmarkBase {
  late final alien.WritableSignal<int> s;
  final List<alien.Effect> _stops = [];
  int _counter = 0;

  AlienSignalsStoreNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Signal.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(0);
    for (var i = 0; i < 1000; i++) {
      final stop = alien.effect(() {
        final _ = s();
      });
      _stops.add(stop);
    }
  }

  @override
  void run() {
    s.set(++_counter);
  }

  @override
  void teardown() {
    for (final stop in _stops) {
      stop();
    }
    _stops.clear();
  }
}

// ============================================================================
// Recomputable View Benchmarks
// ============================================================================

class AlienSignalsComputedCreateBenchmark extends BenchmarkBase {
  late final alien.WritableSignal<int> s;
  final List<alien.Computed<int>> _computeds = [];

  AlienSignalsComputedCreateBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Computed.create',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(42);
  }

  @override
  void run() {
    _computeds.add(alien.computed((_) => s() * 2));
  }

  @override
  void teardown() {
    _computeds.clear();
  }
}

class AlienSignalsComputedReadBenchmark extends BenchmarkBase {
  late final alien.WritableSignal<int> s;
  late final alien.Computed<int> c;
  int _result = 0;

  AlienSignalsComputedReadBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Computed.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(42);
    c = alien.computed((_) => s() * 2);
  }

  @override
  void run() {
    _result = c();
  }
}

class AlienSignalsComputedRecomputeBenchmark extends BenchmarkBase {
  late final alien.WritableSignal<int> s;
  late final alien.Computed<int> c;
  int _counter = 0;
  int _result = 0;

  AlienSignalsComputedRecomputeBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Computed.recompute',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(0);
    c = alien.computed((_) => s() * 2);
  }

  @override
  void run() {
    s.set(++_counter);
    _result = c();
  }
}

class AlienSignalsComputedChainBenchmark extends BenchmarkBase {
  late final alien.WritableSignal<int> s;
  late final alien.Computed<int> doubled;
  late final alien.Computed<int> sum;
  int _counter = 0;
  int _result = 0;

  AlienSignalsComputedChainBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Computed.chain',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(0);
    doubled = alien.computed((_) => s() * 2);
    sum = alien.computed((_) => doubled() + 10);
  }

  @override
  void run() {
    s.set(++_counter);
    _result = sum();
  }
}

class AlienSignalsComputedChainManyDependentsBenchmark extends BenchmarkBase {
  late final alien.WritableSignal<int> s;
  final List<alien.Computed<int>> _computeds = [];
  int _counter = 0;

  AlienSignalsComputedChainManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Computed.chain.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(0);
    for (var i = 0; i < 1000; i++) {
      final computed = alien.computed((_) => s() * 2);
      _computeds.add(computed);
    }
  }

  @override
  void run() {
    s.set(++_counter);
    // Access all computeds to trigger recomputation
    for (final computed in _computeds) {
      final _ = computed();
    }
  }

  @override
  void teardown() {
    _computeds.clear();
  }
}

// ============================================================================
// Main
// ============================================================================

Future<List<BenchmarkResult>> runBenchmark() async {
  // Create custom emitter to collect results
  final emitter = CollectingScoreEmitter(_extractFeature);

  // State Holder Benchmarks
  AlienSignalsStoreCreateBenchmark(emitter: emitter).report();
  AlienSignalsStoreReadBenchmark(emitter: emitter).report();
  AlienSignalsStoreWriteBenchmark(emitter: emitter).report();
  AlienSignalsStoreNotifyBenchmark(emitter: emitter).report();
  AlienSignalsStoreNotifyManyDependentsBenchmark(emitter: emitter).report();

  // Recomputable View Benchmarks
  AlienSignalsComputedCreateBenchmark(emitter: emitter).report();
  AlienSignalsComputedReadBenchmark(emitter: emitter).report();
  AlienSignalsComputedRecomputeBenchmark(emitter: emitter).report();
  AlienSignalsComputedChainBenchmark(emitter: emitter).report();
  AlienSignalsComputedChainManyDependentsBenchmark(emitter: emitter).report();

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
