// ignore_for_file: unused_field, unused_local_variable

import 'dart:async';

import 'package:alien_signals/alien_signals.dart' as alien;
import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/fair_benchmark_base.dart';

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class AlienSignalsStoreLifecycleBenchmark extends BenchmarkBase {
  int _result = 0;

  AlienSignalsStoreLifecycleBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Signal.lifecycle',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final signal = alien.signal(42);
    _result = signal();
  }
}

class AlienSignalsStoreReadBenchmark extends BenchmarkBase {
  late alien.WritableSignal<int> s;
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
  late alien.WritableSignal<int> s;
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
/// alien_signals' design, unlike Pureflow's plain `addListener` callbacks.
class AlienSignalsStoreNotifyBenchmark extends BenchmarkBase {
  late alien.WritableSignal<int> s;
  int _counter = 0;
  int _notifications = 0;
  late alien.Effect _stop;

  AlienSignalsStoreNotifyBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Signal.notify',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(0);
    _stop = alien.effect(() {
      _notifications += s();
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
  late alien.WritableSignal<int> s;
  final List<alien.Effect> _stops = [];
  int _counter = 0;
  int _checksum = 0;

  AlienSignalsStoreNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Signal.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(0);
    for (var i = 0; i < 1000; i++) {
      final stop = alien.effect(() {
        _checksum += s();
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

class AlienSignalsComputedLifecycleBenchmark extends BenchmarkBase {
  int _result = 0;

  AlienSignalsComputedLifecycleBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Computed.lifecycle',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final signal = alien.signal(42);
    final computed = alien.computed((_) => signal() * 2);
    _result = computed();
  }
}

class AlienSignalsComputedReadBenchmark extends BenchmarkBase {
  late alien.WritableSignal<int> s;
  late alien.Computed<int> c;
  int _result = 0;

  AlienSignalsComputedReadBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Computed.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(42);
    c = alien.computed((_) => s() * 2);
    _result = c();
  }

  @override
  void run() {
    _result = c();
  }
}

class AlienSignalsComputedRecomputeBenchmark extends BenchmarkBase {
  late alien.WritableSignal<int> s;
  late alien.Computed<int> c;
  int _counter = 0;
  int _result = 0;

  AlienSignalsComputedRecomputeBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Computed.recompute',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(0);
    c = alien.computed((_) => s() * 2);
    _result = c();
  }

  @override
  void run() {
    s.set(++_counter);
    _result = c();
  }
}

class AlienSignalsComputedChainBenchmark extends BenchmarkBase {
  late alien.WritableSignal<int> s;
  late alien.Computed<int> doubled;
  late alien.Computed<int> sum;
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
    _result = sum();
  }

  @override
  void run() {
    s.set(++_counter);
    _result = sum();
  }
}

class AlienSignalsComputedManyDependentsBenchmark extends BenchmarkBase {
  late alien.WritableSignal<int> s;
  final List<alien.Computed<int>> _computeds = [];
  int _counter = 0;
  int _checksum = 0;

  AlienSignalsComputedManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('AlienSignals: Computed.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    s = alien.signal(0);
    for (var i = 0; i < 1000; i++) {
      final computed = alien.computed((_) => s() * 2);
      _computeds.add(computed);
      _checksum += computed();
    }
  }

  @override
  void run() {
    s.set(++_counter);
    for (final computed in _computeds) {
      _checksum += computed();
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
  final emitter = CollectingScoreEmitter(_extractFeature, _extractTiming);

  // State Holder Benchmarks
  AlienSignalsStoreLifecycleBenchmark(emitter: emitter).report();
  AlienSignalsStoreReadBenchmark(emitter: emitter).report();
  AlienSignalsStoreWriteBenchmark(emitter: emitter).report();
  AlienSignalsStoreNotifyBenchmark(emitter: emitter).report();
  AlienSignalsStoreNotifyManyDependentsBenchmark(emitter: emitter).report();

  // Recomputable View Benchmarks
  AlienSignalsComputedLifecycleBenchmark(emitter: emitter).report();
  AlienSignalsComputedReadBenchmark(emitter: emitter).report();
  AlienSignalsComputedRecomputeBenchmark(emitter: emitter).report();
  AlienSignalsComputedChainBenchmark(emitter: emitter).report();
  AlienSignalsComputedManyDependentsBenchmark(emitter: emitter).report();

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
