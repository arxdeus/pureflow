// ignore_for_file: unused_field, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';
import 'dart:math';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:bloc/bloc.dart';

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(42);
}

class BlocCubitCreateBenchmark extends AsyncBenchmarkBase {
  BlocCubitCreateBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.create', emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> run() async {
    final cubit = CounterCubit();
    await cubit.close();
  }
}

class BlocCubitReadBenchmark extends BenchmarkBase {
  late final CounterCubit cubit;
  int _result = 0;

  BlocCubitReadBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.read', emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    cubit = CounterCubit();
  }

  @override
  void run() {
    _result = cubit.state;
  }

  @override
  void teardown() {
    cubit.close();
  }
}

class BlocCubitWriteBenchmark extends BenchmarkBase {
  late final CounterCubit cubit;
  int _counter = 0;

  BlocCubitWriteBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.write', emitter: emitter ?? const PrintEmitter());

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
    cubit.close();
  }
}

class BlocCubitNotifyBenchmark extends AsyncBenchmarkBase {
  late final CounterCubit cubit;
  int _counter = 0;
  int _notifications = 0;
  late final StreamSubscription<int> subscription;
  Completer<void>? _completer;

  BlocCubitNotifyBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.notify', emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    cubit = CounterCubit();
    subscription = cubit.stream.listen((state) {
      _notifications++;
      _completer?.complete();
    });
  }

  @override
  Future<void> run() async {
    _completer = Completer<void>();
    cubit.emit(++_counter);
    await _completer!.future;
  }

  @override
  Future<void> teardown() async {
    await subscription.cancel();
    await cubit.close();
  }
}

class BlocCubitNotifyManyDependentsBenchmark extends AsyncBenchmarkBase {
  late final CounterCubit cubit;
  final List<StreamSubscription<int>> _subscriptions = [];
  int _counter = 0;

  BlocCubitNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    cubit = CounterCubit();
    for (var i = 0; i < 1000; i++) {
      final subscription = cubit.stream.listen((state) {
        // Just track that notification happened
      });
      _subscriptions.add(subscription);
    }
  }

  @override
  Future<void> run() async {
    cubit.emit(++_counter);
  }

  @override
  Future<void> teardown() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await cubit.close();
  }
}

class BlocCubitSubscribeBenchmark extends AsyncBenchmarkBase {
  late final CounterCubit cubit;
  StreamSubscription<int>? _subscription;

  BlocCubitSubscribeBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.subscribe',
            emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    cubit = CounterCubit();
  }

  @override
  Future<void> run() async {
    _subscription = cubit.stream.listen((state) {
      // Empty listener
    });
  }

  @override
  Future<void> teardown() async {
    await _subscription?.cancel();
    await cubit.close();
  }
}

class BlocCubitUnsubscribeBenchmark extends AsyncBenchmarkBase {
  late final CounterCubit cubit;
  late final StreamSubscription<int> subscription;

  BlocCubitUnsubscribeBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.unsubscribe',
            emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    cubit = CounterCubit();
    subscription = cubit.stream.listen((state) {
      // Empty listener
    });
  }

  @override
  Future<void> run() async {
    await subscription.cancel();
  }

  @override
  Future<void> teardown() async {
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
    );
  }
}

class BlocSequentialBenchmark extends AsyncBenchmarkBase {
  late final SequentialBloc bloc;
  Completer<Object?>? completer;

  BlocSequentialBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Sequential', emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    bloc = SequentialBloc();
  }

  @override
  Future<void> run() async {
    final value = Random().nextInt(100);
    bloc.add(value);
    await Future<void>.delayed(Duration.zero);
    final newValue = bloc.state;
    assert(value == newValue, 'Wrong bloc value: $value');
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
  // Create custom emitter to collect results
  final emitter = CollectingScoreEmitter(_extractFeature);

  // State Holder Benchmarks
  await BlocCubitCreateBenchmark(emitter: emitter).report();
  BlocCubitReadBenchmark(emitter: emitter).report();
  BlocCubitWriteBenchmark(emitter: emitter).report();
  await BlocCubitNotifyBenchmark(emitter: emitter).report();
  await BlocCubitNotifyManyDependentsBenchmark(emitter: emitter).report();
  await BlocCubitSubscribeBenchmark(emitter: emitter).report();
  await BlocCubitUnsubscribeBenchmark(emitter: emitter).report();

  // Async Configurable Concurrency Flow Benchmarks
  await BlocSequentialBenchmark(emitter: emitter).report();

  return emitter.results;
}

String _extractFeature(String benchmarkName) {
  if (benchmarkName.contains('Cubit.create')) {
    return 'State Holder: Create';
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
  if (benchmarkName.contains('Cubit.subscribe')) {
    return 'State Holder: Subscribe';
  }
  if (benchmarkName.contains('Cubit.unsubscribe')) {
    return 'State Holder: Unsubscribe';
  }
  if (benchmarkName.contains('Sequential')) {
    return 'Async Concurrency: Sequential';
  }

  return benchmarkName;
}

Future<void> main() async {
  await runBenchmark();
}
