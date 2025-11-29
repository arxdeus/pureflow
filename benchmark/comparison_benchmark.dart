import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:pureflow/pureflow.dart' as pureflow;
import 'package:signals_core/signals_core.dart' as signals;

/// Comparison benchmark: PureFlow vs signals_core (pub.dev)
void main() {
  print('PureFlow vs signals_core - Performance Comparison');
  print('Using benchmark_harness (10 iterations, 2s warmup)\n');
  print('=' * 85);

  _runComparison(
      'Signal creation', PureFlowSignalCreation(), SignalsSignalCreation());
  _runComparison('Signal reads', PureFlowSignalReads(), SignalsSignalReads());
  _runComparison(
      'Signal writes', PureFlowSignalWrites(), SignalsSignalWrites());
  _runComparison('Computed creation', PureFlowComputedCreation(),
      SignalsComputedCreation());
  _runComparison(
      'Computed reads', PureFlowComputedReads(), SignalsComputedReads());
  _runComparison(
      'Computed chain (5)', PureFlowComputedChain(), SignalsComputedChain());
  _runComparison('Batch (10 signals)', PureFlowBatch(), SignalsBatch());
  _runComparison('Diamond dependency', PureFlowDiamond(), SignalsDiamond());
  _runComparison(
      'Many dependents', PureFlowManyDependents(), SignalsManyDependents());

  print('=' * 85);
  print('\nLower μs/op is better. Benchmark complete.');
}

void _runComparison(
    String name, BenchmarkBase pureflow, BenchmarkBase signalsLib) {
  final pureUs = pureflow.measure();
  final signalsUs = signalsLib.measure();

  final ratio = signalsUs / pureUs;
  final winner = ratio > 1 ? 'PureFlow' : 'signals';
  final diff = ratio > 1 ? ratio : 1 / ratio;

  print(
    '${name.padRight(20)} '
    'PureFlow: ${pureUs.toStringAsFixed(2).padLeft(10)} μs  '
    'signals: ${signalsUs.toStringAsFixed(2).padLeft(10)} μs  '
    '[$winner ${diff.toStringAsFixed(1)}x faster]',
  );
}

// ============================================================================
// Signal Creation
// ============================================================================

class PureFlowSignalCreation extends BenchmarkBase {
  PureFlowSignalCreation() : super('PureFlow Signal Creation');

  late List<pureflow.Signal<int>> _signals;

  @override
  void run() {
    _signals = List.generate(1000, pureflow.Signal.new);
  }

  @override
  void teardown() {
    for (final s in _signals) {
      s.dispose();
    }
  }
}

class SignalsSignalCreation extends BenchmarkBase {
  SignalsSignalCreation() : super('Signals Signal Creation');

  late List<signals.Signal<int>> _signals;

  @override
  void run() {
    _signals = List.generate(1000, signals.signal);
  }

  @override
  void teardown() {
    for (final s in _signals) {
      s.dispose();
    }
  }
}

// ============================================================================
// Signal Reads
// ============================================================================

class PureFlowSignalReads extends BenchmarkBase {
  PureFlowSignalReads() : super('PureFlow Signal Reads');

  late pureflow.Signal<int> _signal;

  @override
  void setup() {
    _signal = pureflow.Signal(42);
  }

  @override
  void run() {
    var sum = 0;
    for (var i = 0; i < 10000; i++) {
      sum += _signal.value;
    }
    if (sum == 0) throw StateError('Optimization prevention');
  }

  @override
  void teardown() {
    _signal.dispose();
  }
}

class SignalsSignalReads extends BenchmarkBase {
  SignalsSignalReads() : super('Signals Signal Reads');

  late signals.Signal<int> _signal;

  @override
  void setup() {
    _signal = signals.signal(42);
  }

  @override
  void run() {
    var sum = 0;
    for (var i = 0; i < 10000; i++) {
      sum += _signal.value;
    }
    if (sum == 0) throw StateError('Optimization prevention');
  }

  @override
  void teardown() {
    _signal.dispose();
  }
}

// ============================================================================
// Signal Writes
// ============================================================================

class PureFlowSignalWrites extends BenchmarkBase {
  PureFlowSignalWrites() : super('PureFlow Signal Writes');

  late pureflow.Signal<int> _signal;

  @override
  void setup() {
    _signal = pureflow.Signal(0);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      _signal.value = i;
    }
  }

  @override
  void teardown() {
    _signal.dispose();
  }
}

class SignalsSignalWrites extends BenchmarkBase {
  SignalsSignalWrites() : super('Signals Signal Writes');

  late signals.Signal<int> _signal;

  @override
  void setup() {
    _signal = signals.signal(0);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      _signal.value = i;
    }
  }

  @override
  void teardown() {
    _signal.dispose();
  }
}

// ============================================================================
// Computed Creation
// ============================================================================

class PureFlowComputedCreation extends BenchmarkBase {
  PureFlowComputedCreation() : super('PureFlow Computed Creation');

  late pureflow.Signal<int> _source;
  late List<pureflow.Computed<int>> _computeds;

  @override
  void setup() {
    _source = pureflow.Signal(1);
  }

  @override
  void run() {
    _computeds =
        List.generate(1000, (_) => pureflow.Computed(() => _source.value * 2));
  }

  @override
  void teardown() {
    for (final c in _computeds) {
      c.dispose();
    }
    _source.dispose();
  }
}

class SignalsComputedCreation extends BenchmarkBase {
  SignalsComputedCreation() : super('Signals Computed Creation');

  late signals.Signal<int> _source;
  late List<signals.Computed<int>> _computeds;

  @override
  void setup() {
    _source = signals.signal(1);
  }

  @override
  void run() {
    _computeds =
        List.generate(1000, (_) => signals.computed(() => _source.value * 2));
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
// Computed Reads (Cached)
// ============================================================================

class PureFlowComputedReads extends BenchmarkBase {
  PureFlowComputedReads() : super('PureFlow Computed Reads');

  late pureflow.Signal<int> _signal;
  late pureflow.Computed<int> _computed;

  @override
  void setup() {
    _signal = pureflow.Signal(10);
    _computed = pureflow.Computed(() => _signal.value * 2);
  }

  @override
  void run() {
    var sum = 0;
    for (var i = 0; i < 10000; i++) {
      sum += _computed.value;
    }
    if (sum == 0) throw StateError('Optimization prevention');
  }

  @override
  void teardown() {
    _computed.dispose();
    _signal.dispose();
  }
}

class SignalsComputedReads extends BenchmarkBase {
  SignalsComputedReads() : super('Signals Computed Reads');

  late signals.Signal<int> _signal;
  late signals.Computed<int> _computed;

  @override
  void setup() {
    _signal = signals.signal(10);
    _computed = signals.computed(() => _signal.value * 2);
  }

  @override
  void run() {
    var sum = 0;
    for (var i = 0; i < 10000; i++) {
      sum += _computed.value;
    }
    if (sum == 0) throw StateError('Optimization prevention');
  }

  @override
  void teardown() {
    _computed.dispose();
    _signal.dispose();
  }
}

// ============================================================================
// Computed Chain (5 deep)
// ============================================================================

class PureFlowComputedChain extends BenchmarkBase {
  PureFlowComputedChain() : super('PureFlow Computed Chain');

  late pureflow.Signal<int> _source;
  late pureflow.Computed<int> _c1;
  late pureflow.Computed<int> _c2;
  late pureflow.Computed<int> _c3;
  late pureflow.Computed<int> _c4;
  late pureflow.Computed<int> _c5;

  @override
  void setup() {
    _source = pureflow.Signal(1);
    _c1 = pureflow.Computed(() => _source.value + 1);
    _c2 = pureflow.Computed(() => _c1.value + 1);
    _c3 = pureflow.Computed(() => _c2.value + 1);
    _c4 = pureflow.Computed(() => _c3.value + 1);
    _c5 = pureflow.Computed(() => _c4.value + 1);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      _source.value = i;
      final _ = _c5.value;
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

class SignalsComputedChain extends BenchmarkBase {
  SignalsComputedChain() : super('Signals Computed Chain');

  late signals.Signal<int> _source;
  late signals.Computed<int> _c1;
  late signals.Computed<int> _c2;
  late signals.Computed<int> _c3;
  late signals.Computed<int> _c4;
  late signals.Computed<int> _c5;

  @override
  void setup() {
    _source = signals.signal(1);
    _c1 = signals.computed(() => _source.value + 1);
    _c2 = signals.computed(() => _c1.value + 1);
    _c3 = signals.computed(() => _c2.value + 1);
    _c4 = signals.computed(() => _c3.value + 1);
    _c5 = signals.computed(() => _c4.value + 1);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      _source.value = i;
      final _ = _c5.value;
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
// Batch Updates
// ============================================================================

class PureFlowBatch extends BenchmarkBase {
  PureFlowBatch() : super('PureFlow Batch');

  late List<pureflow.Signal<int>> _signals;
  late pureflow.Computed<int> _sum;

  @override
  void setup() {
    _signals = List.generate(10, pureflow.Signal.new);
    _sum = pureflow.Computed(() {
      var total = 0;
      for (final s in _signals) {
        total += s.value;
      }
      return total;
    });
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      pureflow.Signal.batch(() {
        for (var j = 0; j < 10; j++) {
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

class SignalsBatch extends BenchmarkBase {
  SignalsBatch() : super('Signals Batch');

  late List<signals.Signal<int>> _signals;
  late signals.Computed<int> _sum;

  @override
  void setup() {
    _signals = List.generate(10, signals.signal);
    _sum = signals.computed(() {
      var total = 0;
      for (final s in _signals) {
        total += s.value;
      }
      return total;
    });
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      signals.batch(() {
        for (var j = 0; j < 10; j++) {
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
// Diamond Dependency
// ============================================================================

class PureFlowDiamond extends BenchmarkBase {
  PureFlowDiamond() : super('PureFlow Diamond');

  late pureflow.Signal<int> _source;
  late pureflow.Computed<int> _left;
  late pureflow.Computed<int> _right;
  late pureflow.Computed<int> _bottom;

  @override
  void setup() {
    _source = pureflow.Signal(1);
    _left = pureflow.Computed(() => _source.value + 1);
    _right = pureflow.Computed(() => _source.value + 2);
    _bottom = pureflow.Computed(() => _left.value + _right.value);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
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

class SignalsDiamond extends BenchmarkBase {
  SignalsDiamond() : super('Signals Diamond');

  late signals.Signal<int> _source;
  late signals.Computed<int> _left;
  late signals.Computed<int> _right;
  late signals.Computed<int> _bottom;

  @override
  void setup() {
    _source = signals.signal(1);
    _left = signals.computed(() => _source.value + 1);
    _right = signals.computed(() => _source.value + 2);
    _bottom = signals.computed(() => _left.value + _right.value);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
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

// ============================================================================
// Many Dependents
// ============================================================================

class PureFlowManyDependents extends BenchmarkBase {
  PureFlowManyDependents() : super('PureFlow Many Dependents');

  late pureflow.Signal<int> _source;
  late List<pureflow.Computed<int>> _computeds;

  @override
  void setup() {
    _source = pureflow.Signal(0);
    _computeds =
        List.generate(100, (i) => pureflow.Computed(() => _source.value + i));
  }

  @override
  void run() {
    for (var i = 0; i < 100; i++) {
      _source.value = i;
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

class SignalsManyDependents extends BenchmarkBase {
  SignalsManyDependents() : super('Signals Many Dependents');

  late signals.Signal<int> _source;
  late List<signals.Computed<int>> _computeds;

  @override
  void setup() {
    _source = signals.signal(0);
    _computeds =
        List.generate(100, (i) => signals.computed(() => _source.value + i));
  }

  @override
  void run() {
    for (var i = 0; i < 100; i++) {
      _source.value = i;
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
