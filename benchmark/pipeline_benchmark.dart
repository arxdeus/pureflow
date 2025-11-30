import 'dart:async';

import '../packages/pureflow/lib/pureflow.dart';

/// Benchmark comparing the new pipeline implementation (custom Stream)
/// vs the old one (async* generator).
void main() async {
  print('Pipeline Performance Benchmark\n');
  print('=' * 60);

  // Warmup
  print('Warming up...');
  await _runPipelineBenchmark(iterations: 100, taskCount: 10);

  print('\nRunning benchmarks...\n');

  // Sequential transformer benchmark
  print('--- Sequential Transformer (asyncExpand) ---');
  await _runSequentialBenchmark();

  print('\n--- Concurrent Transformer (flatMap) ---');
  await _runConcurrentBenchmark();

  print('\n--- Switching Transformer (switchMap) ---');
  await _runSwitchingBenchmark();

  print('\n--- High Throughput (many small tasks) ---');
  await _runHighThroughputBenchmark();

  print('\n${'=' * 60}');
  print('Benchmark complete.\n');
}

Future<void> _runSequentialBenchmark() async {
  final results = <double>[];

  for (var run = 0; run < 5; run++) {
    final elapsed = await _runPipelineBenchmark(
      iterations: 1000,
      taskCount: 100,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    results.add(elapsed);
  }

  _printResults('Sequential (1000 iterations, 100 tasks)', results);
}

Future<void> _runConcurrentBenchmark() async {
  final results = <double>[];

  for (var run = 0; run < 5; run++) {
    final elapsed = await _runPipelineBenchmark(
      iterations: 1000,
      taskCount: 100,
      transformer: _flatMapTransformer,
    );
    results.add(elapsed);
  }

  _printResults('Concurrent (1000 iterations, 100 tasks)', results);
}

Future<void> _runSwitchingBenchmark() async {
  final results = <double>[];

  for (var run = 0; run < 5; run++) {
    final elapsed = await _runPipelineBenchmark(
      iterations: 1000,
      taskCount: 100,
      transformer: _switchMapTransformer,
    );
    results.add(elapsed);
  }

  _printResults('Switching (1000 iterations, 100 tasks)', results);
}

Future<void> _runHighThroughputBenchmark() async {
  final results = <double>[];

  for (var run = 0; run < 5; run++) {
    final elapsed = await _runPipelineBenchmark(
      iterations: 100,
      taskCount: 10000,
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
    results.add(elapsed);
  }

  _printResults('High Throughput (100 iterations, 10000 tasks)', results);
}

void _printResults(String name, List<double> results) {
  results.sort();
  final median = results[results.length ~/ 2];
  final min = results.first;
  final max = results.last;
  final avg = results.reduce((a, b) => a + b) / results.length;

  print('$name:');
  print('  Min: ${min.toStringAsFixed(2)} ms');
  print('  Max: ${max.toStringAsFixed(2)} ms');
  print('  Avg: ${avg.toStringAsFixed(2)} ms');
  print('  Median: ${median.toStringAsFixed(2)} ms');
}

Future<double> _runPipelineBenchmark({
  required int iterations,
  required int taskCount,
  EventTransformer<dynamic, dynamic>? transformer,
}) async {
  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    final pipeline = Pipeline(
      transformer:
          transformer ?? (events, mapper) => events.asyncExpand(mapper),
    );

    final futures = <Future<int>>[];
    for (var j = 0; j < taskCount; j++) {
      futures.add(pipeline.run((_) async => j));
    }

    await Future.wait(futures);
    await pipeline.dispose();
  }

  stopwatch.stop();
  return stopwatch.elapsedMilliseconds.toDouble();
}

// Custom transformers for testing
Stream<R> _flatMapTransformer<E, R>(
  Stream<E> events,
  Stream<R> Function(E) mapper,
) {
  return events.transform(
    StreamTransformer.fromHandlers(
      handleData: (event, sink) {
        mapper(event).listen(sink.add);
      },
    ),
  );
}

Stream<R> _switchMapTransformer<E, R>(
  Stream<E> events,
  Stream<R> Function(E) mapper,
) {
  StreamSubscription<R>? currentSub;
  return events.transform(
    StreamTransformer.fromHandlers(
      handleData: (event, sink) {
        currentSub?.cancel();
        currentSub = mapper(event).listen(sink.add);
      },
      handleDone: (sink) {
        currentSub?.cancel();
        sink.close();
      },
    ),
  );
}
