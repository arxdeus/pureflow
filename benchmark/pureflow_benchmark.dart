import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:pureflow/pureflow.dart';

/// Benchmark suite for PureFlow reactive primitives using benchmark_harness.
void main() {
  print('PureFlow - Performance Benchmark (benchmark_harness)\n');
  print('=' * 60);

  SignalCreationBenchmark().report();
  SignalReadsBenchmark().report();
  SignalWritesBenchmark().report();
  ComputedCreationBenchmark().report();
  ComputedReadsBenchmark().report();
  ComputedChainBenchmark().report();
  BatchUpdatesBenchmark().report();
  DiamondDependencyBenchmark().report();
  ManyDependentsBenchmark().report();
  MemoryEfficiencyBenchmark().report();

  print('=' * 60);
  print('Benchmark complete.\n');
}

// ============================================================================
// Signal Benchmarks
// ============================================================================

class SignalCreationBenchmark extends BenchmarkBase {
  static const int _batchSize = 1000;
  late List<Signal<int>> _signals;

  SignalCreationBenchmark() : super('Signal creation');

  @override
  void setup() {
    _signals = [];
  }

  @override
  void run() {
    for (var i = 0; i < _batchSize; i++) {
      _signals.add(Signal(i));
    }
  }

  @override
  void teardown() {
    for (final s in _signals) {
      s.dispose();
    }
    _signals.clear();
  }
}

class SignalReadsBenchmark extends BenchmarkBase {
  static const int _readsPerRun = 1000;
  late Signal<int> _signal;
  int _sum = 0;

  SignalReadsBenchmark() : super('Signal reads');

  @override
  void setup() {
    _signal = Signal(42);
    _sum = 0;
  }

  @override
  void run() {
    for (var i = 0; i < _readsPerRun; i++) {
      _sum += _signal.value;
    }
  }

  @override
  void teardown() {
    _signal.dispose();
    // Prevent optimization
    if (_sum == 0) print('');
  }
}

class SignalWritesBenchmark extends BenchmarkBase {
  static const int _writesPerRun = 1000;
  late Signal<int> _signal;

  SignalWritesBenchmark() : super('Signal writes');

  @override
  void setup() {
    _signal = Signal(0);
  }

  @override
  void run() {
    for (var i = 0; i < _writesPerRun; i++) {
      _signal.value = i;
    }
  }

  @override
  void teardown() {
    _signal.dispose();
  }
}

// ============================================================================
// Computed Benchmarks
// ============================================================================

class ComputedCreationBenchmark extends BenchmarkBase {
  static const int _batchSize = 100;
  late Signal<int> _source;
  late List<Computed<int>> _computeds;

  ComputedCreationBenchmark() : super('Computed creation');

  @override
  void setup() {
    _source = Signal(1);
    _computeds = [];
  }

  @override
  void run() {
    for (var i = 0; i < _batchSize; i++) {
      _computeds.add(Computed(() => _source.value * 2));
    }
  }

  @override
  void teardown() {
    for (final c in _computeds) {
      c.dispose();
    }
    _computeds.clear();
    _source.dispose();
  }
}

class ComputedReadsBenchmark extends BenchmarkBase {
  static const int _readsPerRun = 1000;
  late Signal<int> _signal;
  late Computed<int> _computed;
  int _sum = 0;

  ComputedReadsBenchmark() : super('Computed reads (cached)');

  @override
  void setup() {
    _signal = Signal(10);
    _computed = Computed(() => _signal.value * 2);
    _sum = 0;
  }

  @override
  void run() {
    for (var i = 0; i < _readsPerRun; i++) {
      _sum += _computed.value;
    }
  }

  @override
  void teardown() {
    _computed.dispose();
    _signal.dispose();
    // Prevent optimization
    if (_sum == 0) print('');
  }
}

class ComputedChainBenchmark extends BenchmarkBase {
  static const int _updatesPerRun = 100;
  late Signal<int> _source;
  late Computed<int> _c1;
  late Computed<int> _c2;
  late Computed<int> _c3;
  late Computed<int> _c4;
  late Computed<int> _c5;

  ComputedChainBenchmark() : super('Computed chain (5 deep)');

  @override
  void setup() {
    _source = Signal(1);
    _c1 = Computed(() => _source.value + 1);
    _c2 = Computed(() => _c1.value + 1);
    _c3 = Computed(() => _c2.value + 1);
    _c4 = Computed(() => _c3.value + 1);
    _c5 = Computed(() => _c4.value + 1);
  }

  @override
  void run() {
    for (var i = 0; i < _updatesPerRun; i++) {
      _source.value = i;
      final _ = _c5.value; // Force recomputation through chain
    }
  }

  @override
  void teardown() {
    _c5.dispose();
    _c4.dispose();
    _c3.dispose();
    _c2.dispose();
    _c1.dispose();
    _source.dispose();
  }
}

// ============================================================================
// Batch Benchmarks
// ============================================================================

class BatchUpdatesBenchmark extends BenchmarkBase {
  static const int _updatesPerRun = 100;
  static const int _signalCount = 10;
  late List<Signal<int>> _signals;
  late Computed<int> _sum;

  BatchUpdatesBenchmark() : super('Batch updates (10 signals)');

  @override
  void setup() {
    _signals = List.generate(_signalCount, Signal.new);
    _sum = Computed(() {
      var total = 0;
      for (final s in _signals) {
        total += s.value;
      }
      return total;
    });
  }

  @override
  void run() {
    for (var i = 0; i < _updatesPerRun; i++) {
      Signal.batch(() {
        for (var j = 0; j < _signalCount; j++) {
          _signals[j].value = i + j;
        }
      });
      final _ = _sum.value;
    }
  }

  @override
  void teardown() {
    _sum.dispose();
    for (final s in _signals) {
      s.dispose();
    }
  }
}

// ============================================================================
// Complex Dependency Benchmarks
// ============================================================================

class DiamondDependencyBenchmark extends BenchmarkBase {
  static const int _updatesPerRun = 100;
  late Signal<int> _source;
  late Computed<int> _left;
  late Computed<int> _right;
  late Computed<int> _bottom;

  DiamondDependencyBenchmark() : super('Diamond dependency');

  @override
  void setup() {
    //     source
    //    /      \
    //  left    right
    //    \      /
    //     bottom
    _source = Signal(1);
    _left = Computed(() => _source.value + 1);
    _right = Computed(() => _source.value + 2);
    _bottom = Computed(() => _left.value + _right.value);
  }

  @override
  void run() {
    for (var i = 0; i < _updatesPerRun; i++) {
      _source.value = i;
      final _ = _bottom.value;
    }
  }

  @override
  void teardown() {
    _bottom.dispose();
    _right.dispose();
    _left.dispose();
    _source.dispose();
  }
}

class ManyDependentsBenchmark extends BenchmarkBase {
  static const int _updatesPerRun = 10;
  static const int _dependentCount = 100;
  late Signal<int> _source;
  late List<Computed<int>> _computeds;

  ManyDependentsBenchmark() : super('Many dependents (100)');

  @override
  void setup() {
    _source = Signal(0);
    _computeds = List.generate(
      _dependentCount,
      (i) => Computed(() => _source.value + i),
    );
  }

  @override
  void run() {
    for (var i = 0; i < _updatesPerRun; i++) {
      _source.value = i;
      // Read all to trigger recomputation
      for (final c in _computeds) {
        final _ = c.value;
      }
    }
  }

  @override
  void teardown() {
    for (final c in _computeds) {
      c.dispose();
    }
    _source.dispose();
  }
}

// ============================================================================
// Memory Efficiency
// ============================================================================

class MemoryEfficiencyBenchmark extends BenchmarkBase {
  static const int _signalCount = 1000;
  late List<Signal<int>> _signals;
  int _sum = 0;

  MemoryEfficiencyBenchmark() : super('Signals w/o deps');

  @override
  void setup() {
    // Create signals without dependents (should use minimal memory)
    _signals = List.generate(_signalCount, Signal.new);
    _sum = 0;
  }

  @override
  void run() {
    // Read values without computed context (no dependency tracking)
    for (final s in _signals) {
      _sum += s.value;
    }
  }

  @override
  void teardown() {
    for (final s in _signals) {
      s.dispose();
    }
    // Prevent optimization
    if (_sum == 0) print('');
  }
}
