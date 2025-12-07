// ignore_for_file: unused_field, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/listenable.dart';
import 'package:benchmark_harness/benchmark_harness.dart';

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class ListenableValueNotifierCreateBenchmark extends BenchmarkBase {
  ListenableValueNotifierCreateBenchmark({ScoreEmitter? emitter})
      : super('ValueNotifier: ValueNotifier.create',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final notifier = ValueNotifier<int>(42);
    notifier.dispose();
  }
}

class ListenableValueNotifierReadBenchmark extends BenchmarkBase {
  late final ValueNotifier<int> notifier;
  int _result = 0;

  ListenableValueNotifierReadBenchmark({ScoreEmitter? emitter})
      : super('ValueNotifier: ValueNotifier.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    notifier = ValueNotifier<int>(42);
  }

  @override
  void run() {
    _result = notifier.value;
  }

  @override
  void teardown() {
    notifier.dispose();
  }
}

class ListenableValueNotifierWriteBenchmark extends BenchmarkBase {
  late final ValueNotifier<int> notifier;
  int _counter = 0;

  ListenableValueNotifierWriteBenchmark({ScoreEmitter? emitter})
      : super('ValueNotifier: ValueNotifier.write',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    notifier = ValueNotifier<int>(0);
  }

  @override
  void run() {
    notifier.value = ++_counter;
  }

  @override
  void teardown() {
    notifier.dispose();
  }
}

class ListenableValueNotifierNotifyBenchmark extends BenchmarkBase {
  late final ValueNotifier<int> notifier;
  int _counter = 0;
  int _notifications = 0;
  late final VoidCallback listener;

  ListenableValueNotifierNotifyBenchmark({ScoreEmitter? emitter})
      : super('ValueNotifier: ValueNotifier.notify',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    notifier = ValueNotifier<int>(0);
    listener = () {
      _notifications++;
    };
    notifier.addListener(listener);
  }

  @override
  void run() {
    notifier.value = ++_counter;
  }

  @override
  void teardown() {
    notifier.removeListener(listener);
    notifier.dispose();
  }
}

class ListenableValueNotifierNotifyManyDependentsBenchmark
    extends BenchmarkBase {
  late final ValueNotifier<int> notifier;
  final List<VoidCallback> _listeners = [];
  int _counter = 0;

  ListenableValueNotifierNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('ValueNotifier: ValueNotifier.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    notifier = ValueNotifier<int>(0);
    for (var i = 0; i < 1000; i++) {
      void listener() {
        // Just track that notification happened
      }
      notifier.addListener(listener);
      _listeners.add(listener);
    }
  }

  @override
  void run() {
    notifier.value = ++_counter;
  }

  @override
  void teardown() {
    for (final listener in _listeners) {
      notifier.removeListener(listener);
    }
    notifier.dispose();
  }
}

// ============================================================================
// Recomputable View Benchmarks
// ============================================================================

/// Helper class to emulate Computed behavior using ValueNotifier
class ComputedValueNotifier<T> extends ValueNotifier<T> {
  ComputedValueNotifier(this._compute, this._dependencies) : super(_compute()) {
    // Listen to all dependencies
    for (final dep in _dependencies) {
      dep.addListener(_recompute);
    }
  }

  final T Function() _compute;
  final List<ValueNotifier<Object?>> _dependencies;
  bool _disposed = false;

  void _recompute() {
    if (!_disposed) {
      value = _compute();
    }
  }

  @override
  void dispose() {
    if (!_disposed) {
      _disposed = true;
      for (final dep in _dependencies) {
        dep.removeListener(_recompute);
      }
      super.dispose();
    }
  }
}

class ListenableComputedCreateBenchmark extends BenchmarkBase {
  late final ValueNotifier<int> base;

  ListenableComputedCreateBenchmark({ScoreEmitter? emitter})
      : super('ValueNotifier: Computed.create',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    base = ValueNotifier<int>(42);
  }

  @override
  void run() {
    final computed = ComputedValueNotifier<int>(
      () => base.value * 2,
      [base],
    );
    computed.dispose();
  }

  @override
  void teardown() {
    base.dispose();
  }
}

class ListenableComputedReadBenchmark extends BenchmarkBase {
  late final ValueNotifier<int> base;
  late final ComputedValueNotifier<int> computed;
  int _result = 0;

  ListenableComputedReadBenchmark({ScoreEmitter? emitter})
      : super('ValueNotifier: Computed.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    base = ValueNotifier<int>(42);
    computed = ComputedValueNotifier<int>(
      () => base.value * 2,
      [base],
    );
  }

  @override
  void run() {
    _result = computed.value;
  }

  @override
  void teardown() {
    computed.dispose();
    base.dispose();
  }
}

class ListenableComputedRecomputeBenchmark extends BenchmarkBase {
  late final ValueNotifier<int> base;
  late final ComputedValueNotifier<int> computed;
  int _counter = 0;
  int _result = 0;

  ListenableComputedRecomputeBenchmark({ScoreEmitter? emitter})
      : super('ValueNotifier: Computed.recompute',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    base = ValueNotifier<int>(0);
    computed = ComputedValueNotifier<int>(
      () => base.value * 2,
      [base],
    );
  }

  @override
  void run() {
    base.value = ++_counter;
    _result = computed.value;
  }

  @override
  void teardown() {
    computed.dispose();
    base.dispose();
  }
}

class ListenableComputedChainBenchmark extends BenchmarkBase {
  late final ValueNotifier<int> base;
  late final ComputedValueNotifier<int> doubled;
  late final ComputedValueNotifier<int> sum;
  int _counter = 0;
  int _result = 0;

  ListenableComputedChainBenchmark({ScoreEmitter? emitter})
      : super('ValueNotifier: Computed.chain',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    base = ValueNotifier<int>(0);
    doubled = ComputedValueNotifier<int>(
      () => base.value * 2,
      [base],
    );
    sum = ComputedValueNotifier<int>(
      () => doubled.value + 10,
      [doubled],
    );
  }

  @override
  void run() {
    base.value = ++_counter;
    _result = sum.value;
  }

  @override
  void teardown() {
    sum.dispose();
    doubled.dispose();
    base.dispose();
  }
}

class ListenableComputedChainManyDependentsBenchmark extends BenchmarkBase {
  late final ValueNotifier<int> base;
  final List<ComputedValueNotifier<int>> _computeds = [];
  int _counter = 0;

  ListenableComputedChainManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('ValueNotifier: Computed.chain.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    base = ValueNotifier<int>(0);
    for (var i = 0; i < 1000; i++) {
      final computed = ComputedValueNotifier<int>(
        () => base.value * 2,
        [base],
      );
      _computeds.add(computed);
    }
  }

  @override
  void run() {
    base.value = ++_counter;
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
    base.dispose();
  }
}

// ============================================================================
// Main
// ============================================================================

Future<List<BenchmarkResult>> runBenchmark() async {
  // Create custom emitter to collect results
  final emitter = CollectingScoreEmitter(_extractFeature);

  // State Holder Benchmarks
  ListenableValueNotifierCreateBenchmark(emitter: emitter).report();
  ListenableValueNotifierReadBenchmark(emitter: emitter).report();
  ListenableValueNotifierWriteBenchmark(emitter: emitter).report();
  ListenableValueNotifierNotifyBenchmark(emitter: emitter).report();
  ListenableValueNotifierNotifyManyDependentsBenchmark(emitter: emitter)
      .report();

  // Recomputable View Benchmarks
  ListenableComputedCreateBenchmark(emitter: emitter).report();
  ListenableComputedReadBenchmark(emitter: emitter).report();
  ListenableComputedRecomputeBenchmark(emitter: emitter).report();
  ListenableComputedChainBenchmark(emitter: emitter).report();
  ListenableComputedChainManyDependentsBenchmark(emitter: emitter).report();

  return emitter.results;
}

String _extractFeature(String benchmarkName) {
  if (benchmarkName.contains('ValueNotifier.create') &&
      !benchmarkName.contains('Computed')) {
    return 'State Holder: Create';
  }
  if (benchmarkName.contains('ValueNotifier.read') &&
      !benchmarkName.contains('Computed')) {
    return 'State Holder: Read';
  }
  if (benchmarkName.contains('ValueNotifier.write')) {
    return 'State Holder: Write';
  }
  if (benchmarkName.contains('ValueNotifier.notify.many_dependents')) {
    return 'State Holder: Notify - Many Dependents (1000)';
  }
  if (benchmarkName.contains('ValueNotifier.notify')) {
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
