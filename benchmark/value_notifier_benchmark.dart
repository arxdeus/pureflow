import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:pureflow/pureflow.dart' as pureflow;
import 'value_notifier/listenable.dart';

/// Comparison benchmark: Pureflow Signal/Computed vs ValueNotifier
void main() {
  print('Pureflow vs ValueNotifier - Performance Comparison');
  print('Using benchmark_harness (10 iterations, 2s warmup)\n');
  print('=' * 90);

  _runComparison(
    'Creation (1000x)',
    PureFlowSignalCreation(),
    ValueNotifierCreation(),
  );
  _runComparison(
    'Reads (10000x)',
    PureFlowSignalReads(),
    ValueNotifierReads(),
  );
  _runComparison(
    'Writes (1000x)',
    PureFlowSignalWrites(),
    ValueNotifierWrites(),
  );
  _runComparison(
    'Writes + 1 listener',
    PureFlowSignalWritesWithListener(),
    ValueNotifierWritesWithListener(),
  );
  _runComparison(
    'Writes + 10 listeners',
    PureFlowSignalWritesWith10Listeners(),
    ValueNotifierWritesWith10Listeners(),
  );
  _runComparison(
    'Computed reads (cached)',
    PureFlowComputedReads(),
    ValueNotifierComputedReads(),
  );
  _runComparison(
    'Computed chain (5 deep)',
    PureFlowComputedChain(),
    ValueNotifierComputedChain(),
  );
  _runComparison(
    'Diamond dependency',
    PureFlowDiamond(),
    ValueNotifierDiamond(),
  );
  _runComparison(
    'Many listeners (100)',
    PureFlowManyListeners(),
    ValueNotifierManyListeners(),
  );

  print('=' * 90);
  print('\nLower μs/op is better. Benchmark complete.');
}

void _runComparison(
  String name,
  BenchmarkBase pureflowBench,
  BenchmarkBase valueNotifier,
) {
  final pureUs = pureflowBench.measure();
  final vnUs = valueNotifier.measure();

  final ratio = vnUs / pureUs;
  final winner = ratio > 1 ? 'Pureflow' : 'ValueNotifier';
  final diff = ratio > 1 ? ratio : 1 / ratio;

  print(
    '${name.padRight(25)} '
    'Pureflow: ${pureUs.toStringAsFixed(2).padLeft(10)} μs  '
    'ValueNotifier: ${vnUs.toStringAsFixed(2).padLeft(10)} μs  '
    '[$winner ${diff.toStringAsFixed(1)}x faster]',
  );
}

// ============================================================================
// Creation Benchmarks
// ============================================================================

class PureFlowSignalCreation extends BenchmarkBase {
  PureFlowSignalCreation() : super('Pureflow Signal Creation');

  late List<pureflow.Store<int>> _signals;

  @override
  void run() {
    _signals = List.generate(1000, pureflow.Store.new);
  }

  @override
  void teardown() {
    for (final s in _signals) {
      s.dispose();
    }
  }
}

class ValueNotifierCreation extends BenchmarkBase {
  ValueNotifierCreation() : super('ValueNotifier Creation');

  late List<ValueNotifier<int>> _notifiers;

  @override
  void run() {
    _notifiers = List.generate(1000, ValueNotifier.new);
  }

  @override
  void teardown() {
    for (final n in _notifiers) {
      n.dispose();
    }
  }
}

// ============================================================================
// Read Benchmarks
// ============================================================================

class PureFlowSignalReads extends BenchmarkBase {
  PureFlowSignalReads() : super('Pureflow Signal Reads');

  late pureflow.Store<int> _signal;

  @override
  void setup() {
    _signal = pureflow.Store(42);
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

class ValueNotifierReads extends BenchmarkBase {
  ValueNotifierReads() : super('ValueNotifier Reads');

  late ValueNotifier<int> _notifier;

  @override
  void setup() {
    _notifier = ValueNotifier(42);
  }

  @override
  void run() {
    var sum = 0;
    for (var i = 0; i < 10000; i++) {
      sum += _notifier.value;
    }
    if (sum == 0) throw StateError('Optimization prevention');
  }

  @override
  void teardown() {
    _notifier.dispose();
  }
}

// ============================================================================
// Write Benchmarks
// ============================================================================

class PureFlowSignalWrites extends BenchmarkBase {
  PureFlowSignalWrites() : super('Pureflow Signal Writes');

  late pureflow.Store<int> _signal;

  @override
  void setup() {
    _signal = pureflow.Store(0);
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

class ValueNotifierWrites extends BenchmarkBase {
  ValueNotifierWrites() : super('ValueNotifier Writes');

  late ValueNotifier<int> _notifier;

  @override
  void setup() {
    _notifier = ValueNotifier(0);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      _notifier.value = i;
    }
  }

  @override
  void teardown() {
    _notifier.dispose();
  }
}

// ============================================================================
// Write with Listener Benchmarks
// ============================================================================

class PureFlowSignalWritesWithListener extends BenchmarkBase {
  PureFlowSignalWritesWithListener()
      : super('Pureflow Signal Writes + Listener');

  late pureflow.Store<int> _signal;
  late pureflow.Computed<int> _computed;

  @override
  void setup() {
    _signal = pureflow.Store(0);
    _computed = pureflow.Computed(() => _signal.value * 2);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      _signal.value = i;
      final _ = _computed.value;
    }
  }

  @override
  void teardown() {
    _computed.dispose();
    _signal.dispose();
  }
}

class ValueNotifierWritesWithListener extends BenchmarkBase {
  ValueNotifierWritesWithListener() : super('ValueNotifier Writes + Listener');

  late ValueNotifier<int> _source;
  late ValueNotifier<int> _derived;
  late void Function() _listener;

  @override
  void setup() {
    _source = ValueNotifier(0);
    _derived = ValueNotifier(0);
    _listener = () => _derived.value = _source.value * 2;
    _source.addListener(_listener);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      _source.value = i;
      final _ = _derived.value;
    }
  }

  @override
  void teardown() {
    _source.removeListener(_listener);
    _source.dispose();
    _derived.dispose();
  }
}

// ============================================================================
// Write with 10 Listeners Benchmarks
// ============================================================================

class PureFlowSignalWritesWith10Listeners extends BenchmarkBase {
  PureFlowSignalWritesWith10Listeners() : super('Pureflow 10 Listeners');

  late pureflow.Store<int> _signal;
  late List<pureflow.Computed<int>> _computeds;

  @override
  void setup() {
    _signal = pureflow.Store(0);
    _computeds = List.generate(
      10,
      (i) => pureflow.Computed(() => _signal.value * (i + 1)),
    );
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      _signal.value = i;
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
    _signal.dispose();
  }
}

class ValueNotifierWritesWith10Listeners extends BenchmarkBase {
  ValueNotifierWritesWith10Listeners() : super('ValueNotifier 10 Listeners');

  late ValueNotifier<int> _source;
  late List<ValueNotifier<int>> _derived;
  late List<void Function()> _listeners;

  @override
  void setup() {
    _source = ValueNotifier(0);
    _derived = List.generate(10, (_) => ValueNotifier<int>(0));
    _listeners = List.generate(
      10,
      (i) => () => _derived[i].value = _source.value * (i + 1),
    );
    for (final listener in _listeners) {
      _source.addListener(listener);
    }
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      _source.value = i;
      for (final d in _derived) {
        final _ = d.value;
      }
    }
  }

  @override
  void teardown() {
    for (final listener in _listeners) {
      _source.removeListener(listener);
    }
    _source.dispose();
    for (final d in _derived) {
      d.dispose();
    }
  }
}

// ============================================================================
// Computed Reads (Cached) Benchmarks
// ============================================================================

class PureFlowComputedReads extends BenchmarkBase {
  PureFlowComputedReads() : super('Pureflow Computed Reads');

  late pureflow.Store<int> _signal;
  late pureflow.Computed<int> _computed;

  @override
  void setup() {
    _signal = pureflow.Store(10);
    _computed = pureflow.Computed(() => _signal.value * 2);
    // Warm up to cache the value
    final _ = _computed.value;
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

class ValueNotifierComputedReads extends BenchmarkBase {
  ValueNotifierComputedReads() : super('ValueNotifier Computed Reads');

  late ValueNotifier<int> _source;
  late ValueNotifier<int> _derived;
  late void Function() _listener;

  @override
  void setup() {
    _source = ValueNotifier(10);
    _derived = ValueNotifier(_source.value * 2);
    _listener = () => _derived.value = _source.value * 2;
    _source.addListener(_listener);
  }

  @override
  void run() {
    var sum = 0;
    for (var i = 0; i < 10000; i++) {
      sum += _derived.value;
    }
    if (sum == 0) throw StateError('Optimization prevention');
  }

  @override
  void teardown() {
    _source.removeListener(_listener);
    _source.dispose();
    _derived.dispose();
  }
}

// ============================================================================
// Computed Chain (5 deep) Benchmarks
// ============================================================================

class PureFlowComputedChain extends BenchmarkBase {
  PureFlowComputedChain() : super('Pureflow Computed Chain');

  late pureflow.Store<int> _source;
  late pureflow.Computed<int> _c1;
  late pureflow.Computed<int> _c2;
  late pureflow.Computed<int> _c3;
  late pureflow.Computed<int> _c4;
  late pureflow.Computed<int> _c5;

  @override
  void setup() {
    _source = pureflow.Store(1);
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

class ValueNotifierComputedChain extends BenchmarkBase {
  ValueNotifierComputedChain() : super('ValueNotifier Computed Chain');

  late ValueNotifier<int> _source;
  late ValueNotifier<int> _n1;
  late ValueNotifier<int> _n2;
  late ValueNotifier<int> _n3;
  late ValueNotifier<int> _n4;
  late ValueNotifier<int> _n5;
  late List<void Function()> _listeners;

  @override
  void setup() {
    _source = ValueNotifier(1);
    _n1 = ValueNotifier(_source.value + 1);
    _n2 = ValueNotifier(_n1.value + 1);
    _n3 = ValueNotifier(_n2.value + 1);
    _n4 = ValueNotifier(_n3.value + 1);
    _n5 = ValueNotifier(_n4.value + 1);

    _listeners = [
      () => _n1.value = _source.value + 1,
      () => _n2.value = _n1.value + 1,
      () => _n3.value = _n2.value + 1,
      () => _n4.value = _n3.value + 1,
      () => _n5.value = _n4.value + 1,
    ];

    _source.addListener(_listeners[0]);
    _n1.addListener(_listeners[1]);
    _n2.addListener(_listeners[2]);
    _n3.addListener(_listeners[3]);
    _n4.addListener(_listeners[4]);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      _source.value = i;
      final _ = _n5.value;
    }
  }

  @override
  void teardown() {
    _source.removeListener(_listeners[0]);
    _n1.removeListener(_listeners[1]);
    _n2.removeListener(_listeners[2]);
    _n3.removeListener(_listeners[3]);
    _n4.removeListener(_listeners[4]);

    _source.dispose();
    _n1.dispose();
    _n2.dispose();
    _n3.dispose();
    _n4.dispose();
    _n5.dispose();
  }
}

// ============================================================================
// Diamond Dependency Benchmarks
// ============================================================================

class PureFlowDiamond extends BenchmarkBase {
  PureFlowDiamond() : super('Pureflow Diamond');

  late pureflow.Store<int> _source;
  late pureflow.Computed<int> _left;
  late pureflow.Computed<int> _right;
  late pureflow.Computed<int> _bottom;

  @override
  void setup() {
    //     source
    //    /      \
    //  left    right
    //    \      /
    //     bottom
    _source = pureflow.Store(1);
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

class ValueNotifierDiamond extends BenchmarkBase {
  ValueNotifierDiamond() : super('ValueNotifier Diamond');

  late ValueNotifier<int> _source;
  late ValueNotifier<int> _left;
  late ValueNotifier<int> _right;
  late ValueNotifier<int> _bottom;
  late List<void Function()> _listeners;

  @override
  void setup() {
    //     source
    //    /      \
    //  left    right
    //    \      /
    //     bottom
    _source = ValueNotifier(1);
    _left = ValueNotifier(_source.value + 1);
    _right = ValueNotifier(_source.value + 2);
    _bottom = ValueNotifier(_left.value + _right.value);

    _listeners = [
      () => _left.value = _source.value + 1,
      () => _right.value = _source.value + 2,
      () => _bottom.value = _left.value + _right.value,
    ];

    _source.addListener(_listeners[0]);
    _source.addListener(_listeners[1]);
    _left.addListener(_listeners[2]);
    _right.addListener(_listeners[2]);
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
    _source.removeListener(_listeners[0]);
    _source.removeListener(_listeners[1]);
    _left.removeListener(_listeners[2]);
    _right.removeListener(_listeners[2]);

    _source.dispose();
    _left.dispose();
    _right.dispose();
    _bottom.dispose();
  }
}

// ============================================================================
// Many Listeners Benchmarks
// ============================================================================

class PureFlowManyListeners extends BenchmarkBase {
  PureFlowManyListeners() : super('Pureflow Many Listeners');

  late pureflow.Store<int> _source;
  late List<pureflow.Computed<int>> _computeds;

  @override
  void setup() {
    _source = pureflow.Store(0);
    _computeds = List.generate(
      100,
      (i) => pureflow.Computed(() => _source.value + i),
    );
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

class ValueNotifierManyListeners extends BenchmarkBase {
  ValueNotifierManyListeners() : super('ValueNotifier Many Listeners');

  late ValueNotifier<int> _source;
  late List<ValueNotifier<int>> _derived;
  late List<void Function()> _listeners;

  @override
  void setup() {
    _source = ValueNotifier(0);
    _derived = List.generate(100, ValueNotifier<int>.new);
    _listeners = List.generate(
      100,
      (i) => () => _derived[i].value = _source.value + i,
    );
    for (final listener in _listeners) {
      _source.addListener(listener);
    }
  }

  @override
  void run() {
    for (var i = 0; i < 100; i++) {
      _source.value = i;
      for (final d in _derived) {
        final _ = d.value;
      }
    }
  }

  @override
  void teardown() {
    for (final listener in _listeners) {
      _source.removeListener(listener);
    }
    _source.dispose();
    for (final d in _derived) {
      d.dispose();
    }
  }
}
