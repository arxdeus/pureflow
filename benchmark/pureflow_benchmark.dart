import 'package:pureflow/pureflow.dart';

/// Benchmark suite for PureFlow reactive primitives.
void main() {
  print('PureFlow - Performance Benchmark\n');
  print('=' * 60);

  _benchmarkSignalCreation();
  _benchmarkSignalReads();
  _benchmarkSignalWrites();
  _benchmarkComputedCreation();
  _benchmarkComputedReads();
  _benchmarkComputedChain();
  _benchmarkBatchUpdates();
  _benchmarkDiamondDependency();
  _benchmarkManyDependents();
  _benchmarkMemoryEfficiency();

  print('=' * 60);
  print('Benchmark complete.\n');
}

// ============================================================================
// Signal Benchmarks
// ============================================================================

void _benchmarkSignalCreation() {
  const iterations = 100000;

  final sw = Stopwatch()..start();
  final signals = <Signal<int>>[];

  for (var i = 0; i < iterations; i++) {
    signals.add(Signal(i));
  }

  sw.stop();
  _printResult('Signal creation', iterations, sw.elapsedMicroseconds);

  // Cleanup
  for (final s in signals) {
    s.dispose();
  }
}

void _benchmarkSignalReads() {
  const iterations = 1000000;
  final signal = Signal(42);
  var sum = 0;

  final sw = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    sum += signal.value;
  }

  sw.stop();
  _printResult('Signal reads', iterations, sw.elapsedMicroseconds);

  // Prevent optimization
  if (sum == 0) print('');
  signal.dispose();
}

void _benchmarkSignalWrites() {
  const iterations = 100000;
  final signal = Signal(0);

  final sw = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    signal.value = i;
  }

  sw.stop();
  _printResult('Signal writes', iterations, sw.elapsedMicroseconds);

  signal.dispose();
}

// ============================================================================
// Computed Benchmarks
// ============================================================================

void _benchmarkComputedCreation() {
  const iterations = 10000;
  final source = Signal(1);

  final sw = Stopwatch()..start();
  final computeds = <Computed<int>>[];

  for (var i = 0; i < iterations; i++) {
    computeds.add(Computed(() => source.value * 2));
  }

  sw.stop();
  _printResult('Computed creation', iterations, sw.elapsedMicroseconds);

  // Cleanup
  for (final c in computeds) {
    c.dispose();
  }
  source.dispose();
}

void _benchmarkComputedReads() {
  const iterations = 100000;
  final signal = Signal(10);
  final computed = Computed(() => signal.value * 2);
  var sum = 0;

  final sw = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    sum += computed.value;
  }

  sw.stop();
  _printResult('Computed reads (cached)', iterations, sw.elapsedMicroseconds);

  // Prevent optimization
  if (sum == 0) print('');
  computed.dispose();
  signal.dispose();
}

void _benchmarkComputedChain() {
  const iterations = 10000;
  final source = Signal(1);

  // Create chain: source -> c1 -> c2 -> c3 -> c4 -> c5
  final c1 = Computed(() => source.value + 1);
  final c2 = Computed(() => c1.value + 1);
  final c3 = Computed(() => c2.value + 1);
  final c4 = Computed(() => c3.value + 1);
  final c5 = Computed(() => c4.value + 1);

  final sw = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    source.value = i;
    final _ = c5.value; // Force recomputation through chain
  }

  sw.stop();
  _printResult('Computed chain (5 deep)', iterations, sw.elapsedMicroseconds);

  c5.dispose();
  c4.dispose();
  c3.dispose();
  c2.dispose();
  c1.dispose();
  source.dispose();
}

// ============================================================================
// Batch Benchmarks
// ============================================================================

void _benchmarkBatchUpdates() {
  const iterations = 10000;
  const signalCount = 10;

  final signals = List.generate(signalCount, Signal.new);
  final sum = Computed(() {
    var total = 0;
    for (final s in signals) {
      total += s.value;
    }
    return total;
  });

  final sw = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    Signal.batch(() {
      for (var j = 0; j < signalCount; j++) {
        signals[j].value = i + j;
      }
    });
    final _ = sum.value;
  }

  sw.stop();
  _printResult(
    'Batch updates (10 signals)',
    iterations,
    sw.elapsedMicroseconds,
  );

  sum.dispose();
  for (final s in signals) {
    s.dispose();
  }
}

// ============================================================================
// Complex Dependency Benchmarks
// ============================================================================

void _benchmarkDiamondDependency() {
  const iterations = 10000;

  //     source
  //    /      \
  //  left    right
  //    \      /
  //     bottom

  final source = Signal(1);
  final left = Computed(() => source.value + 1);
  final right = Computed(() => source.value + 2);
  final bottom = Computed(() => left.value + right.value);

  final sw = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    source.value = i;
    final _ = bottom.value;
  }

  sw.stop();
  _printResult('Diamond dependency', iterations, sw.elapsedMicroseconds);

  bottom.dispose();
  right.dispose();
  left.dispose();
  source.dispose();
}

void _benchmarkManyDependents() {
  const iterations = 1000;
  const dependentCount = 100;

  final source = Signal(0);
  final computeds = List.generate(
    dependentCount,
    (i) => Computed(() => source.value + i),
  );

  final sw = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    source.value = i;
    // Read all to trigger recomputation
    for (final c in computeds) {
      final _ = c.value;
    }
  }

  sw.stop();
  _printResult('Many dependents (100)', iterations, sw.elapsedMicroseconds);

  for (final c in computeds) {
    c.dispose();
  }
  source.dispose();
}

// ============================================================================
// Memory Efficiency
// ============================================================================

void _benchmarkMemoryEfficiency() {
  const count = 10000;

  // Measure signals without dependents (should use minimal memory)
  final signals = <Signal<int>>[];

  final sw = Stopwatch()..start();

  for (var i = 0; i < count; i++) {
    signals.add(Signal(i));
  }

  // Read values without computed context (no dependency tracking)
  var sum = 0;
  for (final s in signals) {
    sum += s.value;
  }

  sw.stop();
  _printResult('Signals w/o deps (memory test)', count, sw.elapsedMicroseconds);

  // Prevent optimization
  if (sum == 0) print('');

  for (final s in signals) {
    s.dispose();
  }
}

// ============================================================================
// Helpers
// ============================================================================

void _printResult(String name, int iterations, int microseconds) {
  final ms = microseconds / 1000;
  final opsPerSec = (iterations / microseconds * 1000000).round();
  final nsPerOp = (microseconds * 1000 / iterations).toStringAsFixed(1);

  print(
    '${name.padRight(30)} ${iterations.toString().padLeft(8)} ops  '
    '${ms.toStringAsFixed(2).padLeft(8)} ms  '
    '${nsPerOp.padLeft(6)} ns/op  '
    '${_formatNumber(opsPerSec).padLeft(10)} ops/s',
  );
}

String _formatNumber(int n) {
  if (n >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(1)}M';
  } else if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(1)}K';
  }
  return n.toString();
}
