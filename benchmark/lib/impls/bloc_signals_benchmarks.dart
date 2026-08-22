// ignore_for_file: unused_field, unused_local_variable, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:bloc_signals/bloc_signals.dart';

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 42);
}

class BlocSignalsCubitCreateBenchmark extends BenchmarkBase {
  final List<CounterCubit> _cubits = [];

  BlocSignalsCubitCreateBenchmark({ScoreEmitter? emitter})
      : super(
          'BlocSignals: CubitSignal.create',
          emitter: emitter ?? const PrintEmitter(),
        );

  @override
  void run() {
    final cubit = CounterCubit();
    _cubits.add(cubit);
  }

  @override
  void teardown() {
    _cubits.clear();
  }
}

class BlocSignalsCubitReadBenchmark extends BenchmarkBase {
  late final CounterCubit cubit;
  int _result = 0;

  BlocSignalsCubitReadBenchmark({ScoreEmitter? emitter})
      : super(
          'BlocSignals: CubitSignal.read',
          emitter: emitter ?? const PrintEmitter(),
        );

  @override
  void setup() {
    cubit = CounterCubit();
  }

  @override
  void run() {
    _result = cubit.stateValue;
  }

  @override
  void teardown() {
    unawaited(cubit.close());
  }
}

class BlocSignalsCubitWriteBenchmark extends BenchmarkBase {
  late final CounterCubit cubit;
  int _counter = 0;

  BlocSignalsCubitWriteBenchmark({ScoreEmitter? emitter})
      : super(
          'BlocSignals: CubitSignal.write',
          emitter: emitter ?? const PrintEmitter(),
        );

  @override
  void setup() {
    cubit = CounterCubit();
  }

  @override
  void run() {
    cubit.emit(++_counter);
  }

  @override
  void teardown() {
    unawaited(cubit.close());
  }
}

class BlocSignalsCubitNotifyBenchmark extends BenchmarkBase {
  late final CounterCubit cubit;
  int _counter = 0;
  int _notifications = 0;

  BlocSignalsCubitNotifyBenchmark({ScoreEmitter? emitter})
      : super(
          'BlocSignals: CubitSignal.notify',
          emitter: emitter ?? const PrintEmitter(),
        );

  @override
  void setup() {
    cubit = CounterCubit();
    cubit.createEffect(() {
      final _ = cubit.state.value;
      _notifications++;
    });
  }

  @override
  void run() {
    cubit.emit(++_counter);
  }

  @override
  void teardown() {
    unawaited(cubit.close());
  }
}

class BlocSignalsCubitNotifyManyDependentsBenchmark extends BenchmarkBase {
  late final CounterCubit cubit;
  int _counter = 0;

  BlocSignalsCubitNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super(
          'BlocSignals: CubitSignal.notify.many_dependents',
          emitter: emitter ?? const PrintEmitter(),
        );

  @override
  void setup() {
    cubit = CounterCubit();
    for (var i = 0; i < 1000; i++) {
      cubit.createEffect(() {
        final _ = cubit.state.value;
      });
    }
  }

  @override
  void run() {
    cubit.emit(++_counter);
  }

  @override
  void teardown() {
    unawaited(cubit.close());
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
  late final SequentialBloc bloc;
  int _counter = 0;
  int _expected = -1;
  late Completer<int> _completer;

  BlocSignalsSequentialBenchmark({ScoreEmitter? emitter})
      : super(
          'BlocSignals: Sequential',
          emitter: emitter ?? const PrintEmitter(),
        );

  @override
  Future<void> setup() async {
    bloc = SequentialBloc();
    _completer = Completer<int>();
    bloc.createEffect(() {
      final state = bloc.state.value;
      if (state == _expected && !_completer.isCompleted) {
        _completer.complete(state);
      }
    });
  }

  @override
  Future<void> run() async {
    final value = ++_counter;
    _expected = value;
    _completer = Completer<int>();
    bloc.add(value);
    final newValue = await _completer.future;
    assert(value == newValue, 'Wrong bloc signal value: $value != $newValue');
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
  final emitter = CollectingScoreEmitter(_extractFeature);

  BlocSignalsCubitCreateBenchmark(emitter: emitter).report();
  BlocSignalsCubitReadBenchmark(emitter: emitter).report();
  BlocSignalsCubitWriteBenchmark(emitter: emitter).report();
  BlocSignalsCubitNotifyBenchmark(emitter: emitter).report();
  BlocSignalsCubitNotifyManyDependentsBenchmark(emitter: emitter).report();

  await BlocSignalsSequentialBenchmark(emitter: emitter).report();

  return emitter.results;
}

String _extractFeature(String benchmarkName) {
  if (benchmarkName.contains('CubitSignal.create')) {
    return 'State Holder: Create';
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

Future<void> main() async {
  await runBenchmark();
}
