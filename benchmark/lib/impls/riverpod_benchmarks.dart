// ignore_for_file: unused_field, use_setters_to_change_properties

import 'dart:async';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/fair_benchmark_base.dart';
import 'package:riverpod/riverpod.dart' as rp;

// ============================================================================
// Shared Notifier
// ============================================================================

/// Minimal int [rp.Notifier] for the NotifierProvider benchmarks. The initial
/// value is injected so each provider declaration can seed its own state.
class IntNotifier extends rp.Notifier<int> {
  IntNotifier(this._initial);

  final int _initial;

  @override
  int build() => _initial;

  void set(int value) => state = value;
}

rp.NotifierProvider<IntNotifier, int> intProvider(int initial) =>
    rp.NotifierProvider<IntNotifier, int>(() => IntNotifier(initial));

// ============================================================================
// State Holder Benchmarks
// ============================================================================

/// Measures the cost of creating and initializing a NotifierProvider.
/// Riverpod requires a ProviderContainer for any provider usage, and a single
/// container accumulates unbounded state across iterations (causing hangs).
/// Therefore the full container lifecycle (create → read → dispose) is
/// measured per iteration. This reflects the real minimum cost of getting
/// a usable state holder in Riverpod.
class RiverpodNotifierProviderCreateBenchmark extends BenchmarkBase {
  int _result = 0;

  RiverpodNotifierProviderCreateBenchmark({ScoreEmitter? emitter})
      : super('Riverpod: NotifierProvider.lifecycle',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final container = rp.ProviderContainer();
    final provider = intProvider(42);
    _result = container.read(provider);
    container.dispose();
  }
}

/// Note: Riverpod reads go through `container.read()` which involves a map
/// lookup by provider identity, unlike other libraries that use direct field
/// access. This indirection is inherent to Riverpod's architecture.
class RiverpodNotifierProviderReadBenchmark extends BenchmarkBase {
  late rp.ProviderContainer container;
  late rp.NotifierProvider<IntNotifier, int> provider;
  int _result = 0;

  RiverpodNotifierProviderReadBenchmark({ScoreEmitter? emitter})
      : super('Riverpod: NotifierProvider.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    container = rp.ProviderContainer();
    provider = intProvider(42);
  }

  @override
  void run() {
    _result = container.read(provider);
  }

  @override
  void teardown() {
    container.dispose();
  }
}

/// Note: Riverpod writes go through `container.read(provider.notifier).set(..)`
/// which is two indirections (container lookup + notifier access) vs a direct
/// assignment in other libraries.
class RiverpodNotifierProviderWriteBenchmark extends BenchmarkBase {
  late rp.ProviderContainer container;
  late rp.NotifierProvider<IntNotifier, int> provider;
  int _counter = 0;

  RiverpodNotifierProviderWriteBenchmark({ScoreEmitter? emitter})
      : super('Riverpod: NotifierProvider.write',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    container = rp.ProviderContainer();
    provider = intProvider(0);
  }

  @override
  void run() {
    container.read(provider.notifier).set(++_counter);
  }

  @override
  void teardown() {
    container.dispose();
  }
}

class RiverpodNotifierProviderNotifyBenchmark extends BenchmarkBase {
  late rp.ProviderContainer container;
  late rp.NotifierProvider<IntNotifier, int> provider;
  int _counter = 0;
  int _checksum = 0;
  late rp.ProviderSubscription<int> subscription;

  RiverpodNotifierProviderNotifyBenchmark({ScoreEmitter? emitter})
      : super('Riverpod: NotifierProvider.notify',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    container = rp.ProviderContainer();
    provider = intProvider(0);
    subscription = container.listen<int>(provider, (previous, next) {
      _checksum += next;
    });
  }

  @override
  void run() {
    container.read(provider.notifier).set(++_counter);
  }

  @override
  void teardown() {
    subscription.close();
    container.dispose();
  }
}

class RiverpodNotifierProviderNotifyManyDependentsBenchmark
    extends BenchmarkBase {
  late rp.ProviderContainer container;
  late rp.NotifierProvider<IntNotifier, int> provider;
  final List<rp.ProviderSubscription<int>> _subscriptions = [];
  int _counter = 0;
  int _checksum = 0;

  RiverpodNotifierProviderNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Riverpod: NotifierProvider.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    container = rp.ProviderContainer();
    provider = intProvider(0);
    for (var i = 0; i < 1000; i++) {
      final subscription = container.listen<int>(provider, (previous, next) {
        _checksum += next;
      });
      _subscriptions.add(subscription);
    }
  }

  @override
  void run() {
    container.read(provider.notifier).set(++_counter);
  }

  @override
  void teardown() {
    for (final subscription in _subscriptions) {
      subscription.close();
    }
    _subscriptions.clear();
    container.dispose();
  }
}

// ============================================================================
// Recomputable View Benchmarks
// ============================================================================

/// Measures the cost of creating a computed (derived) provider.
/// Riverpod requires a ProviderContainer + base provider for any computed.
/// A single container accumulates unbounded dependents across iterations
/// (causing hangs), so the full lifecycle is measured per iteration.
/// This reflects the real minimum cost of getting a usable computed in
/// Riverpod.
class RiverpodComputedCreateBenchmark extends BenchmarkBase {
  int _result = 0;

  RiverpodComputedCreateBenchmark({ScoreEmitter? emitter})
      : super('Riverpod: Computed.lifecycle',
            emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final container = rp.ProviderContainer();
    final baseProvider = intProvider(42);
    final computedProvider =
        rp.Provider<int>((ref) => ref.watch(baseProvider) * 2);
    _result = container.read(computedProvider);
    container.dispose();
  }
}

class RiverpodComputedReadBenchmark extends BenchmarkBase {
  late rp.ProviderContainer container;
  late rp.NotifierProvider<IntNotifier, int> baseProvider;
  late rp.Provider<int> computedProvider;
  int _result = 0;

  RiverpodComputedReadBenchmark({ScoreEmitter? emitter})
      : super('Riverpod: Computed.read',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    container = rp.ProviderContainer();
    baseProvider = intProvider(42);
    computedProvider = rp.Provider<int>((ref) {
      return ref.watch(baseProvider) * 2;
    });
    _result = container.read(computedProvider);
  }

  @override
  void run() {
    _result = container.read(computedProvider);
  }

  @override
  void teardown() {
    container.dispose();
  }
}

class RiverpodComputedRecomputeBenchmark extends BenchmarkBase {
  late rp.ProviderContainer container;
  late rp.NotifierProvider<IntNotifier, int> baseProvider;
  late rp.Provider<int> computedProvider;
  int _counter = 0;
  int _result = 0;

  RiverpodComputedRecomputeBenchmark({ScoreEmitter? emitter})
      : super('Riverpod: Computed.recompute',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    container = rp.ProviderContainer();
    baseProvider = intProvider(0);
    computedProvider = rp.Provider<int>((ref) {
      return ref.watch(baseProvider) * 2;
    });
    _result = container.read(computedProvider);
  }

  @override
  void run() {
    container.read(baseProvider.notifier).set(++_counter);
    _result = container.read(computedProvider);
  }

  @override
  void teardown() {
    container.dispose();
  }
}

class RiverpodComputedChainBenchmark extends BenchmarkBase {
  late rp.ProviderContainer container;
  late rp.NotifierProvider<IntNotifier, int> baseProvider;
  late rp.Provider<int> doubledProvider;
  late rp.Provider<int> sumProvider;
  int _counter = 0;
  int _result = 0;

  RiverpodComputedChainBenchmark({ScoreEmitter? emitter})
      : super('Riverpod: Computed.chain',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    container = rp.ProviderContainer();
    baseProvider = intProvider(0);
    doubledProvider = rp.Provider<int>((ref) {
      return ref.watch(baseProvider) * 2;
    });
    sumProvider = rp.Provider<int>((ref) {
      return ref.watch(doubledProvider) + 10;
    });
    _result = container.read(sumProvider);
  }

  @override
  void run() {
    container.read(baseProvider.notifier).set(++_counter);
    _result = container.read(sumProvider);
  }

  @override
  void teardown() {
    container.dispose();
  }
}

class RiverpodComputedManyDependentsBenchmark extends BenchmarkBase {
  late rp.ProviderContainer container;
  late rp.NotifierProvider<IntNotifier, int> baseProvider;
  final List<rp.Provider<int>> _computedProviders = [];
  int _counter = 0;
  int _checksum = 0;

  RiverpodComputedManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Riverpod: Computed.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    container = rp.ProviderContainer();
    baseProvider = intProvider(0);
    for (var i = 0; i < 1000; i++) {
      final computedProvider = rp.Provider<int>((ref) {
        return ref.watch(baseProvider) * 2;
      });
      _computedProviders.add(computedProvider);
      final value = container.read(computedProvider);
      _checksum += value;
    }
  }

  @override
  void run() {
    container.read(baseProvider.notifier).set(++_counter);
    // Access all computed providers to trigger recomputation
    for (final computedProvider in _computedProviders) {
      final value = container.read(computedProvider);
      _checksum += value;
    }
  }

  @override
  void teardown() {
    container.dispose();
    _computedProviders.clear();
  }
}

// ============================================================================
// Main
// ============================================================================

Future<List<BenchmarkResult>> runBenchmark() async {
  // Create custom emitter to collect results
  final emitter = CollectingScoreEmitter(_extractFeature, _extractTiming);

  // State Holder Benchmarks
  RiverpodNotifierProviderCreateBenchmark(emitter: emitter).report();
  RiverpodNotifierProviderReadBenchmark(emitter: emitter).report();
  RiverpodNotifierProviderWriteBenchmark(emitter: emitter).report();
  RiverpodNotifierProviderNotifyBenchmark(emitter: emitter).report();
  RiverpodNotifierProviderNotifyManyDependentsBenchmark(emitter: emitter)
      .report();

  // Recomputable View Benchmarks
  RiverpodComputedCreateBenchmark(emitter: emitter).report();
  RiverpodComputedReadBenchmark(emitter: emitter).report();
  RiverpodComputedRecomputeBenchmark(emitter: emitter).report();
  RiverpodComputedChainBenchmark(emitter: emitter).report();
  RiverpodComputedManyDependentsBenchmark(emitter: emitter).report();

  return emitter.results;
}

String _extractFeature(String benchmarkName) {
  if (benchmarkName.contains('NotifierProvider.lifecycle')) {
    return 'State Holder: Lifecycle (Create + Use + Release)';
  }
  if (benchmarkName.contains('NotifierProvider.read')) {
    return 'State Holder: Read';
  }
  if (benchmarkName.contains('NotifierProvider.write')) {
    return 'State Holder: Write';
  }
  if (benchmarkName.contains('NotifierProvider.notify.many_dependents')) {
    return 'State Holder: Notify - Many Dependents (1000)';
  }
  if (benchmarkName.contains('NotifierProvider.notify')) {
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
