// ignore_for_file: unused_field, unused_local_variable, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark/common/fair_benchmark_base.dart';
import 'package:bloc_signals/bloc_signals.dart';

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 42);
}

class BlocSignalsCubitCreateBenchmark extends AsyncBenchmarkBase {
  int _result = 0;

  BlocSignalsCubitCreateBenchmark({ScoreEmitter? emitter})
      : super(
          'BlocSignals: CubitSignal.lifecycle',
          emitter: emitter ?? const PrintEmitter(),
        );

  @override
  Future<void> run() async {
    final cubit = CounterCubit();
    _result = cubit.stateValue;
    await cubit.close();
  }
}

class BlocSignalsCubitReadBenchmark extends SyncRunAsyncLifecycleBenchmarkBase {
  late CounterCubit cubit;
  int _result = 0;

  BlocSignalsCubitReadBenchmark({ScoreEmitter? emitter})
      : super(
          'BlocSignals: CubitSignal.read',
          emitter: emitter ?? const PrintEmitter(),
        );

  @override
  Future<void> setup() async {
    cubit = CounterCubit();
  }

  @override
  void run() {
    _result = cubit.stateValue;
  }

  @override
  Future<void> teardown() async {
    await cubit.close();
  }
}

class BlocSignalsCubitWriteBenchmark
    extends SyncRunAsyncLifecycleBenchmarkBase {
  late CounterCubit cubit;
  int _counter = 0;

  BlocSignalsCubitWriteBenchmark({ScoreEmitter? emitter})
      : super(
          'BlocSignals: CubitSignal.write',
          emitter: emitter ?? const PrintEmitter(),
        );

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

class BlocSignalsCubitNotifyBenchmark
    extends SyncRunAsyncLifecycleBenchmarkBase {
  late CounterCubit cubit;
  int _counter = 0;
  int _notifications = 0;
  int _checksum = 0;

  BlocSignalsCubitNotifyBenchmark({ScoreEmitter? emitter})
      : super(
          'BlocSignals: CubitSignal.notify',
          emitter: emitter ?? const PrintEmitter(),
        );

  @override
  Future<void> setup() async {
    cubit = CounterCubit();
    cubit.createEffect(() {
      final value = cubit.state.value;
      _checksum += value;
      _notifications++;
    });
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

class BlocSignalsCubitNotifyManyDependentsBenchmark
    extends SyncRunAsyncLifecycleBenchmarkBase {
  late CounterCubit cubit;
  int _counter = 0;
  int _checksum = 0;

  BlocSignalsCubitNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super(
          'BlocSignals: CubitSignal.notify.many_dependents',
          emitter: emitter ?? const PrintEmitter(),
        );

  @override
  Future<void> setup() async {
    cubit = CounterCubit();
    for (var i = 0; i < 1000; i++) {
      cubit.createEffect(() {
        _checksum += cubit.state.value;
      });
    }
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

// ============================================================================
// Async Configurable Concurrency Flow Benchmarks
// ============================================================================

class SequentialBloc extends BlocSignal<int, int> {
  SequentialBloc() : super(initialState: 0) {
    on<int>(
      (event, emit) async {
        await Future<void>.delayed(Duration.zero);
        emit(event);
      },
      transformer: sequential(),
    );
  }
}

class BlocSignalsSequentialBenchmark extends AsyncBenchmarkBase {
  late SequentialBloc bloc;
  int _counter = 0;
  late Completer<void> _completer;
  final List<int> _received = [];
  int _checksum = 0;

  BlocSignalsSequentialBenchmark({ScoreEmitter? emitter})
      : super(
          'BlocSignals: Sequential',
          emitter: emitter ?? const PrintEmitter(),
          operationsPerRun: 2,
        );

  @override
  Future<void> setup() async {
    bloc = SequentialBloc();
    _completer = Completer<void>();
    bloc.createEffect(() {
      final state = bloc.state.value;
      if (state == 0) return;
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
      throw StateError(
        'Wrong bloc signal order: $_received != [$first, $second]',
      );
    }
  }

  @override
  Future<void> teardown() async {
    await bloc.close();
  }
}

// ============================================================================
// Main
// ============================================================================

Future<List<BenchmarkResult>> runBenchmark() async {
  final emitter = CollectingScoreEmitter(_extractFeature, _extractTiming);

  await BlocSignalsCubitCreateBenchmark(emitter: emitter).report();
  await BlocSignalsCubitReadBenchmark(emitter: emitter).report();
  await BlocSignalsCubitWriteBenchmark(emitter: emitter).report();
  await BlocSignalsCubitNotifyBenchmark(emitter: emitter).report();
  await BlocSignalsCubitNotifyManyDependentsBenchmark(emitter: emitter)
      .report();

  await BlocSignalsSequentialBenchmark(emitter: emitter).report();

  return emitter.results;
}

String _extractFeature(String benchmarkName) {
  if (benchmarkName.contains('CubitSignal.lifecycle')) {
    return 'State Holder: Lifecycle (Create + Use + Release)';
  }
  if (benchmarkName.contains('CubitSignal.read')) {
    return 'State Holder: Read';
  }
  if (benchmarkName.contains('CubitSignal.write')) {
    return 'State Holder: Write';
  }
  if (benchmarkName.contains('CubitSignal.notify.many_dependents')) {
    return 'State Holder: Notify - Many Dependents (1000)';
  }
  if (benchmarkName.contains('CubitSignal.notify')) {
    return 'State Holder: Notify';
  }
  if (benchmarkName.contains('Sequential')) {
    return 'Async Concurrency: Sequential';
  }
  return benchmarkName;
}

BenchmarkTiming _extractTiming(String benchmarkName) {
  if (benchmarkName.contains('CubitSignal.lifecycle') ||
      benchmarkName.contains('Sequential')) {
    return BenchmarkTiming.asyncSettled;
  }
  return BenchmarkTiming.synchronous;
}

Future<void> main() async {
  await runBenchmark();
}
