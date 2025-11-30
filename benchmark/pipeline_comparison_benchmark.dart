import 'dart:async';
import 'dart:collection';

import '../packages/pureflow/lib/src/common/bit_flags.dart';
import '../packages/pureflow/lib/src/common/synchronous_future.dart';

/// Direct comparison benchmark: async* generator vs custom Stream implementation

void main() async {
  print('Pipeline Implementation Comparison Benchmark');
  print('OLD: async* generator');
  print('NEW: custom Stream + StreamSubscription\n');
  print('=' * 70);

  // Warmup
  print('Warming up...');
  await _runBenchmark(_OldPipeline.new, iterations: 50, taskCount: 10);
  await _runBenchmark(_NewPipeline.new, iterations: 50, taskCount: 10);

  print('\nRunning benchmarks...\n');

  // Test 1: Many iterations with few tasks
  print('--- Test 1: 500 iterations × 50 tasks ---');
  await _compareBenchmark(iterations: 500, taskCount: 50);

  // Test 2: Few iterations with many tasks
  print('\n--- Test 2: 50 iterations × 500 tasks ---');
  await _compareBenchmark(iterations: 50, taskCount: 500);

  // Test 3: High throughput
  print('\n--- Test 3: 10 iterations × 5000 tasks ---');
  await _compareBenchmark(iterations: 10, taskCount: 5000);

  // Test 4: Rapid pipeline creation/disposal
  print('\n--- Test 4: 1000 iterations × 10 tasks (rapid creation) ---');
  await _compareBenchmark(iterations: 1000, taskCount: 10);

  print('\n${'=' * 70}');
  print('Benchmark complete.\n');
}

Future<void> _compareBenchmark({
  required int iterations,
  required int taskCount,
}) async {
  final oldResults = <double>[];
  final newResults = <double>[];

  for (var run = 0; run < 5; run++) {
    oldResults.add(await _runBenchmark(
      _OldPipeline.new,
      iterations: iterations,
      taskCount: taskCount,
    ));
    newResults.add(await _runBenchmark(
      _NewPipeline.new,
      iterations: iterations,
      taskCount: taskCount,
    ));
  }

  oldResults.sort();
  newResults.sort();

  final oldMedian = oldResults[oldResults.length ~/ 2];
  final newMedian = newResults[newResults.length ~/ 2];
  final improvement = (oldMedian - newMedian) / oldMedian * 100;
  final speedup = oldMedian / newMedian;

  print('OLD (async*):    ${oldMedian.toStringAsFixed(2)} ms (median)');
  print('NEW (custom):    ${newMedian.toStringAsFixed(2)} ms (median)');

  if (improvement > 0) {
    print('Result: NEW is ${improvement.toStringAsFixed(1)}% faster '
        '(${speedup.toStringAsFixed(2)}x speedup)');
  } else {
    print('Result: OLD is ${(-improvement).toStringAsFixed(1)}% faster '
        '(${(1 / speedup).toStringAsFixed(2)}x speedup)');
  }
}

Future<double> _runBenchmark(
  _BasePipeline Function() factory, {
  required int iterations,
  required int taskCount,
}) async {
  final stopwatch = Stopwatch()..start();

  for (var i = 0; i < iterations; i++) {
    final pipeline = factory();

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

// ============================================================================
// Base Pipeline Interface
// ============================================================================

abstract class _BasePipeline {
  Future<T> run<T>(Future<T> Function(dynamic ctx) task);
  Future<void> dispose();
}

// ============================================================================
// OLD Implementation (async* generator)
// ============================================================================

class _OldPipeline implements _BasePipeline {
  final _OldTaskStream _taskStream = _OldTaskStream();

  @override
  Future<T> run<T>(Future<T> Function(dynamic ctx) task) {
    final completer = Completer<T>.sync();
    _taskStream.add(_OldEvent<T>(task: task, completer: completer));
    return completer.future;
  }

  @override
  Future<void> dispose() => _taskStream.dispose();
}

class _OldEvent<T> {
  final Future<T> Function(dynamic ctx) task;
  final Completer<T> completer;
  bool isCancelled = false;

  _OldEvent({required this.task, required this.completer});

  void cancel() => isCancelled = true;
}

class _OldTaskStream {
  final Queue<_OldEvent<dynamic>> _eventQueue = Queue();
  final Set<_OldEvent<dynamic>> _activeEvents = {};
  Completer<void>? _waitingCompleter;
  bool _isActive = true;
  bool _isDisposed = false;
  StreamSubscription<dynamic>? _subscription;

  _OldTaskStream() {
    _initializeProcessing();
  }

  void _initializeProcessing() {
    final sourceStream = _createSourceStream();
    final processedStream = sourceStream.asyncExpand(_processEvent);
    _subscription = processedStream.listen(null, cancelOnError: false);
  }

  // OLD: Using async* generator
  Stream<dynamic> _createSourceStream() async* {
    while (_isActive) {
      if (_eventQueue.isEmpty) {
        final pendingCompleter = _waitingCompleter ??= Completer<void>();
        await pendingCompleter.future;
        _waitingCompleter = null;
        if (!_isActive) return;
      }
      yield _eventQueue.removeFirst();
    }
  }

  Stream<dynamic> _processEvent(dynamic event) async* {
    if (event is! _OldEvent<dynamic>) return;
    _activeEvents.add(event);
    try {
      final result = await event.task(null);
      if (!event.isCancelled && !event.completer.isCompleted) {
        event.completer.complete(result);
      }
      yield result;
    } catch (e, st) {
      if (!event.completer.isCompleted) {
        event.completer.completeError(e, st);
      }
    } finally {
      _activeEvents.remove(event);
    }
  }

  void _completeWaitingCompleter() {
    final completer = _waitingCompleter;
    if (completer != null && !completer.isCompleted) {
      _waitingCompleter = null;
      completer.complete();
    }
  }

  void add(_OldEvent<dynamic> event) {
    if (_isDisposed || !_isActive) {
      event.cancel();
      return;
    }
    _eventQueue.add(event);
    _completeWaitingCompleter();
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    final futures = <Future<dynamic>>[];
    for (final event in _eventQueue) {
      futures.add(event.completer.future);
    }
    for (final event in _activeEvents) {
      futures.add(event.completer.future);
    }

    _completeWaitingCompleter();

    if (futures.isNotEmpty) {
      try {
        await Future.wait(futures);
      } catch (_) {}
    }

    _isActive = false;
    _completeWaitingCompleter();
    await _subscription?.cancel();
  }
}

// ============================================================================
// NEW Implementation (custom Stream)
// ============================================================================

class _NewPipeline implements _BasePipeline {
  final _NewTaskStream _taskStream = _NewTaskStream();

  @override
  Future<T> run<T>(Future<T> Function(dynamic ctx) task) {
    final completer = Completer<T>.sync();
    _taskStream.add(_NewEvent<T>(task: task, completer: completer));
    return completer.future;
  }

  @override
  Future<void> dispose() => _taskStream.dispose();
}

class _NewEvent<T> {
  final Future<T> Function(dynamic ctx) task;
  final Completer<T> completer;
  bool isCancelled = false;

  _NewEvent({required this.task, required this.completer});

  void cancel() => isCancelled = true;
}

class _NewTaskStream {
  final Queue<_NewEvent<dynamic>> _eventQueue = Queue();
  final Set<_NewEvent<dynamic>> _activeEvents = {};
  Completer<void>? _waitingCompleter;
  bool _isActive = true;
  bool _isDisposed = false;
  StreamSubscription<dynamic>? _subscription;

  _NewTaskStream() {
    _initializeProcessing();
  }

  void _initializeProcessing() {
    // NEW: Using custom Stream implementation
    final sourceStream = _NewSourceStream(this);
    final processedStream = sourceStream.asyncExpand(_processEvent);
    _subscription = processedStream.listen(null, cancelOnError: false);
  }

  Stream<dynamic> _processEvent(dynamic event) async* {
    if (event is! _NewEvent<dynamic>) return;
    _activeEvents.add(event);
    try {
      final result = await event.task(null);
      if (!event.isCancelled && !event.completer.isCompleted) {
        event.completer.complete(result);
      }
      yield result;
    } catch (e, st) {
      if (!event.completer.isCompleted) {
        event.completer.completeError(e, st);
      }
    } finally {
      _activeEvents.remove(event);
    }
  }

  void _completeWaitingCompleter() {
    final completer = _waitingCompleter;
    if (completer != null && !completer.isCompleted) {
      _waitingCompleter = null;
      completer.complete();
    }
  }

  void add(_NewEvent<dynamic> event) {
    if (_isDisposed || !_isActive) {
      event.cancel();
      return;
    }
    _eventQueue.add(event);
    _completeWaitingCompleter();
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    final futures = <Future<dynamic>>[];
    for (final event in _eventQueue) {
      futures.add(event.completer.future);
    }
    for (final event in _activeEvents) {
      futures.add(event.completer.future);
    }

    _completeWaitingCompleter();

    if (futures.isNotEmpty) {
      try {
        await Future.wait(futures);
      } catch (_) {}
    }

    _isActive = false;
    _completeWaitingCompleter();
    await _subscription?.cancel();
  }
}

// NEW: Custom Stream implementation (no async*)
class _NewSourceStream extends Stream<dynamic> {
  final _NewTaskStream _taskStream;

  _NewSourceStream(this._taskStream);

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _NewSourceStreamSubscription(_taskStream, onData, onDone);
  }
}

const int _srcCanceledBit = 1 << 0;
const int _srcPausedBit = 1 << 1;
const int _srcScheduledBit = 1 << 2;

class _NewSourceStreamSubscription implements StreamSubscription<dynamic> {
  final _NewTaskStream _taskStream;
  void Function(dynamic event)? _onData;
  void Function()? _onDone;
  final Zone _zone = Zone.current;

  int _statusFlag = 0;

  _NewSourceStreamSubscription(
    this._taskStream,
    this._onData,
    this._onDone,
  ) {
    _scheduleNext();
  }

  void _scheduleNext() {
    if (_statusFlag.hasFlag(_srcScheduledBit)) return;
    if (_statusFlag.hasFlag(_srcCanceledBit)) return;

    _statusFlag = _statusFlag.setFlag(_srcScheduledBit);
    _processNext();
  }

  void _processNext() {
    _statusFlag = _statusFlag.clearFlag(_srcScheduledBit);

    if (_statusFlag.hasFlag(_srcCanceledBit)) return;
    if (_statusFlag.hasFlag(_srcPausedBit)) return;

    if (!_taskStream._isActive) {
      _invokeDone();
      return;
    }

    if (_taskStream._eventQueue.isEmpty) {
      final completer =
          _taskStream._waitingCompleter ??= Completer<void>.sync();
      completer.future.then((_) {
        if (!_statusFlag.hasFlag(_srcCanceledBit)) {
          _scheduleNext();
        }
      });
      return;
    }

    final event = _taskStream._eventQueue.removeFirst();

    final handler = _onData;
    if (handler != null) {
      _zone.runUnaryGuarded(handler, event);
    }

    _scheduleNext();
  }

  void _invokeDone() {
    final handler = _onDone;
    if (handler != null) {
      _zone.runGuarded(handler);
    }
  }

  @override
  Future<void> cancel() {
    if (_statusFlag.hasFlag(_srcCanceledBit)) {
      return const SynchronousFuture<void>(null);
    }
    _statusFlag = _statusFlag.setFlag(_srcCanceledBit);
    return const SynchronousFuture<void>(null);
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    if (_statusFlag.hasFlag(_srcPausedBit | _srcCanceledBit)) return;
    _statusFlag = _statusFlag.setFlag(_srcPausedBit);
    resumeSignal?.whenComplete(resume);
  }

  @override
  void resume() {
    if (!_statusFlag.hasFlag(_srcPausedBit)) return;
    _statusFlag = _statusFlag.clearFlag(_srcPausedBit);
    _scheduleNext();
  }

  @override
  bool get isPaused => _statusFlag.hasFlag(_srcPausedBit);

  @override
  void onData(void Function(dynamic event)? handleData) {
    _onData = handleData;
  }

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {
    _onDone = handleDone;
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    final completer = Completer<E>();
    final oldOnDone = _onDone;
    _onDone = () {
      oldOnDone?.call();
      completer.complete(futureValue);
    };
    return completer.future;
  }
}
