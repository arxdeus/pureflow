// ignore_for_file: library_private_types_in_public_api, unused_field, invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import 'dart:async';

import 'package:benchmark/common/benchmark_result.dart';
import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

// ============================================================================
// State Holder Benchmarks
// ============================================================================

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(42);
}

class BlocCubitCreateBenchmark extends BenchmarkBase {
  final List<CounterCubit> _cubits = [];

  BlocCubitCreateBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.create', emitter: emitter ?? const PrintEmitter());

  @override
  void run() {
    final cubit = CounterCubit();
    _cubits.add(cubit);
  }

  @override
  void teardown() {
    // Don't call close() on each of ~2M cubits — each close() creates
    // an unawaited Future (async StreamController.close()). Those ~2M
    // microtasks would flood the event loop on the next await, causing
    // massive delay. Just clear the list and let GC handle cleanup.
    _cubits.clear();
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

/// Measures the cost of emit + async delivery to 1 stream listener.
/// Uses Bloc's native `stream.listen()` — events are delivered asynchronously
/// via microtasks. This async overhead is inherent to Bloc's architecture;
/// other libraries (Pureflow, Signals, MobX, ValueNotifier) notify
/// synchronously.
class BlocCubitNotifyBenchmark extends AsyncBenchmarkBase {
  late final CounterCubit cubit;
  late final StreamSubscription<int> _subscription;
  late Completer<void> _completer;
  int _counter = 0;

  BlocCubitNotifyBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.notify', emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    cubit = CounterCubit();
    _completer = Completer<void>();
    _subscription = cubit.stream.listen((state) {
      if (!_completer.isCompleted) {
        _completer.complete();
      }
    });
  }

  @override
  Future<void> run() async {
    _completer = Completer<void>();
    cubit.emit(++_counter);
    await _completer.future;
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
  late final CounterCubit cubit;
  final List<StreamSubscription<int>> _subscriptions = [];
  late Completer<void> _completer;
  int _counter = 0;
  int _notified = 0;

  BlocCubitNotifyManyDependentsBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.notify.many_dependents',
            emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    cubit = CounterCubit();
    _completer = Completer<void>();
    for (var i = 0; i < 1000; i++) {
      _subscriptions.add(cubit.stream.listen((state) {
        if (++_notified == 1000 && !_completer.isCompleted) {
          _completer.complete();
        }
      }));
    }
  }

  @override
  Future<void> run() async {
    _notified = 0;
    _completer = Completer<void>();
    cubit.emit(++_counter);
    await _completer.future;
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

class BlocCubitSubscribeBenchmark extends BenchmarkBase {
  late final CounterCubit cubit;
  final List<StreamSubscription<int>> _subscriptions = [];

  BlocCubitSubscribeBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.subscribe',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    cubit = CounterCubit();
  }

  @override
  void run() {
    _subscriptions.add(cubit.stream.listen((state) {
      // Empty listener
    }));
  }

  @override
  void teardown() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    cubit.close();
  }
}

class BlocCubitUnsubscribeBenchmark extends BenchmarkBase {
  late CounterCubit cubit;
  late StreamSubscription<int> subscription;

  BlocCubitUnsubscribeBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Cubit.unsubscribe',
            emitter: emitter ?? const PrintEmitter());

  @override
  void setup() {
    cubit = CounterCubit();
    subscription = cubit.stream.listen((state) {
      // Empty listener
    });
  }

  @override
  void run() {
    subscription.cancel();
  }

  @override
  void teardown() {
    cubit.close();
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
  late final SequentialBloc bloc;
  int _counter = 0;
  late final StreamSubscription<int> _subscription;
  late Completer<int> _completer;

  BlocSequentialBenchmark({ScoreEmitter? emitter})
      : super('Bloc: Sequential', emitter: emitter ?? const PrintEmitter());

  @override
  Future<void> setup() async {
    bloc = SequentialBloc();
    _completer = Completer<int>();
    // Single persistent subscription — avoids creating/cancelling a
    // broadcast subscription on every iteration (stream.first pattern),
    // which is racy with async broadcast delivery.
    _subscription = bloc.stream.listen((state) {
      if (!_completer.isCompleted) {
        _completer.complete(state);
      }
    });
  }

  @override
  Future<void> run() async {
    final value = ++_counter;
    _completer = Completer<int>();
    bloc.add(value);
    final newValue = await _completer.future;
    assert(value == newValue, 'Wrong bloc value: $value != $newValue');
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
  final emitter = CollectingScoreEmitter(_extractFeature);

  // State Holder Benchmarks
  BlocCubitCreateBenchmark(emitter: emitter).report();
  BlocCubitReadBenchmark(emitter: emitter).report();
  BlocCubitWriteBenchmark(emitter: emitter).report();
  await BlocCubitNotifyBenchmark(emitter: emitter).report();
  await BlocCubitNotifyManyDependentsBenchmark(emitter: emitter).report();
  BlocCubitSubscribeBenchmark(emitter: emitter).report();
  BlocCubitUnsubscribeBenchmark(emitter: emitter).report();

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
