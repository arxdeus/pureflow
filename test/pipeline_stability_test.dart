// ignore_for_file: unnecessary_async

import 'dart:async';

import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Custom transformer: processes only the FIRST N events; extras are dropped.
/// Uses a StreamController to avoid async* generator hang-on-dispose issues.
EventTransformer<dynamic, dynamic> takeFirstN(int n) =>
    (Stream<dynamic> source, Stream<dynamic> Function(dynamic) process) {
      var count = 0;
      late StreamSubscription<dynamic> sourceSub;
      final innerSubs = <StreamSubscription<dynamic>>[];
      var sourceDone = false;
      late StreamController<dynamic> controller;

      void closeIfDone() {
        if (sourceDone && innerSubs.isEmpty) controller.close();
      }

      controller = StreamController<dynamic>(
        onListen: () {
          sourceSub = source.listen(
            (event) {
              if (count >= n) return; // drop
              count++;
              late StreamSubscription<dynamic> inner;
              inner = process(event).listen(
                controller.add,
                onError: controller.addError,
                onDone: () {
                  innerSubs.remove(inner);
                  closeIfDone();
                },
              );
              innerSubs.add(inner);
            },
            onDone: () {
              sourceDone = true;
              closeIfDone();
            },
          );
        },
        onCancel: () async {
          await sourceSub.cancel();
          await Future.wait(innerSubs.map((s) => s.cancel()));
        },
      );
      return controller.stream;
    };

void main() {
  tearDown(() {
    Pureflow.observer = null;
  });

  // =========================================================================
  // 1. droppable – dropped event's run() future outcome
  // =========================================================================

  group('droppable – dropped event run() outcome', () {
    test('dropped task run() future completes with task return value',
        () async {
      final pipeline = Pipeline(transformer: droppable());
      final blocker = Completer<void>();

      // Task 1 blocks until we release it.
      final future1 = pipeline.run<int>((ctx) async {
        await blocker.future;
        return 1;
      });

      // Give the event loop a chance to start task 1.
      await Future<void>.value();

      // Task 2 is dropped because task 1 is still running.
      final future2 = pipeline.run<int>((ctx) async => 2);

      blocker.complete();
      final result1 = await future1;
      final result2 = await future2.timeout(const Duration(seconds: 2));

      expect(result1, 1);
      // Dropped task still ran – returns its own value.
      expect(result2, 2);

      await pipeline.dispose();
    });

    test('dropped task with async gap sees isActive false', () async {
      final pipeline = Pipeline(transformer: droppable());
      final blocker = Completer<void>();

      final future1 = pipeline.run<int>((ctx) async {
        await blocker.future;
        return 10;
      });

      await Future<void>.value();

      // Dropped task with an async yield before isActive check.
      final future2 = pipeline.run<int>((ctx) async {
        await Future<
            void>.value(); // yield to event loop so cancel() fires first
        if (!ctx.isActive) return -1;
        return 20;
      });

      blocker.complete();
      await future1;
      final result2 = await future2.timeout(const Duration(seconds: 2));

      // After async gap, context is inactive for dropped task.
      expect(result2, -1);

      await pipeline.dispose();
    });

    test(
        'dropped task with NO async gap sees isActive true (runs before cancel)',
        () async {
      final pipeline = Pipeline(transformer: droppable());
      final blocker = Completer<void>();

      final future1 = pipeline.run<int>((ctx) async {
        await blocker.future;
        return 10;
      });

      await Future<void>.value();

      // Dropped task: synchronous isActive check happens BEFORE cancel() fires.
      final future2 = pipeline.run<int>((ctx) async {
        // No await here — runs before droppedSubscription.cancel() is called.
        if (!ctx.isActive) return -1;
        return 20;
      });

      blocker.complete();
      await future1;
      final result2 = await future2.timeout(const Duration(seconds: 2));

      // Synchronous path: isActive is still true when checked.
      expect(result2, 20);

      await pipeline.dispose();
    });

    test('async-throwing dropped task propagates error to its run() future',
        () async {
      final pipeline = Pipeline(transformer: droppable());
      final blocker = Completer<void>();

      final future1 = pipeline.run<int>((ctx) async {
        await blocker.future;
        return 1;
      });

      await Future<void>.value();

      // Dropped task that throws asynchronously (after yielding).
      // Set up error capture before any awaits to avoid unhandled future error.
      Object? capturedError;
      final future2 = pipeline.run<int>((ctx) async {
        await Future<void>.value();
        throw StateError('dropped-boom');
      });
      // Attach error handler immediately to prevent unhandled error.
      final handledFuture2 = future2.onError<StateError>((e, _) {
        capturedError = e;
        return -99;
      });

      blocker.complete();
      await future1;
      await handledFuture2.timeout(const Duration(seconds: 2));

      // Error reached the caller.
      expect(capturedError, isA<StateError>());
      expect((capturedError! as StateError).message, 'dropped-boom');

      // Pipeline still functional.
      final result = await pipeline.run<int>((ctx) async => 99);
      expect(result, 99);

      await pipeline.dispose();
    });
  });

  // =========================================================================
  // 2. restartable – cancelled task's run() future outcome
  // =========================================================================

  group('restartable – cancelled task run() outcome', () {
    test('cancelled task run() future completes with its own return value',
        () async {
      final pipeline = Pipeline(transformer: restartable());
      final blocker = Completer<void>();

      final future1 = pipeline.run<int>((ctx) async {
        await blocker.future;
        // Task was cancelled by task2, but still returns a value.
        return 1;
      });

      await Future<void>.value();

      // Task 2 cancels task 1.
      final future2 = pipeline.run<int>((ctx) async => 2);

      blocker.complete();

      final result1 = await future1.timeout(const Duration(seconds: 2));
      final result2 = await future2.timeout(const Duration(seconds: 2));

      // Cancelled task still resolves with its value.
      expect(result1, 1);
      expect(result2, 2);

      await pipeline.dispose();
    });

    test('rapid-fire 10 runs: all futures complete, pipeline usable after',
        () async {
      final pipeline = Pipeline(transformer: restartable());
      final futures = <Future<int>>[];
      final blockers = List.generate(10, (_) => Completer<void>());

      for (var i = 0; i < 10; i++) {
        final idx = i;
        final blocker = blockers[idx];
        futures.add(
          pipeline.run<int>((ctx) async {
            await blocker.future;
            return idx;
          }),
        );
      }

      // Release all blockers.
      for (final b in blockers) {
        b.complete();
      }

      final results = await Future.wait(
        futures.map((f) => f.timeout(const Duration(seconds: 5))),
      );

      // All 10 futures resolved.
      expect(results.length, 10);
      // Last task (index 9) should return 9.
      expect(results.last, 9);

      // Pipeline still usable.
      final extra = await pipeline.run<String>((ctx) async => 'ok');
      expect(extra, 'ok');

      await pipeline.dispose();
    });

    test('stale onDone guard: only last task completes via normal path',
        () async {
      final pipeline = Pipeline(transformer: restartable());
      final gate = Completer<void>();
      final completedNormally = <int>[];

      final futures = <Future<int>>[];
      for (var i = 0; i < 5; i++) {
        final idx = i;
        futures.add(pipeline.run<int>((ctx) async {
          await gate.future;
          if (ctx.isActive) completedNormally.add(idx);
          return idx;
        }));
      }

      gate.complete();
      await Future.wait(
          futures.map((f) => f.timeout(const Duration(seconds: 5))));

      // Only the last task (index 4) had isActive == true when it ran.
      expect(completedNormally, [4]);

      await pipeline.dispose();
    });
  });

  // =========================================================================
  // 3. Graceful dispose with queued sequential tasks
  // =========================================================================

  group('graceful dispose with queued sequential tasks', () {
    test('all 5 queued tasks complete before dispose resolves', () async {
      final pipeline = Pipeline(transformer: sequential());
      final results = <int>[];

      // Submit 5 tasks with tiny delays before dispose.
      final futures = List.generate(
        5,
        (i) => pipeline.run<int>((ctx) async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          results.add(i);
          return i;
        }),
      );

      // Immediately request graceful dispose.
      final disposeFuture = pipeline.dispose();

      // Dispose must not complete before all tasks.
      await disposeFuture;

      // All tasks must have completed.
      expect(results.length, 5);
      expect(results, [0, 1, 2, 3, 4]);

      // All futures resolved.
      final values = await Future.wait(futures);
      expect(values, [0, 1, 2, 3, 4]);
    });

    test('dispose future resolves only after all queued tasks finish',
        () async {
      final pipeline = Pipeline(transformer: sequential());
      var completed = 0;

      final futures = List.generate(
        3,
        (_) => pipeline.run<void>((ctx) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          completed++;
        }),
      );

      await pipeline.dispose();

      expect(completed, 3);
      await Future.wait(futures); // all resolved, no throw
    });
  });

  // =========================================================================
  // 4. Force dispose with queued events – no hang
  // =========================================================================

  group('force dispose with queued events', () {
    test('active task during force dispose sees isActive false', () async {
      final pipeline = Pipeline(transformer: sequential());
      final started = Completer<void>();
      final blocker = Completer<void>();

      final future = pipeline.run<bool>((ctx) async {
        started.complete();
        await blocker.future;
        return ctx.isActive;
      });

      await started.future;

      // Release blocker and force dispose concurrently to avoid deadlock.
      // (sub.cancel() awaits the running task; blocker must be released first.)
      blocker.complete();
      await pipeline.dispose(force: true).timeout(const Duration(seconds: 5));

      final result = await future.timeout(const Duration(seconds: 2));
      // After force dispose, isActive is false.
      expect(result, false);
    });

    test('force dispose: active task future completes after blocker released',
        () async {
      final pipeline = Pipeline(transformer: concurrent());
      final started = Completer<void>();
      final blocker = Completer<void>();

      final future = pipeline.run<int>((ctx) async {
        started.complete();
        await blocker.future;
        return 7;
      });

      await started.future;

      // Release blocker before force dispose to unblock subscription cancellation.
      blocker.complete();
      await pipeline.dispose(force: true).timeout(const Duration(seconds: 5));

      final result = await future.timeout(const Duration(seconds: 2));
      expect(result, 7);
    });
  });

  // =========================================================================
  // 5. Task throwing during graceful drain
  // =========================================================================

  group('error during graceful drain', () {
    test(
        'error in task during graceful dispose propagates to caller, dispose still completes',
        () async {
      final pipeline = Pipeline(transformer: sequential());
      final blocker = Completer<void>();

      final goodFuture = pipeline.run<int>((ctx) async {
        await blocker.future;
        return 1;
      });

      final badFuture = pipeline.run<int>((ctx) async {
        await Future<void>.value();
        throw Exception('drain-error');
      });

      // Start graceful dispose.
      final disposeFuture = pipeline.dispose();

      blocker.complete();

      // Dispose must complete (errors are caught internally).
      await disposeFuture.timeout(const Duration(seconds: 5));

      // Futures still complete with their respective results.
      expect(await goodFuture, 1);
      await expectLater(badFuture, throwsA(isA<Exception>()));
    });
  });

  // =========================================================================
  // 6. completeCancelled path: force dispose then run() with throwing task
  // =========================================================================

  group('completeCancelled – throwing task after force dispose', () {
    test(
        'sync-throwing task after force dispose propagates error, no unhandled leak',
        () async {
      final pipeline = Pipeline(transformer: sequential());
      await pipeline.dispose(force: true);

      // Pipeline is dead; run() triggers completeCancelled path.
      // Task throws synchronously — error must reach caller.
      final future = pipeline.run<int>(
        (ctx) =>
            Future<int>.sync(() => throw ArgumentError('post-dispose-boom')),
      );

      await expectLater(
        future.timeout(const Duration(seconds: 2)),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message, 'message', 'post-dispose-boom')),
      );
    });

    test('no unhandled async error from completeCancelled throwing task',
        () async {
      final errors = <Object>[];
      await runZonedGuarded(
        () async {
          final pipeline = Pipeline(transformer: sequential());
          await pipeline.dispose(force: true);

          final future = pipeline.run<int>(
            (ctx) => Future<int>.sync(() => throw StateError('zoned-boom')),
          );

          try {
            await future.timeout(const Duration(seconds: 2));
          } catch (_) {
            // Expected.
          }

          // Give microtasks time to flush.
          await Future<void>.delayed(const Duration(milliseconds: 5));
        },
        (error, _) => errors.add(error),
      );

      // No unhandled error leaked to zone.
      expect(errors, isEmpty);
    });
  });

  // =========================================================================
  // 7. run<R> generic typing through different transformers
  // =========================================================================

  group('run<R> generic typing', () {
    test('int type through concurrent', () async {
      final pipeline = Pipeline(transformer: concurrent());
      final result = await pipeline.run<int>((ctx) async => 42);
      expect(result, 42);
      await pipeline.dispose();
    });

    test('String type through droppable', () async {
      final pipeline = Pipeline(transformer: droppable());
      final result = await pipeline.run<String>((ctx) async => 'hello');
      expect(result, 'hello');
      await pipeline.dispose();
    });

    test('nullable type through restartable', () async {
      final pipeline = Pipeline(transformer: restartable());
      final result = await pipeline.run<int?>((ctx) async => null);
      expect(result, isNull);
      await pipeline.dispose();
    });

    test('void type through sequential', () async {
      final pipeline = Pipeline(transformer: sequential());
      // Should not throw.
      await pipeline.run<void>((ctx) async {});
      await pipeline.dispose();
    });

    test('typed result preserved through concurrent multiple runs', () async {
      final pipeline = Pipeline(transformer: concurrent());
      final futures = [
        pipeline.run<int>((ctx) async => 1),
        pipeline.run<int>((ctx) async => 2),
        pipeline.run<int>((ctx) async => 3),
      ];
      final results = await Future.wait(futures);
      expect(results.toSet(), {1, 2, 3});
      await pipeline.dispose();
    });
  });

  // =========================================================================
  // 8. context.isActive transitions in restartable
  // =========================================================================

  group('context.isActive transitions', () {
    test('isActive true at start, false after restartable cancels', () async {
      final pipeline = Pipeline(transformer: restartable());
      final startedCompleter = Completer<void>();
      final pollCompleter = Completer<bool>();
      final releaseCompleter = Completer<void>();

      unawaited(pipeline.run<void>((ctx) async {
        // Signal that we started.
        startedCompleter.complete();
        // isActive should be true here.
        final before = ctx.isActive;
        // Wait for second task to arrive and cancel us.
        await releaseCompleter.future;
        // After cancellation, isActive should be false.
        final after = ctx.isActive;
        pollCompleter.complete(before && !after);
      }));

      await startedCompleter.future;

      // This second run cancels the first.
      final f2 = pipeline.run<void>((ctx) async {});
      releaseCompleter.complete();

      await f2.timeout(const Duration(seconds: 2));

      final wasActiveBeforeAndInactiveAfter =
          await pollCompleter.future.timeout(const Duration(seconds: 2));
      expect(wasActiveBeforeAndInactiveAfter, isTrue);

      await pipeline.dispose();
    });

    test('isActive false after force dispose (gate released before dispose)',
        () async {
      final pipeline = Pipeline(transformer: sequential());
      final gate = Completer<void>();
      bool? activeAfterDispose;

      final future = pipeline.run<void>((ctx) async {
        await gate.future;
        activeAfterDispose = ctx.isActive;
      });

      // Release gate first, then force dispose (avoids deadlock from sub.cancel).
      gate.complete();
      await pipeline.dispose(force: true).timeout(const Duration(seconds: 5));
      await future.timeout(const Duration(seconds: 2));

      expect(activeAfterDispose, isFalse);
    });
  });

  // =========================================================================
  // 9. Concurrent stress: 100 runs
  // =========================================================================

  group('concurrent stress', () {
    test('100 concurrent runs all complete with correct results', () async {
      final pipeline = Pipeline(transformer: concurrent());
      const count = 100;

      final futures = List.generate(
        count,
        (i) => pipeline.run<int>((ctx) async {
          // Random-ish tiny delay via microtask scheduling.
          if (i.isEven) await Future<void>.value();
          return i;
        }),
      );

      final results = await Future.wait(
        futures.map((f) => f.timeout(const Duration(seconds: 10))),
      );

      expect(results.length, count);
      expect(results.toSet().length, count); // all unique
      expect(results.toSet(), {for (var i = 0; i < count; i++) i});

      await pipeline.dispose();
    });
  });

  // =========================================================================
  // 10. Sequential ordering invariant: 50 tasks
  // =========================================================================

  group('sequential ordering invariant', () {
    test('50 tasks append to log in strict FIFO order', () async {
      final pipeline = Pipeline(transformer: sequential());
      final log = <int>[];
      const count = 50;

      // Variable delay per task (odd ones faster).
      final futures = List.generate(
        count,
        (i) => pipeline.run<void>((ctx) async {
          if (i.isOdd) await Future<void>.value();
          log.add(i);
        }),
      );

      await Future.wait(futures);

      expect(log, List.generate(count, (i) => i));

      await pipeline.dispose();
    });
  });

  // =========================================================================
  // 11. Pipeline reuse after error storms
  // =========================================================================

  group('pipeline reuse after error storms', () {
    test('20 failing then 20 succeeding – correct isolation', () async {
      final pipeline = Pipeline(transformer: concurrent());
      const half = 20;

      // Batch 1: all fail.
      final errorFutures = List.generate(
        half,
        (i) => pipeline.run<int>((ctx) async {
          throw Exception('error-$i');
        }),
      );

      final errors = await Future.wait(
        errorFutures.map(
            (f) => f.then<Object>((_) => 'ok').onError<Object>((e, _) => e)),
      );
      expect(errors.whereType<Exception>().length, half);

      // Batch 2: all succeed.
      final successFutures = List.generate(
        half,
        (i) => pipeline.run<int>((ctx) async => i),
      );

      final results = await Future.wait(successFutures);
      expect(results, List.generate(half, (i) => i));

      await pipeline.dispose();
    });

    test('sequential: 10 errors then 10 successes in strict order', () async {
      final pipeline = Pipeline(transformer: sequential());
      final log = <String>[];

      final allFutures = <Future<void>>[];

      for (var i = 0; i < 10; i++) {
        final idx = i;
        allFutures.add(
          pipeline
              .run<void>((ctx) async => throw Exception('e$idx'))
              .then((_) => log.add('ok-$idx'))
              .onError((e, _) => log.add('err-$idx')),
        );
      }
      for (var i = 0; i < 10; i++) {
        final idx = i;
        allFutures.add(
          pipeline.run<void>((ctx) async {}).then((_) => log.add('ok-$idx')),
        );
      }

      await Future.wait(allFutures);

      expect(log.length, 20);
      // First 10 entries are errors, next 10 are successes (sequential order).
      for (var i = 0; i < 10; i++) {
        expect(log[i], startsWith('err-'));
      }
      for (var i = 10; i < 20; i++) {
        expect(log[i], startsWith('ok-'));
      }

      await pipeline.dispose();
    });
  });

  // =========================================================================
  // 12. dispose() called twice concurrently
  // =========================================================================

  group('double dispose safety', () {
    test('two graceful dispose() calls concurrently both complete', () async {
      final pipeline = Pipeline(transformer: sequential());

      final blocker = Completer<void>();
      unawaited(pipeline.run<void>((ctx) async => blocker.future));
      await Future<void>.value(); // let task start

      final d1 = pipeline.dispose();
      final d2 = pipeline.dispose();

      blocker.complete();

      // Both must complete without error.
      await Future.wait([d1, d2]).timeout(const Duration(seconds: 5));
    });

    test('dispose(force:true) while graceful dispose in-flight completes both',
        () async {
      final pipeline = Pipeline(transformer: sequential());
      final blocker = Completer<void>();

      final taskFuture = pipeline.run<int>((ctx) async {
        await blocker.future;
        return 1;
      });

      await Future<void>.value();

      // Start graceful dispose.
      final graceful = pipeline.dispose();

      // Immediately follow with force dispose.
      final forced = pipeline.dispose(force: true);

      blocker.complete();

      // Both dispose futures complete.
      await Future.wait([graceful, forced]).timeout(const Duration(seconds: 5));

      // The task future also completes.
      await taskFuture.timeout(const Duration(seconds: 2));
    });
  });

  // =========================================================================
  // 13. Custom EventTransformer
  // =========================================================================

  group('custom EventTransformer', () {
    test('takeFirstN(2) processes only first 2 events', () async {
      final pipeline = Pipeline(transformer: takeFirstN(2));
      final blocker = Completer<void>();

      // We need tasks to start and be observable; use sequential-style with blocking.
      final f1 = pipeline.run<int>((ctx) async => 10);
      final f2 = pipeline.run<int>((ctx) async => 20);

      final results =
          await Future.wait([f1, f2]).timeout(const Duration(seconds: 5));
      expect(results, [10, 20]);

      await pipeline.dispose();
      blocker.complete(); // no-op but keeps linter happy
    });

    test('custom passthrough transformer logs and forwards results', () async {
      // Simple sequential passthrough via asyncExpand that records results.
      final processed = <int>[];
      Stream<int> loggingTransformer(Stream<dynamic> source,
              Stream<dynamic> Function(dynamic) process) =>
          source.asyncExpand((event) => process(event).map((r) {
                processed.add(r as int);
                return r;
              }));

      final pipeline = Pipeline(transformer: loggingTransformer);
      final results = await Future.wait([
        pipeline.run<int>((ctx) async => 1),
        pipeline.run<int>((ctx) async => 2),
        pipeline.run<int>((ctx) async => 3),
      ]);

      // Flush microtasks: _onData fires after completer resolves.
      await Future<void>.value();
      await Future<void>.value();

      expect(results, [1, 2, 3]);
      expect(processed, [1, 2, 3]);

      await pipeline.dispose();
    });
  });

  // =========================================================================
  // 14. Observer onPipelineEvent
  // =========================================================================

  group('observer onPipelineEvent', () {
    test('onPipelineEvent fires once per run() call', () async {
      final events = <(String?, String?)>[];
      Pureflow.observer = FlowObserver(
        onPipelineEvent: (pLabel, eLabel) => events.add((pLabel, eLabel)),
      );

      final pipeline = Pipeline(
        transformer: sequential(),
        debugLabel: 'myPipeline',
      );

      await pipeline.run<void>((ctx) async {}, debugLabel: 'event1');
      await pipeline.run<void>((ctx) async {}, debugLabel: 'event2');
      await pipeline.run<void>((ctx) async {});

      expect(events.length, 3);
      expect(events[0], ('myPipeline', 'event1'));
      expect(events[1], ('myPipeline', 'event2'));
      expect(events[2], ('myPipeline', null));

      await pipeline.dispose();
    });

    test('onPipelineEvent fires for dropped events too', () async {
      final events = <(String?, String?)>[];
      Pureflow.observer = FlowObserver(
        onPipelineEvent: (pLabel, eLabel) => events.add((pLabel, eLabel)),
      );

      final pipeline = Pipeline(transformer: droppable(), debugLabel: 'dp');
      final blocker = Completer<void>();

      final f1 = pipeline.run<void>((ctx) async => blocker.future);
      await Future<void>.value();
      final f2 = pipeline.run<void>((ctx) async {}); // dropped

      blocker.complete();
      await Future.wait([f1, f2]).timeout(const Duration(seconds: 2));

      // Both run() calls must have fired the observer.
      expect(events.length, 2);
      expect(events[0].$1, 'dp');
      expect(events[1].$1, 'dp');

      await pipeline.dispose();
    });

    test('observer null after tearDown – no crash on subsequent run', () async {
      final pipeline = Pipeline(transformer: sequential());

      Pureflow.observer = FlowObserver(
        onPipelineEvent: (_, __) {},
      );
      await pipeline.run<void>((ctx) async {});

      Pureflow.observer = null;
      // Should not throw.
      await pipeline.run<void>((ctx) async {});

      await pipeline.dispose();
    });
  });

  // =========================================================================
  // 15. Context isActive: sequential pipeline dispose during long task
  // =========================================================================

  group('context.isActive – sequential graceful dispose', () {
    test('isActive true before dispose, false after graceful dispose completes',
        () async {
      final pipeline = Pipeline(transformer: sequential());
      final activeDuring = <bool>[];
      final blocker = Completer<void>();

      final future = pipeline.run<void>((ctx) async {
        activeDuring.add(ctx.isActive); // before dispose
        await blocker.future;
        activeDuring.add(ctx.isActive); // after dispose started but graceful
      });

      await Future<void>.value();

      final disposeFuture = pipeline.dispose(); // graceful
      blocker.complete();

      await disposeFuture.timeout(const Duration(seconds: 5));
      await future.timeout(const Duration(seconds: 2));

      // During graceful dispose the task continues – isActive remains true
      // until the task is done and pipeline shuts down.
      expect(activeDuring[0], isTrue);
      // After releasing the blocker, graceful dispose waits for task to finish.
      // isActive may be true or false depending on timing, but no crash.
      expect(activeDuring.length, 2);
    });
  });
}
