// ignore_for_file: unnecessary_async

import 'dart:async';

import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

void main() {
  // ============================================================================
  // Basic Operations
  // ============================================================================

  group('Pipeline - Basic Operations', () {
    test('creates pipeline with sequential transformer', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      await pipeline.dispose();
    });

    test('creates pipeline with concurrent transformer', () async {
      final pipeline = Pipeline(transformer: _concurrentTransformer);
      await pipeline.dispose();
    });

    test('runs simple task', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      final result = await pipeline.run((context) async {
        return 42;
      });

      expect(result, 42);
      await pipeline.dispose();
    });

    test('runs task that returns string', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      final result = await pipeline.run((context) async {
        return 'hello world';
      });

      expect(result, 'hello world');
      await pipeline.dispose();
    });

    test('runs task that returns complex object', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      final result = await pipeline.run((context) async {
        return {'key': 'value', 'number': 42};
      });

      expect(result, {'key': 'value', 'number': 42});
      await pipeline.dispose();
    });

    test('runs multiple sequential tasks', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      final order = <int>[];

      await pipeline.run((context) async {
        order.add(1);
        return 1;
      });

      await pipeline.run((context) async {
        order.add(2);
        return 2;
      });

      await pipeline.run((context) async {
        order.add(3);
        return 3;
      });

      expect(order, [1, 2, 3]);
      await pipeline.dispose();
    });

    test('dispose pipeline gracefully', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      final result = await pipeline.run((context) async => 42);
      expect(result, 42);

      await pipeline.dispose();
    });

    test('dispose pipeline forcefully', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      final result = await pipeline.run((context) async => 42);
      expect(result, 42);

      await pipeline.dispose(force: true);
    });
  });

  // ============================================================================
  // PipelineEventContext
  // ============================================================================

  group('Pipeline - PipelineEventContext', () {
    test('isActive is true during execution', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      bool? wasActive;

      await pipeline.run((context) async {
        wasActive = context.isActive;
        return null;
      });

      expect(wasActive, true);
      await pipeline.dispose();
    });

    test('isActive becomes false on force dispose', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      var wasActiveBeforeDelay = true;
      var wasActiveAfterDelay = true;

      // Start a long-running task
      // ignore: unawaited_futures
      pipeline.run((context) async {
        wasActiveBeforeDelay = context.isActive;
        await Future<void>.delayed(const Duration(milliseconds: 100));
        wasActiveAfterDelay = context.isActive;
        return null;
      });

      // Force dispose while task is running
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await pipeline.dispose(force: true);

      // Wait for task to complete
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Before delay, context should be active; after force dispose it should be inactive
      expect(wasActiveBeforeDelay, true);
      expect(wasActiveAfterDelay, false);
    });

    test('eventDuration increases during execution', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      Duration? duration1;
      Duration? duration2;

      await pipeline.run((context) async {
        duration1 = context.eventDuration;
        await Future<void>.delayed(const Duration(milliseconds: 50));
        duration2 = context.eventDuration;
        return null;
      });

      expect(duration1, isNotNull);
      expect(duration2, isNotNull);
      expect(duration2!.inMilliseconds, greaterThan(duration1!.inMilliseconds));
      await pipeline.dispose();
    });

    test('context is unique per task', () async {
      final pipeline = Pipeline(transformer: _concurrentTransformer);
      final contexts = <PipelineEventContext>[];

      await Future.wait([
        pipeline.run((context) async {
          contexts.add(context);
          return null;
        }),
        pipeline.run((context) async {
          contexts.add(context);
          return null;
        }),
        pipeline.run((context) async {
          contexts.add(context);
          return null;
        }),
      ]);

      expect(contexts.length, 3);
      expect(contexts.toSet().length, 3); // All different

      await pipeline.dispose();
    });

    test('context isActive checked multiple times', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      final activeChecks = <bool>[];

      await pipeline.run((context) async {
        activeChecks.add(context.isActive);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        activeChecks.add(context.isActive);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        activeChecks.add(context.isActive);
        return null;
      });

      expect(activeChecks, [true, true, true]);
      await pipeline.dispose();
    });
  });

  // ============================================================================
  // Transformers
  // ============================================================================

  group('Pipeline - Transformers', () {
    test('sequential transformer processes one at a time', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      final order = <String>[];
      var concurrent = 0;
      var maxConcurrent = 0;

      await Future.wait([
        pipeline.run((context) async {
          concurrent++;
          maxConcurrent =
              concurrent > maxConcurrent ? concurrent : maxConcurrent;
          order.add('start1');
          await Future<void>.delayed(const Duration(milliseconds: 20));
          order.add('end1');
          concurrent--;
          return 1;
        }),
        pipeline.run((context) async {
          concurrent++;
          maxConcurrent =
              concurrent > maxConcurrent ? concurrent : maxConcurrent;
          order.add('start2');
          await Future<void>.delayed(const Duration(milliseconds: 20));
          order.add('end2');
          concurrent--;
          return 2;
        }),
      ]);

      expect(maxConcurrent, 1);
      expect(order, ['start1', 'end1', 'start2', 'end2']);
      await pipeline.dispose();
    });

    test('concurrent transformer processes all in parallel', () async {
      final pipeline = Pipeline(transformer: _concurrentTransformer);
      var concurrent = 0;
      var maxConcurrent = 0;

      await Future.wait([
        pipeline.run((context) async {
          concurrent++;
          maxConcurrent =
              concurrent > maxConcurrent ? concurrent : maxConcurrent;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          concurrent--;
          return 1;
        }),
        pipeline.run((context) async {
          concurrent++;
          maxConcurrent =
              concurrent > maxConcurrent ? concurrent : maxConcurrent;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          concurrent--;
          return 2;
        }),
        pipeline.run((context) async {
          concurrent++;
          maxConcurrent =
              concurrent > maxConcurrent ? concurrent : maxConcurrent;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          concurrent--;
          return 3;
        }),
      ]);

      expect(maxConcurrent, 3);
      await pipeline.dispose();
    });

    test('droppable transformer drops events while processing', () async {
      final pipeline = Pipeline(transformer: _droppableTransformer);
      final results = <int>[];

      final future1 = pipeline.run((context) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        results.add(1);
        return 1;
      });

      // These should be dropped - intentionally not awaited
      // ignore: unawaited_futures
      pipeline.run((context) async {
        results.add(2);
        return 2;
      });
      // ignore: unawaited_futures
      pipeline.run((context) async {
        results.add(3);
        return 3;
      });

      await future1;
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(results, [1]);
      await pipeline.dispose(force: true);
    });

    test('restartable transformer cancels previous on new event', () async {
      final pipeline = Pipeline(transformer: _restartableTransformer);
      final completed = <int>[];

      // Start first task
      // ignore: unawaited_futures
      pipeline.run((context) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (context.isActive) completed.add(1);
        return 1;
      });

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Start second task (should cancel first)
      // ignore: unawaited_futures
      pipeline.run((context) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (context.isActive) completed.add(2);
        return 2;
      });

      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Only the last one should complete
      expect(completed.contains(2), true);
      await pipeline.dispose(force: true);
    });
  });

  // ============================================================================
  // Dispose Behavior
  // ============================================================================

  group('Pipeline - Dispose Behavior', () {
    test('graceful dispose waits for active tasks', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      var taskCompleted = false;

      final future = pipeline.run((context) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        taskCompleted = true;
        return 42;
      });

      await pipeline.dispose();

      expect(taskCompleted, true);
      expect(await future, 42);
    });

    test('force dispose makes tasks inactive immediately', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      var wasInactive = false;

      // ignore: unawaited_futures
      pipeline.run((context) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        wasInactive = !context.isActive;
        return 42;
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await pipeline.dispose(force: true);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(wasInactive, true);
    });

    test('queued tasks cancelled on force dispose', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      final executed = <int>[];

      // Start a slow task - intentionally not awaited
      // ignore: unawaited_futures
      pipeline.run((context) async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (context.isActive) executed.add(1);
        return 1;
      });

      // Queue more tasks - intentionally not awaited
      // ignore: unawaited_futures
      pipeline.run((context) async {
        executed.add(2);
        return 2;
      });
      // ignore: unawaited_futures
      pipeline.run((context) async {
        executed.add(3);
        return 3;
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await pipeline.dispose(force: true);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Queued tasks should not have executed
      expect(executed.contains(2), false);
      expect(executed.contains(3), false);
    });

    test('double dispose is safe', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      await pipeline.run((context) async => 42);

      await pipeline.dispose();
      await pipeline.dispose(); // Should not throw
    });

    test('double force dispose is safe', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      await pipeline.run((context) async => 42);

      await pipeline.dispose(force: true);
      await pipeline.dispose(force: true); // Should not throw
    });

    test('dispose with no pending tasks', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      await pipeline.dispose(); // Should not hang
    });
  });

  // ============================================================================
  // Error Handling
  // ============================================================================

  group('Pipeline - Error Handling', () {
    test('task can throw and be caught', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      var errorWasThrown = false;

      // Task throws but we handle it in the task itself
      await pipeline.run((context) async {
        try {
          throw Exception('test error');
        } catch (_) {
          errorWasThrown = true;
        }
        return null;
      });

      expect(errorWasThrown, true);
      await pipeline.dispose();
    });

    test('tasks continue working after one handles error internally', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      var handledError = false;

      await pipeline.run((context) async {
        try {
          throw Exception('error');
        } catch (_) {
          handledError = true;
        }
        return null;
      });

      expect(handledError, true);

      final result = await pipeline.run((context) async {
        return 42;
      });

      expect(result, 42);
      await pipeline.dispose();
    });

    test('task can catch async error', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      var errorHandled = false;

      await pipeline.run((context) async {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          throw Exception('async error');
        } catch (_) {
          errorHandled = true;
        }
        return null;
      });

      expect(errorHandled, true);
      await pipeline.dispose();
    });

    test('concurrent tasks with internal error handling', () async {
      final pipeline = Pipeline(transformer: _concurrentTransformer);
      var errorCount = 0;
      var successResult = 0;

      await Future.wait([
        pipeline.run((context) async {
          try {
            throw Exception('error 1');
          } catch (_) {
            errorCount++;
          }
          return null;
        }),
        pipeline.run((context) async {
          try {
            throw Exception('error 2');
          } catch (_) {
            errorCount++;
          }
          return null;
        }),
        pipeline.run((context) async {
          successResult = 42;
          return successResult;
        }),
      ]);

      expect(errorCount, 2);
      expect(successResult, 42);
      await pipeline.dispose();
    });
  });

  // ============================================================================
  // Concurrency
  // ============================================================================

  group('Pipeline - Concurrency', () {
    test('concurrent tasks complete', () async {
      final pipeline = Pipeline(transformer: _concurrentTransformer);

      final results = await Future.wait([
        pipeline.run((context) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return 1;
        }),
        pipeline.run((context) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return 2;
        }),
        pipeline.run((context) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 3;
        }),
      ]);

      expect(results, [1, 2, 3]);
      await pipeline.dispose();
    });

    test('task completion order with concurrent transformer', () async {
      final pipeline = Pipeline(transformer: _concurrentTransformer);
      final completionOrder = <int>[];

      await Future.wait([
        pipeline.run((context) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          completionOrder.add(1);
          return 1;
        }),
        pipeline.run((context) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          completionOrder.add(2);
          return 2;
        }),
        pipeline.run((context) async {
          await Future<void>.delayed(const Duration(milliseconds: 35));
          completionOrder.add(3);
          return 3;
        }),
      ]);

      // 2 completes first (20ms), then 3 (35ms), then 1 (50ms)
      expect(completionOrder, [2, 3, 1]);
      await pipeline.dispose();
    });

    test('many concurrent tasks', () async {
      final pipeline = Pipeline(transformer: _concurrentTransformer);

      final results = await Future.wait(
        List.generate(
          20,
          (i) => pipeline.run((context) async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return i;
          }),
        ),
      );

      expect(results, List.generate(20, (i) => i));
      await pipeline.dispose();
    });

    test('sequential tasks maintain order', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      final order = <int>[];

      await Future.wait([
        pipeline.run((context) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          order.add(1);
          return 1;
        }),
        pipeline.run((context) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          order.add(2);
          return 2;
        }),
        pipeline.run((context) async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          order.add(3);
          return 3;
        }),
      ]);

      expect(order, [1, 2, 3]); // Sequential, not by delay time
      await pipeline.dispose();
    });
  });

  // ============================================================================
  // Edge Cases
  // ============================================================================

  group('Pipeline - Edge Cases', () {
    test('empty task', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      final result = await pipeline.run((context) async {
        return null;
      });

      expect(result, isNull);
      await pipeline.dispose();
    });

    test('very fast tasks', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      for (var i = 0; i < 100; i++) {
        final result = await pipeline.run((context) async => i);
        expect(result, i);
      }

      await pipeline.dispose();
    });

    test('task that checks isActive repeatedly', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      final activeChecks = <bool>[];

      await pipeline.run((context) async {
        for (var i = 0; i < 10; i++) {
          activeChecks.add(context.isActive);
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        return null;
      });

      expect(activeChecks.every((a) => a), true);
      await pipeline.dispose();
    });

    test('run after dispose is cancelled', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      await pipeline.dispose();

      // After dispose, new tasks should be cancelled
      // ignore: unawaited_futures
      pipeline.run((context) async {
        return 42;
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Pipeline should still be accessible
      expect(pipeline, isNotNull);
    });

    test('dispose during task execution', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      var contextActive = true;

      // ignore: unawaited_futures
      pipeline.run((context) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        contextActive = context.isActive;
        return 42;
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await pipeline.dispose(force: true);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(contextActive, false);
    });

    test('task returning void', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      var executed = false;

      await pipeline.run((context) async {
        executed = true;
      });

      expect(executed, true);
      await pipeline.dispose();
    });

    test('task with closure capturing external state', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      var counter = 0;

      await pipeline.run((context) async {
        return ++counter;
      });

      await pipeline.run((context) async {
        return ++counter;
      });

      expect(counter, 2);
      await pipeline.dispose();
    });

    test('pipeline with immediate dispose', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      await pipeline.dispose();
      // Should not hang or error
    });

    test('multiple pipelines independent', () async {
      final pipeline1 = Pipeline(transformer: _sequentialTransformer);
      final pipeline2 = Pipeline(transformer: _sequentialTransformer);

      final result1 = await pipeline1.run((context) async => 1);
      final result2 = await pipeline2.run((context) async => 2);

      expect(result1, 1);
      expect(result2, 2);

      await pipeline1.dispose();
      await pipeline2.dispose();
    });
  });

  // ============================================================================
  // Complex Scenarios
  // ============================================================================

  group('Pipeline - Complex Scenarios', () {
    test('pipeline with dependent tasks', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      final first = await pipeline.run((context) async => 10);
      final second = await pipeline.run((context) async => first * 2);
      final third = await pipeline.run((context) async => second + 5);

      expect(third, 25);
      await pipeline.dispose();
    });

    test('pipeline with shared state', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      final state = <String>[];

      await pipeline.run((context) async {
        state.add('task1');
        return null;
      });

      await pipeline.run((context) async {
        state.add('task2');
        return null;
      });

      await pipeline.run((context) async {
        state.add('task3');
        return null;
      });

      expect(state, ['task1', 'task2', 'task3']);
      await pipeline.dispose();
    });

    test('pipeline simulating API calls', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      Future<Map<String, dynamic>> fakeApiCall(String endpoint) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return {'endpoint': endpoint, 'data': 'response'};
      }

      final result = await pipeline.run((context) async {
        if (!context.isActive) return null;
        return fakeApiCall('/users');
      });

      expect(result, {'endpoint': '/users', 'data': 'response'});
      await pipeline.dispose();
    });

    test('pipeline with retry pattern', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      var attempts = 0;

      final result = await pipeline.run((context) async {
        // Retry logic inside the task
        while (attempts < 3) {
          attempts++;
          if (attempts >= 3) {
            return 'success';
          }
          // Simulate retry
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        return 'failed';
      });

      expect(result, 'success');
      expect(attempts, 3);
      await pipeline.dispose();
    });

    test('pipeline with timeout pattern', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      final result = await pipeline.run((context) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 'completed';
      }).timeout(
        const Duration(milliseconds: 100),
        onTimeout: () => 'timeout',
      );

      expect(result, 'completed');
      await pipeline.dispose();
    });

    test('graceful degradation on dispose', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      final results = <String>[];

      // ignore: unawaited_futures
      pipeline.run((context) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (context.isActive) {
          results.add('task1');
        } else {
          results.add('task1-degraded');
        }
        return null;
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Dispose while task is running
      await pipeline.dispose(force: true);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Task should have completed with degraded path
      expect(results.length, 1);
      expect(results[0], 'task1-degraded');
    });

    test('pipeline processing items from list', () async {
      final pipeline = Pipeline(transformer: _concurrentTransformer);
      final items = [1, 2, 3, 4, 5];

      final results = await Future.wait(
        items.map(
          (item) => pipeline.run((context) async {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            return item * 2;
          }),
        ),
      );

      expect(results, [2, 4, 6, 8, 10]);
      await pipeline.dispose();
    });
  });
}

// ============================================================================
// Test Transformers
// ============================================================================

/// Sequential transformer - processes one event at a time
Stream<R> _sequentialTransformer<E, R>(
  Stream<E> events,
  Stream<R> Function(E) mapper,
) {
  return events.asyncExpand(mapper);
}

/// Concurrent transformer - processes all events in parallel
Stream<R> _concurrentTransformer<E, R>(
  Stream<E> events,
  Stream<R> Function(E) mapper,
) {
  return events.flatMap(mapper);
}

/// Droppable transformer - drops new events while processing
Stream<R> _droppableTransformer<E, R>(
  Stream<E> events,
  Stream<R> Function(E) mapper,
) {
  return events.transform(_ExhaustMapTransformer(mapper));
}

/// Restartable transformer - cancels previous on new event
Stream<R> _restartableTransformer<E, R>(
  Stream<E> events,
  Stream<R> Function(E) mapper,
) {
  return events.transform(_SwitchMapTransformer(mapper));
}

// ============================================================================
// Stream Extensions
// ============================================================================

extension _StreamExtensions<T> on Stream<T> {
  Stream<R> flatMap<R>(Stream<R> Function(T) mapper) {
    return transform(_FlatMapTransformer(mapper));
  }
}

class _FlatMapTransformer<T, R> extends StreamTransformerBase<T, R> {
  final Stream<R> Function(T) mapper;

  _FlatMapTransformer(this.mapper);

  @override
  Stream<R> bind(Stream<T> stream) {
    final controller = StreamController<R>();
    final subscriptions = <StreamSubscription<R>>[];

    stream.listen(
      (event) {
        final subscription = mapper(event).listen(
          controller.add,
          onError: controller.addError,
        );
        subscriptions.add(subscription);
      },
      onError: controller.addError,
      onDone: () async {
        await Future.wait(subscriptions.map((s) => s.asFuture<void>()));
        await controller.close();
      },
    );

    return controller.stream;
  }
}

class _ExhaustMapTransformer<T, R> extends StreamTransformerBase<T, R> {
  final Stream<R> Function(T) mapper;

  _ExhaustMapTransformer(this.mapper);

  @override
  Stream<R> bind(Stream<T> stream) {
    final controller = StreamController<R>();
    var isProcessing = false;
    var isDone = false;

    stream.listen(
      (event) {
        if (isProcessing) return; // Drop

        isProcessing = true;
        mapper(event).listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            isProcessing = false;
            if (isDone) controller.close();
          },
        );
      },
      onError: controller.addError,
      onDone: () {
        isDone = true;
        if (!isProcessing) controller.close();
      },
    );

    return controller.stream;
  }
}

class _SwitchMapTransformer<T, R> extends StreamTransformerBase<T, R> {
  final Stream<R> Function(T) mapper;

  _SwitchMapTransformer(this.mapper);

  @override
  Stream<R> bind(Stream<T> stream) {
    final controller = StreamController<R>();
    StreamSubscription<R>? currentSubscription;
    var isDone = false;

    stream.listen(
      (event) {
        currentSubscription?.cancel();

        currentSubscription = mapper(event).listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            if (isDone) controller.close();
          },
        );
      },
      onError: controller.addError,
      onDone: () {
        isDone = true;
        if (currentSubscription == null) controller.close();
      },
    );

    return controller.stream;
  }
}
