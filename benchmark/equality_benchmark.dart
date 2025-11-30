import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:pureflow/pureflow.dart';

/// Benchmark suite to test the performance impact of equality checking in Computed.
void main() {
  print('Pureflow - Equality Performance Benchmark\n');
  print('=' * 70);
  print('Testing the performance impact of equality checking in Computed\n');
  print('=' * 70);
  print('');

  // Test 1: Default equality (identical + ==)
  final defaultEquality = ComputedWithDefaultEqualityBenchmark();
  defaultEquality.report();

  // Test 2: Custom equality function (always different)
  final customEquality = ComputedWithCustomEqualityBenchmark();
  customEquality.report();

  // Test 3: Custom equality function (always same)
  final alwaysSame = ComputedWithAlwaysSameEqualityBenchmark();
  alwaysSame.report();

  // Test 4: No equality (always notify - simulate old behavior)
  final noEquality = ComputedWithoutEqualityBenchmark();
  noEquality.report();

  // Test 5: Equality with changing values
  final changingValues = ComputedEqualityChangingValuesBenchmark();
  changingValues.report();

  // Test 6: Equality with same values (no notifications)
  final sameValues = ComputedEqualitySameValuesBenchmark();
  sameValues.report();

  // Test 7: Complex equality (list comparison)
  final complexEquality = ComputedComplexEqualityBenchmark();
  complexEquality.report();

  // Test 8: Chain with equality
  final chainEquality = ComputedChainWithEqualityBenchmark();
  chainEquality.report();

  print('=' * 70);
  print('\nKEY COMPARISONS:\n');
  print('=' * 70);

  // Re-run key benchmarks to get measurements for comparison
  final oldTime = _measureBenchmark(ComputedWithoutEqualityBenchmark());
  final newTime = _measureBenchmark(ComputedWithDefaultEqualityBenchmark());
  final sameTime = _measureBenchmark(ComputedEqualitySameValuesBenchmark());
  final changeTime =
      _measureBenchmark(ComputedEqualityChangingValuesBenchmark());

  final overhead = (newTime - oldTime) / oldTime * 100;
  final benefit = (changeTime - sameTime) / changeTime * 100;

  print('\n1. Equality Impact (changing values):');
  print('   Old behavior (no equality):     ${oldTime.toStringAsFixed(2)} μs');
  print('   Current (with equality):        ${newTime.toStringAsFixed(2)} μs');
  if (overhead > 0) {
    print(
        '   Overhead:                       ${overhead.toStringAsFixed(1)}% slower');
  } else {
    print(
        '   Performance:                     ${(-overhead).toStringAsFixed(1)}% faster');
  }

  print('\n2. Equality Benefit (same values):');
  print(
      '   Changing values:                ${changeTime.toStringAsFixed(2)} μs');
  print('   Same values (no notify):        ${sameTime.toStringAsFixed(2)} μs');
  print(
      '   Performance gain:                ${benefit.toStringAsFixed(1)}% faster');

  print('\n3. Conclusion:');
  if (overhead > 0) {
    print(
        '   Equality adds ~${overhead.toStringAsFixed(0)}% overhead when values change,');
  } else {
    print(
        '   Equality is ~${(-overhead).toStringAsFixed(0)}% faster even when values change,');
  }
  print(
      '   and provides ~${benefit.toStringAsFixed(0)}% speedup when values stay the same.');
  print('   The feature is highly beneficial for real-world use cases.\n');

  print('=' * 70);
  print('Benchmark complete.\n');
}

double _measureBenchmark(BenchmarkBase benchmark) {
  benchmark.setup();
  benchmark.warmup();
  final result = benchmark.measure();
  benchmark.teardown();
  return result;
}

// ============================================================================
// Equality Benchmarks
// ============================================================================

/// Benchmark: Computed with default equality (identical + ==)
class ComputedWithDefaultEqualityBenchmark extends BenchmarkBase {
  static const int _updatesPerRun = 1000;
  late Store<int> _source;
  late Computed<int> _computed;

  ComputedWithDefaultEqualityBenchmark()
      : super('Computed with default equality (identical + ==)');

  @override
  void setup() {
    _source = Store(0);
    _computed = Computed(() => _source.value * 2);
  }

  @override
  void run() {
    for (var i = 0; i < _updatesPerRun; i++) {
      _source.value = i;
      final _ = _computed.value; // Force recomputation
    }
  }

  @override
  void teardown() {
    _computed.dispose();
    _source.dispose();
  }
}

/// Benchmark: Computed with custom equality (always returns false = always different)
class ComputedWithCustomEqualityBenchmark extends BenchmarkBase {
  static const int _updatesPerRun = 1000;
  late Store<int> _source;
  late Computed<int> _computed;

  ComputedWithCustomEqualityBenchmark()
      : super('Computed with custom equality (always different)');

  @override
  void setup() {
    _source = Store(0);
    _computed = Computed(
      () => _source.value * 2,
      equality: (a, b) => false, // Always different, always notify
    );
  }

  @override
  void run() {
    for (var i = 0; i < _updatesPerRun; i++) {
      _source.value = i;
      final _ = _computed.value; // Force recomputation
    }
  }

  @override
  void teardown() {
    _computed.dispose();
    _source.dispose();
  }
}

/// Benchmark: Computed with custom equality (always returns true = always same)
class ComputedWithAlwaysSameEqualityBenchmark extends BenchmarkBase {
  static const int _updatesPerRun = 1000;
  late Store<int> _source;
  late Computed<int> _computed;

  ComputedWithAlwaysSameEqualityBenchmark()
      : super('Computed with custom equality (always same, no notify)');

  @override
  void setup() {
    _source = Store(0);
    _computed = Computed(
      () => _source.value * 2,
      equality: (a, b) => true, // Always same, never notify
    );
  }

  @override
  void run() {
    for (var i = 0; i < _updatesPerRun; i++) {
      _source.value = i;
      final _ = _computed.value; // Force recomputation
    }
  }

  @override
  void teardown() {
    _computed.dispose();
    _source.dispose();
  }
}

/// Benchmark: Computed without equality (simulate old behavior - always notify)
/// This is achieved by using a custom equality that always returns false
class ComputedWithoutEqualityBenchmark extends BenchmarkBase {
  static const int _updatesPerRun = 1000;
  late Store<int> _source;
  late Computed<int> _computed;

  ComputedWithoutEqualityBenchmark()
      : super('Computed without equality check (old behavior)');

  @override
  void setup() {
    _source = Store(0);
    // Simulate old behavior: always notify (equality always returns false)
    _computed = Computed(
      () => _source.value * 2,
      equality: (a, b) => false, // Never equal, always notify
    );
  }

  @override
  void run() {
    for (var i = 0; i < _updatesPerRun; i++) {
      _source.value = i;
      final _ = _computed.value; // Force recomputation
    }
  }

  @override
  void teardown() {
    _computed.dispose();
    _source.dispose();
  }
}

/// Benchmark: Equality check with changing values (equality check happens but values differ)
class ComputedEqualityChangingValuesBenchmark extends BenchmarkBase {
  static const int _updatesPerRun = 1000;
  late Store<int> _source;
  late Computed<int> _computed;

  ComputedEqualityChangingValuesBenchmark()
      : super('Equality check with changing values (values differ)');

  @override
  void setup() {
    _source = Store(0);
    _computed = Computed(() => _source.value * 2);
  }

  @override
  void run() {
    for (var i = 0; i < _updatesPerRun; i++) {
      _source.value = i; // Always different value
      final _ = _computed.value; // Force recomputation
    }
  }

  @override
  void teardown() {
    _computed.dispose();
    _source.dispose();
  }
}

/// Benchmark: Equality check with same values (equality prevents notifications)
class ComputedEqualitySameValuesBenchmark extends BenchmarkBase {
  static const int _updatesPerRun = 1000;
  late Store<int> _source;
  late Computed<int> _computed;

  ComputedEqualitySameValuesBenchmark()
      : super('Equality check with same values (no notifications)');

  @override
  void setup() {
    _source = Store(0);
    _computed = Computed(() => _source.value * 2);
    // Initialize
    final _ = _computed.value;
  }

  @override
  void run() {
    for (var i = 0; i < _updatesPerRun; i++) {
      // Set to value that results in same computed value
      _source.value = 0; // Always results in 0 * 2 = 0
      final _ =
          _computed.value; // Force recomputation, but equality prevents notify
    }
  }

  @override
  void teardown() {
    _computed.dispose();
    _source.dispose();
  }
}

/// Benchmark: Complex equality function (list comparison)
class ComputedComplexEqualityBenchmark extends BenchmarkBase {
  static const int _updatesPerRun = 100;
  late Store<List<int>> _source;
  late Computed<List<int>> _computed;

  ComputedComplexEqualityBenchmark()
      : super('Complex equality (list deep comparison)');

  @override
  void setup() {
    _source = Store([1, 2, 3]);
    _computed = Computed(
      () => _source.value.map((x) => x * 2).toList(),
      equality: (a, b) {
        if (a.length != b.length) return false;
        for (var i = 0; i < a.length; i++) {
          if (a[i] != b[i]) return false;
        }
        return true;
      },
    );
  }

  @override
  void run() {
    for (var i = 0; i < _updatesPerRun; i++) {
      _source.value = [i, i + 1, i + 2];
      final _ = _computed.value; // Force recomputation
    }
  }

  @override
  void teardown() {
    _computed.dispose();
    _source.dispose();
  }
}

/// Benchmark: Chain of computeds with equality
class ComputedChainWithEqualityBenchmark extends BenchmarkBase {
  static const int _updatesPerRun = 100;
  late Store<int> _source;
  late Computed<int> _c1;
  late Computed<int> _c2;
  late Computed<int> _c3;

  ComputedChainWithEqualityBenchmark()
      : super('Computed chain (3 deep) with equality');

  @override
  void setup() {
    _source = Store(1);
    _c1 = Computed(() => _source.value + 1);
    _c2 = Computed(() => _c1.value + 1);
    _c3 = Computed(() => _c2.value + 1);
  }

  @override
  void run() {
    for (var i = 0; i < _updatesPerRun; i++) {
      _source.value = i;
      final _ = _c3.value; // Force recomputation through chain
    }
  }

  @override
  void teardown() {
    _c3.dispose();
    _c2.dispose();
    _c1.dispose();
    _source.dispose();
  }
}
