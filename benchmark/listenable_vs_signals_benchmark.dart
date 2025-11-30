import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:pureflow/src/value_unit/value_unit.dart' as pureflow;
import 'package:signals_core/signals_core.dart' as signals;
import 'value_notifier/listenable.dart' as listenable;

/// Comparison benchmark: Listenable vs PureFlow vs signals_core
void main() {
  print('Listenable vs PureFlow vs signals_core - Performance Comparison');
  print('Using benchmark_harness (10 iterations, 2s warmup)\n');
  print('=' * 120);

  _runComparison(
    'Creation (1000x)',
    ListenableCreation(),
    PureFlowCreation(),
    SignalsCreation(),
  );
  _runComparison(
    'Reads (10000x)',
    ListenableReads(),
    PureFlowReads(),
    SignalsReads(),
  );
  _runComparison(
    'Writes (1000x)',
    ListenableWrites(),
    PureFlowWrites(),
    SignalsWrites(),
  );
  _runComparison(
    'Writes + 1 listener',
    ListenableWritesWithListener(),
    PureFlowWritesWithListener(),
    SignalsWritesWithListener(),
  );
  _runComparison(
    'Writes + 10 listeners',
    ListenableWritesWith10Listeners(),
    PureFlowWritesWith10Listeners(),
    SignalsWritesWith10Listeners(),
  );
  _runComparison(
    'Computed reads (cached)',
    ListenableComputedReads(),
    PureFlowComputedReads(),
    SignalsComputedReads(),
  );
  _runComparison(
    'Computed chain (5 deep)',
    ListenableComputedChain(),
    PureFlowComputedChain(),
    SignalsComputedChain(),
  );
  _runComparison(
    'Diamond dependency',
    ListenableDiamond(),
    PureFlowDiamond(),
    SignalsDiamond(),
  );
  _runComparison(
    'Many listeners (100)',
    ListenableManyListeners(),
    PureFlowManyListeners(),
    SignalsManyListeners(),
  );

  print('=' * 120);
  print('\nLower μs/op is better. Benchmark complete.');
}

void _runComparison(
  String name,
  BenchmarkBase listenableBench,
  BenchmarkBase pureflowBench,
  BenchmarkBase signalsBench,
) {
  final listenableUs = listenableBench.measure();
  final pureflowUs = pureflowBench.measure();
  final signalsUs = signalsBench.measure();

  // Find the winner
  final times = {
    'Listenable': listenableUs,
    'PureFlow': pureflowUs,
    'signals': signalsUs
  };
  final sorted = times.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  final winner = sorted.first.key;
  final slowest = sorted.last.value;
  final diff = slowest / sorted.first.value;

  print(
    '${name.padRight(22)} '
    'Listenable: ${listenableUs.toStringAsFixed(1).padLeft(8)} μs  '
    'PureFlow: ${pureflowUs.toStringAsFixed(1).padLeft(8)} μs  '
    'signals: ${signalsUs.toStringAsFixed(1).padLeft(8)} μs  '
    '[$winner wins, ${diff.toStringAsFixed(1)}x vs slowest]',
  );
}

// ============================================================================
// Creation Benchmarks
// ============================================================================

class ListenableCreation extends BenchmarkBase {
  ListenableCreation() : super('Listenable Creation');

  late List<listenable.ValueNotifier<int>> _signals;

  @override
  void run() {
    _signals = List.generate(1000, listenable.ValueNotifier<int>.new);
  }

  @override
  void teardown() {
    for (final s in _signals) {
      s.dispose();
    }
  }
}

class PureFlowCreation extends BenchmarkBase {
  PureFlowCreation() : super('PureFlow Creation');

  late List<pureflow.ValueUnit<int>> _signals;

  @override
  void run() {
    _signals = List.generate(1000, pureflow.ValueUnit<int>.new);
  }

  @override
  void teardown() {
    for (final s in _signals) {
      s.dispose();
    }
  }
}

class SignalsCreation extends BenchmarkBase {
  SignalsCreation() : super('signals Creation');

  late List<signals.Signal<int>> _signals;

  @override
  void run() {
    _signals = List.generate(1000, signals.signal<int>);
  }

  @override
  void teardown() {
    for (final s in _signals) {
      s.dispose();
    }
  }
}

// ============================================================================
// Read Benchmarks
// ============================================================================

class ListenableReads extends BenchmarkBase {
  ListenableReads() : super('Listenable Reads');

  late listenable.ValueNotifier<int> _signal;

  @override
  void setup() {
    _signal = listenable.ValueNotifier(42);
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

class PureFlowReads extends BenchmarkBase {
  PureFlowReads() : super('PureFlow Reads');

  late pureflow.ValueUnit<int> _signal;

  @override
  void setup() {
    _signal = pureflow.ValueUnit(42);
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

class SignalsReads extends BenchmarkBase {
  SignalsReads() : super('signals Reads');

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
// Write Benchmarks
// ============================================================================

class ListenableWrites extends BenchmarkBase {
  ListenableWrites() : super('Listenable Writes');

  late listenable.ValueNotifier<int> _signal;

  @override
  void setup() {
    _signal = listenable.ValueNotifier(0);
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

class PureFlowWrites extends BenchmarkBase {
  PureFlowWrites() : super('PureFlow Writes');

  late pureflow.ValueUnit<int> _signal;

  @override
  void setup() {
    _signal = pureflow.ValueUnit(0);
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

class SignalsWrites extends BenchmarkBase {
  SignalsWrites() : super('signals Writes');

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
// Write with Listener Benchmarks
// ============================================================================

class ListenableWritesWithListener extends BenchmarkBase {
  ListenableWritesWithListener() : super('Listenable Writes + Listener');

  late listenable.ValueNotifier<int> _signal;
  late listenable.ValueNotifier<int> _derived;
  late void Function() _listener;

  @override
  void setup() {
    _signal = listenable.ValueNotifier(0);
    _derived = listenable.ValueNotifier(0);
    _listener = () => _derived.value = _signal.value * 2;
    _signal.addListener(_listener);
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      _signal.value = i;
      final _ = _derived.value;
    }
  }

  @override
  void teardown() {
    _signal.removeListener(_listener);
    _derived.dispose();
    _signal.dispose();
  }
}

class PureFlowWritesWithListener extends BenchmarkBase {
  PureFlowWritesWithListener() : super('PureFlow Writes + Listener');

  late pureflow.ValueUnit<int> _signal;
  late pureflow.CompositeUnit<int> _computed;

  @override
  void setup() {
    _signal = pureflow.ValueUnit(0);
    _computed = pureflow.CompositeUnit(() => _signal.value * 2);
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

class SignalsWritesWithListener extends BenchmarkBase {
  SignalsWritesWithListener() : super('signals Writes + Listener');

  late signals.Signal<int> _signal;
  late signals.Computed<int> _computed;

  @override
  void setup() {
    _signal = signals.signal(0);
    _computed = signals.computed(() => _signal.value * 2);
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

// ============================================================================
// Write with 10 Listeners Benchmarks
// ============================================================================

class ListenableWritesWith10Listeners extends BenchmarkBase {
  ListenableWritesWith10Listeners() : super('Listenable 10 Listeners');

  late listenable.ValueNotifier<int> _signal;
  late List<listenable.ValueNotifier<int>> _derived;
  late List<void Function()> _listeners;

  @override
  void setup() {
    _signal = listenable.ValueNotifier(0);
    _derived = List.generate(10, (_) => listenable.ValueNotifier<int>(0));
    _listeners = List.generate(
      10,
      (i) => () => _derived[i].value = _signal.value * (i + 1),
    );
    for (final listener in _listeners) {
      _signal.addListener(listener);
    }
  }

  @override
  void run() {
    for (var i = 0; i < 1000; i++) {
      _signal.value = i;
      for (final d in _derived) {
        final _ = d.value;
      }
    }
  }

  @override
  void teardown() {
    for (final listener in _listeners) {
      _signal.removeListener(listener);
    }
    for (final d in _derived) {
      d.dispose();
    }
    _signal.dispose();
  }
}

class PureFlowWritesWith10Listeners extends BenchmarkBase {
  PureFlowWritesWith10Listeners() : super('PureFlow 10 Listeners');

  late pureflow.ValueUnit<int> _signal;
  late List<pureflow.CompositeUnit<int>> _computeds;

  @override
  void setup() {
    _signal = pureflow.ValueUnit(0);
    _computeds = List.generate(
      10,
      (i) => pureflow.CompositeUnit(() => _signal.value * (i + 1)),
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

class SignalsWritesWith10Listeners extends BenchmarkBase {
  SignalsWritesWith10Listeners() : super('signals 10 Listeners');

  late signals.Signal<int> _signal;
  late List<signals.Computed<int>> _computeds;

  @override
  void setup() {
    _signal = signals.signal(0);
    _computeds = List.generate(
      10,
      (i) => signals.computed(() => _signal.value * (i + 1)),
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

// ============================================================================
// Computed Reads (Cached) Benchmarks
// ============================================================================

class ListenableComputedReads extends BenchmarkBase {
  ListenableComputedReads() : super('Listenable Computed Reads');

  late listenable.ValueNotifier<int> _signal;
  late listenable.ValueNotifier<int> _derived;
  late void Function() _listener;

  @override
  void setup() {
    _signal = listenable.ValueNotifier(10);
    _derived = listenable.ValueNotifier(_signal.value * 2);
    _listener = () => _derived.value = _signal.value * 2;
    _signal.addListener(_listener);
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
    _signal.removeListener(_listener);
    _derived.dispose();
    _signal.dispose();
  }
}

class PureFlowComputedReads extends BenchmarkBase {
  PureFlowComputedReads() : super('PureFlow Computed Reads');

  late pureflow.ValueUnit<int> _signal;
  late pureflow.CompositeUnit<int> _computed;

  @override
  void setup() {
    _signal = pureflow.ValueUnit(10);
    _computed = pureflow.CompositeUnit(() => _signal.value * 2);
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

class SignalsComputedReads extends BenchmarkBase {
  SignalsComputedReads() : super('signals Computed Reads');

  late signals.Signal<int> _signal;
  late signals.Computed<int> _computed;

  @override
  void setup() {
    _signal = signals.signal(10);
    _computed = signals.computed(() => _signal.value * 2);
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

// ============================================================================
// Computed Chain (5 deep) Benchmarks
// ============================================================================

class ListenableComputedChain extends BenchmarkBase {
  ListenableComputedChain() : super('Listenable Computed Chain');

  late listenable.ValueNotifier<int> _source;
  late listenable.ValueNotifier<int> _n1;
  late listenable.ValueNotifier<int> _n2;
  late listenable.ValueNotifier<int> _n3;
  late listenable.ValueNotifier<int> _n4;
  late listenable.ValueNotifier<int> _n5;
  late List<void Function()> _listeners;

  @override
  void setup() {
    _source = listenable.ValueNotifier(1);
    _n1 = listenable.ValueNotifier(_source.value + 1);
    _n2 = listenable.ValueNotifier(_n1.value + 1);
    _n3 = listenable.ValueNotifier(_n2.value + 1);
    _n4 = listenable.ValueNotifier(_n3.value + 1);
    _n5 = listenable.ValueNotifier(_n4.value + 1);

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

class PureFlowComputedChain extends BenchmarkBase {
  PureFlowComputedChain() : super('PureFlow Computed Chain');

  late pureflow.ValueUnit<int> _source;
  late pureflow.CompositeUnit<int> _c1;
  late pureflow.CompositeUnit<int> _c2;
  late pureflow.CompositeUnit<int> _c3;
  late pureflow.CompositeUnit<int> _c4;
  late pureflow.CompositeUnit<int> _c5;

  @override
  void setup() {
    _source = pureflow.ValueUnit(1);
    _c1 = pureflow.CompositeUnit(() => _source.value + 1);
    _c2 = pureflow.CompositeUnit(() => _c1.value + 1);
    _c3 = pureflow.CompositeUnit(() => _c2.value + 1);
    _c4 = pureflow.CompositeUnit(() => _c3.value + 1);
    _c5 = pureflow.CompositeUnit(() => _c4.value + 1);
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
  SignalsComputedChain() : super('signals Computed Chain');

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
// Diamond Dependency Benchmarks
// ============================================================================

class ListenableDiamond extends BenchmarkBase {
  ListenableDiamond() : super('Listenable Diamond');

  late listenable.ValueNotifier<int> _source;
  late listenable.ValueNotifier<int> _left;
  late listenable.ValueNotifier<int> _right;
  late listenable.ValueNotifier<int> _bottom;
  late List<void Function()> _listeners;

  @override
  void setup() {
    //     source
    //    /      \
    //  left    right
    //    \      /
    //     bottom
    _source = listenable.ValueNotifier(1);
    _left = listenable.ValueNotifier(_source.value + 1);
    _right = listenable.ValueNotifier(_source.value + 2);
    _bottom = listenable.ValueNotifier(_left.value + _right.value);

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

class PureFlowDiamond extends BenchmarkBase {
  PureFlowDiamond() : super('PureFlow Diamond');

  late pureflow.ValueUnit<int> _source;
  late pureflow.CompositeUnit<int> _left;
  late pureflow.CompositeUnit<int> _right;
  late pureflow.CompositeUnit<int> _bottom;

  @override
  void setup() {
    //     source
    //    /      \
    //  left    right
    //    \      /
    //     bottom
    _source = pureflow.ValueUnit(1);
    _left = pureflow.CompositeUnit(() => _source.value + 1);
    _right = pureflow.CompositeUnit(() => _source.value + 2);
    _bottom = pureflow.CompositeUnit(() => _left.value + _right.value);
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
  SignalsDiamond() : super('signals Diamond');

  late signals.Signal<int> _source;
  late signals.Computed<int> _left;
  late signals.Computed<int> _right;
  late signals.Computed<int> _bottom;

  @override
  void setup() {
    //     source
    //    /      \
    //  left    right
    //    \      /
    //     bottom
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
// Many Listeners Benchmarks
// ============================================================================

class ListenableManyListeners extends BenchmarkBase {
  ListenableManyListeners() : super('Listenable Many Listeners');

  late listenable.ValueNotifier<int> _source;
  late List<listenable.ValueNotifier<int>> _derived;
  late List<void Function()> _listeners;

  @override
  void setup() {
    _source = listenable.ValueNotifier(0);
    _derived = List.generate(100, listenable.ValueNotifier<int>.new);
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
    for (final d in _derived) {
      d.dispose();
    }
    _source.dispose();
  }
}

class PureFlowManyListeners extends BenchmarkBase {
  PureFlowManyListeners() : super('PureFlow Many Listeners');

  late pureflow.ValueUnit<int> _source;
  late List<pureflow.CompositeUnit<int>> _computeds;

  @override
  void setup() {
    _source = pureflow.ValueUnit(0);
    _computeds = List.generate(
      100,
      (i) => pureflow.CompositeUnit(() => _source.value + i),
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

class SignalsManyListeners extends BenchmarkBase {
  SignalsManyListeners() : super('signals Many Listeners');

  late signals.Signal<int> _source;
  late List<signals.Computed<int>> _computeds;

  @override
  void setup() {
    _source = signals.signal(0);
    _computeds = List.generate(
      100,
      (i) => signals.computed(() => _source.value + i),
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
