// ignore_for_file: library_private_types_in_public_api, unused_field, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/fair_benchmark_base.dart';
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

// The same batch size is used by Bloc and Caffeine. Sensitivity checks at
// 16/32/64 operations showed per-operation scores had reached a stable range
// by 32 while keeping each harness exercise bounded.
const _asyncDeliveryBatchSize = 32;

int _expectedBatchSum(int first) =>
    _asyncDeliveryBatchSize * (2 * first + _asyncDeliveryBatchSize - 1) ~/ 2;

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(42);
}

class BlocCubitCreateBenchmark extends AsyncBenchmarkBase {
  int _result = 0;

  BlocCubitCreateBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.lifecycle',
            emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> run() async {
    final cubit = CounterCubit();
    _result = cubit.state;
    await cubit.close();
  }
}

class BlocCubitReadBenchmark extends SyncRunAsyncLifecycleBenchmarkBase {
  late CounterCubit cubit;
  int _result = 0;

  BlocCubitReadBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.read', emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    cubit = CounterCubit();
  }

  @override
  void run() {
    _result = cubit.state;
  }

  @override
  Future<void> teardown() async {
    await cubit.close();
  }
}

class BlocCubitWriteBenchmark extends SyncRunAsyncLifecycleBenchmarkBase {
  late CounterCubit cubit;
  int _counter = 0;

  BlocCubitWriteBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.write', emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    cubit = CounterCubit();
  }

  @override
  void run() {
    cubit.emit(++_counter);
  }

  @override
  Future<void> teardown() async {
    await cubit.close();
  }
}

/// Measures the cost of emit + async delivery to 1 stream listener.
/// Uses Bloc's native `stream.listen()` — events are delivered asynchronously
/// via microtasks. This async overhead is inherent to Bloc's architecture;
/// other libraries (Pureflow, Signals, MobX) notify
/// synchronously.
class BlocCubitNotifyBenchmark extends AsyncBenchmarkBase {
  late CounterCubit cubit;
  late StreamSubscription<int> _subscription;
  int _counter = 0;
  int _remaining = 0;
  int _lastValue = 0;
  late Completer<void> _batchDone;
  int _checksum = 0;

  BlocCubitNotifyBenchmark({ScoreEmitter? emitter})
      : super(
          'Bloc: Cubit.notify',
          emitter: emitter ?? const PrintEmitter(),
          operationsPerRun: _asyncDeliveryBatchSize,
        );

  @override
  Future<void> setup() async {
    cubit = CounterCubit();
    _batchDone = Completer<void>();
    _subscription = cubit.stream.listen((state) {
      _checksum += state;
      _lastValue = state;
      if (_remaining == 0) return;
      if (--_remaining == 0) {
        _batchDone.complete();
      } else {
        _emitNext();
      }
    });
  }

  void _emitNext() => cubit.emit(++_counter);

  @override
  Future<void> run() async {
    final first = _counter + 1;
    final checksumBefore = _checksum;
    _remaining = _asyncDeliveryBatchSize;
    _batchDone = Completer<void>();
    _emitNext();
    await _batchDone.future;

    final expectedLast = first + _asyncDeliveryBatchSize - 1;
    if (_lastValue != expectedLast ||
        _checksum - checksumBefore != _expectedBatchSum(first)) {
      throw StateError('Wrong bloc notification batch.');
    }
  }

  @override
  Future<void> teardown() async {
    await _subscription.cancel();
    await cubit.close();
  }
}

/// Measures the cost of emit + async delivery to 1000 stream listeners.
/// Uses Bloc's native `stream.listen()` — each listener receives the event
/// via its own microtask. This is how real Bloc apps with multiple
/// BlocBuilders/stream.listen calls work.
class BlocCubitNotifyManyDependentsBenchmark extends AsyncBenchmarkBase {
  late CounterCubit cubit;
  final List<StreamSubscription<int>> _subscriptions = [];
  int _counter = 0;
  int _notified = 0;
  int _remaining = 0;
  int _lastValue = 0;
  late Completer<void> _batchDone;
  int _checksum = 0;

  BlocCubitNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter(),
            operationsPerRun: _asyncDeliveryBatchSize);

  @override
  Future<void> setup() async {
    cubit = CounterCubit();
    _batchDone = Completer<void>();
    for (var i = 0; i < 1000; i++) {
      _subscriptions.add(cubit.stream.listen((state) {
        _checksum += state;
        _lastValue = state;
        if (_remaining == 0 || ++_notified != 1000) return;
        _notified = 0;
        if (--_remaining == 0) {
          _batchDone.complete();
        } else {
          _emitNext();
        }
      }));
    }
  }

  void _emitNext() => cubit.emit(++_counter);

  @override
  Future<void> run() async {
    final first = _counter + 1;
    final checksumBefore = _checksum;
    _notified = 0;
    _remaining = _asyncDeliveryBatchSize;
    _batchDone = Completer<void>();
    _emitNext();
    await _batchDone.future;

    final expectedLast = first + _asyncDeliveryBatchSize - 1;
    if (_lastValue != expectedLast ||
        _checksum - checksumBefore != _expectedBatchSum(first) * 1000) {
      throw StateError('Wrong bloc fan-out batch.');
    }
  }

  @override
  Future<void> teardown() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await cubit.close();
  }
}

// ============================================================================
// Async Configurable Concurrency Flow Benchmarks
// ============================================================================

class SequentialBloc extends Bloc<int, int> {
  SequentialBloc() : super(0) {
    on<int>(
      (event, emit) async {
        await Future<void>.delayed(Duration.zero);
        emit(event);
      },
      transformer: sequential(),
    );
  }
}

class BlocSequentialBenchmark extends AsyncBenchmarkBase {
  late SequentialBloc bloc;
  int _counter = 0;
  late StreamSubscription<int> _subscription;
  late Completer<void> _completer;
  final List<int> _received = [];
  int _checksum = 0;

  BlocSequentialBenchmark({ScoreEmitter? emitter})
      : super(
          'Bloc: Sequential',
          emitter: emitter ?? const PrintEmitter(),
          operationsPerRun: 2,
        );

  @override
  Future<void> setup() async {
    bloc = SequentialBloc();
    _completer = Completer<void>();
    // Single persistent subscription — avoids creating/cancelling a
    // broadcast subscription on every iteration (stream.first pattern),
    // which is racy with async broadcast delivery.
    _subscription = bloc.stream.listen((state) {
      _received.add(state);
      _checksum += state;
      if (_received.length == 2 && !_completer.isCompleted) {
        _completer.complete();
      }
    });
  }

  @override
  Future<void> run() async {
    final first = ++_counter;
    final second = ++_counter;
    _received.clear();
    _completer = Completer<void>();
    bloc
      ..add(first)
      ..add(second);
    await _completer.future;
    if (_received[0] != first || _received[1] != second) {
      throw StateError('Wrong bloc order: $_received != [$first, $second]');
    }
  }

  @override
  Future<void> teardown() async {
    await _subscription.cancel();
    await bloc.close();
  }
}

// ============================================================================
// Main
// ============================================================================

Future<List<BenchmarkResult>> runBenchmark() async {
  // Create custom emitter to collect results
  final emitter = CollectingScoreEmitter(_extractFeature, _extractTiming);

  // State Holder Benchmarks
  await BlocCubitCreateBenchmark(emitter: emitter).report();
  await BlocCubitReadBenchmark(emitter: emitter).report();
  await BlocCubitWriteBenchmark(emitter: emitter).report();
  await BlocCubitNotifyBenchmark(emitter: emitter).report();
  await BlocCubitNotifyManyDependentsBenchmark(emitter: emitter).report();

  // Async Configurable Concurrency Flow Benchmarks
  await BlocSequentialBenchmark(emitter: emitter).report();

  return emitter.results;
}

String _extractFeature(String benchmarkName) {
  if (benchmarkName.contains('Cubit.lifecycle')) {
    return 'State Holder: Lifecycle (Create + Use + Release)';
  }
  if (benchmarkName.contains('Cubit.read')) {
    return 'State Holder: Read';
  }
  if (benchmarkName.contains('Cubit.write')) {
    return 'State Holder: Write';
  }
  if (benchmarkName.contains('Cubit.notify.many_dependents')) {
    return 'State Holder: Notify - Many Dependents (1000)';
  }
  if (benchmarkName.contains('Cubit.notify')) {
    return 'State Holder: Notify';
  }
  if (benchmarkName.contains('Sequential')) {
    return 'Async Concurrency: Sequential';
  }

  return benchmarkName;
}

BenchmarkTiming _extractTiming(String benchmarkName) {
  if (benchmarkName.contains('Cubit.lifecycle') ||
      benchmarkName.contains('Cubit.notify') ||
      benchmarkName.contains('Sequential')) {
    return BenchmarkTiming.asyncSettled;
  }
  return BenchmarkTiming.synchronous;
}

Future<void> main() async {
  await runBenchmark();
}
