// ignore_for_file: unawaited_futures, invalid_use_of_internal_member, cancel_subscriptions, implementation_imports
import 'dart:async';

import 'package:pureflow/pureflow.dart';
import 'package:pureflow/src/internal/pipeline/single_event_stream.dart';
import 'package:pureflow/src/internal/pipeline/source_stream.dart';
import 'package:pureflow/src/internal/pipeline/task_stream.dart';
import 'package:test/test.dart';

void main() {
  // ==========================================================================
  // D. Transformer onPause/onResume and synchronous-throw catch paths
  // ==========================================================================

  group('D. concurrent() transformer', () {
    test('D1: onPause/onResume called while inner subscriptions active',
        () async {
      final transformer = concurrent<String, String>();
      final sourceController = StreamController<String>();

      final innerMayComplete = Completer<void>();
      final results = <String>[];
      final errors = <Object>[];

      final resultStream = transformer(
        sourceController.stream,
        (event) => Stream<String>.fromFuture(
          innerMayComplete.future.then((_) => event),
        ),
      );

      final sub = resultStream.listen(
        results.add,
        onError: errors.add,
        cancelOnError: false,
      );

      // Send event so an inner subscription is active
      sourceController.add('hello');
      await Future<void>.delayed(Duration.zero);

      // Pause outer stream — exercises onPause which pauses innerSubscriptions
      sub.pause();
      await Future<void>.delayed(Duration.zero);

      // Resume — exercises onResume
      sub.resume();

      // Let the inner task complete
      innerMayComplete.complete();
      await Future<void>.delayed(Duration.zero);

      expect(results, ['hello']);
      expect(errors, isEmpty);

      await sub.cancel();
      await sourceController.close();
    });

    test('D2: process throws synchronously — error propagated via stream',
        () async {
      final transformer = concurrent<String, String>();
      final sourceController = StreamController<String>();
      final errors = <Object>[];

      final resultStream = transformer(
        sourceController.stream,
        (event) => throw StateError('boom-concurrent'),
      );

      final sub = resultStream.listen(
        null,
        onError: errors.add,
        cancelOnError: false,
      );

      sourceController.add('trigger');
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.first, isA<StateError>());

      await sub.cancel();
      await sourceController.close();
    });
  });

  group('D. droppable() transformer', () {
    test('D3: onPause/onResume called while inner subscription active',
        () async {
      final transformer = droppable<String, String>();
      final sourceController = StreamController<String>();

      final innerMayComplete = Completer<void>();
      final results = <String>[];
      final errors = <Object>[];

      final resultStream = transformer(
        sourceController.stream,
        (event) => Stream<String>.fromFuture(
          innerMayComplete.future.then((_) => event),
        ),
      );

      final sub = resultStream.listen(
        results.add,
        onError: errors.add,
        cancelOnError: false,
      );

      sourceController.add('first');
      await Future<void>.delayed(Duration.zero);

      // Pause while inner subscription is active → exercises onPause (droppable)
      sub.pause();
      await Future<void>.delayed(Duration.zero);
      sub.resume();

      innerMayComplete.complete();
      await Future<void>.delayed(Duration.zero);

      expect(results, ['first']);
      expect(errors, isEmpty);

      await sub.cancel();
      await sourceController.close();
    });

    test('D4: process throws on second event (inner active) — error propagated',
        () async {
      final transformer = droppable<String, String>();
      final sourceController = StreamController<String>();

      final firstCompleter = Completer<void>();
      final errors = <Object>[];
      var callCount = 0;

      final resultStream = transformer(
        sourceController.stream,
        (event) {
          callCount++;
          if (callCount == 1) {
            // First event: long stream (keeps innerSubscription active)
            return Stream<String>.fromFuture(
              firstCompleter.future.then((_) => event),
            );
          }
          // Second event while inner active: throws synchronously
          throw StateError('boom-droppable');
        },
      );

      final sub = resultStream.listen(
        null,
        onError: errors.add,
        cancelOnError: false,
      );

      // Send first event — starts inner subscription
      sourceController.add('first');
      await Future<void>.delayed(Duration.zero);

      // Send second event while inner active — process throws → catch block (line 93-94)
      sourceController.add('second');
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.first, isA<StateError>());

      firstCompleter.complete();
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();
      await sourceController.close();
    });
  });

  group('D. restartable() transformer', () {
    test('D5: onPause/onResume called while inner subscription active',
        () async {
      final transformer = restartable<String, String>();
      final sourceController = StreamController<String>();

      final innerMayComplete = Completer<void>();
      final results = <String>[];

      final resultStream = transformer(
        sourceController.stream,
        (event) => Stream<String>.fromFuture(
          innerMayComplete.future.then((_) => event),
        ),
      );

      final sub = resultStream.listen(results.add);

      sourceController.add('first');
      await Future<void>.delayed(Duration.zero);

      // Pause → exercises onPause (restartable)
      sub.pause();
      await Future<void>.delayed(Duration.zero);
      // Resume → exercises onResume
      sub.resume();

      innerMayComplete.complete();
      await Future<void>.delayed(Duration.zero);

      expect(results, ['first']);

      await sub.cancel();
      await sourceController.close();
    });

    test('D6: process throws synchronously — error propagated via stream',
        () async {
      final transformer = restartable<String, String>();
      final sourceController = StreamController<String>();
      final errors = <Object>[];

      final resultStream = transformer(
        sourceController.stream,
        (event) => throw StateError('boom-restartable'),
      );

      final sub = resultStream.listen(
        null,
        onError: errors.add,
        cancelOnError: false,
      );

      sourceController.add('trigger');
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.first, isA<StateError>());

      await sub.cancel();
      await sourceController.close();
    });
  });

  // ==========================================================================
  // E. SinglePipelineEventSubscription internals
  // ==========================================================================

  group('E. SinglePipelineEventSubscription', () {
    /// Helper: create a TaskStream + PipelineEventContext + subscription
    /// for testing internal paths.
    ({
      TaskStream taskStream,
      SinglePipelineEventSubscription sub,
      Future<dynamic> result,
    }) makeSubscription({
      required Future<dynamic> Function(PipelineEventContext ctx) task,
      void Function(dynamic)? onData,
      void Function()? onDone,
    }) {
      final taskStream = TaskStream(transformer: sequential());
      final completer = Completer<dynamic>();
      final ctx = PipelineEventContext(
        task: task,
        completer: completer,
        taskStream: taskStream,
      );
      final sub = SinglePipelineEventSubscription(
        ctx,
        (_) {}, // onStreamClosed no-op
        onData,
        onDone,
      );
      return (taskStream: taskStream, sub: sub, result: completer.future);
    }

    test('E1: cancel() when already canceled is safe (idempotent)', () async {
      final r = makeSubscription(
        task: (ctx) async => 42,
      );
      // Wait for task to complete first
      await r.result.catchError((_) => null);
      await Future<void>.delayed(Duration.zero);

      r.sub.cancel();
      // Second cancel should return normally
      expect(r.sub.cancel, returnsNormally);
      await r.taskStream.dispose(force: true);
    });

    test('E2: onData setter replaces data handler', () async {
      final received = <dynamic>[];
      final received2 = <dynamic>[];

      final r = makeSubscription(
        task: (ctx) async => 99,
        onData: received.add,
      );

      // Replace onData before task completes
      r.sub.onData(received2.add);

      await r.result;
      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty, reason: 'old handler replaced');
      expect(received2, [99], reason: 'new handler received value');
      await r.taskStream.dispose(force: true);
    });

    test('E3: onError setter is no-op (does not crash)', () async {
      final r = makeSubscription(task: (ctx) async => 1);
      expect(() => r.sub.onError((e, s) {}), returnsNormally);
      await r.result;
      await r.taskStream.dispose(force: true);
    });

    test('E4: onDone setter replaces done handler', () async {
      var oldFired = 0;
      var newFired = 0;

      final r = makeSubscription(
        task: (ctx) async => 7,
        onDone: () => oldFired++,
      );

      r.sub.onDone(() => newFired++);

      await r.result;
      await Future<void>.delayed(Duration.zero);

      expect(oldFired, 0, reason: 'old onDone was replaced');
      expect(newFired, 1, reason: 'new onDone fired');
      await r.taskStream.dispose(force: true);
    });

    test('E5: isPaused reflects pause/resume state', () async {
      final r = makeSubscription(task: (ctx) async {
        // Long task so we can observe pause state
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return null;
      });

      expect(r.sub.isPaused, isFalse);
      r.sub.pause();
      expect(r.sub.isPaused, isTrue);
      r.sub.resume();
      expect(r.sub.isPaused, isFalse);

      await r.result;
      await r.taskStream.dispose(force: true);
    });

    test('E6: pause then resume — resumeCompleter await path exercised',
        () async {
      final data = <dynamic>[];
      final doneCalled = <bool>[];

      final r = makeSubscription(
        task: (ctx) async => 'value',
        onData: data.add,
        onDone: () => doneCalled.add(true),
      );

      // Pause the subscription before the task's result is delivered
      r.sub.pause();

      // Wait for task to complete (it will block in _completeWithResult
      // waiting for resumeCompleter since we're paused)
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Data not yet delivered (still paused)
      expect(data, isEmpty);

      // Resume — triggers _completeResumeCompleter → data/done delivered
      r.sub.resume();

      await Future<void>.delayed(Duration.zero);

      expect(data, ['value']);
      expect(doneCalled, [true]);
      await r.taskStream.dispose(force: true);
    });

    test('E7: asFuture() success — called before completion', () async {
      final r = makeSubscription(task: (ctx) async => 'result');

      final f = r.sub.asFuture<String>('futureValue');
      await r.result;
      await Future<void>.delayed(Duration.zero);

      final v = await f;
      expect(v, 'futureValue');
      await r.taskStream.dispose(force: true);
    });

    test(
        'E8: asFuture() success — called after completion (already-done branch)',
        () async {
      final r = makeSubscription(task: (ctx) async => 'done');

      await r.result;
      await Future<void>.delayed(Duration.zero);

      // Call asFuture AFTER the subscription has already completed
      // This hits the asFutureCompletedBit branch (lines 239-244)
      final f = r.sub.asFuture<String>('afterValue');
      final v = await f;
      expect(v, 'afterValue');
      await r.taskStream.dispose(force: true);
    });

    test('E9: asFuture() error — called before completion (task throws)',
        () async {
      final r = makeSubscription(
        task: (ctx) async => throw StateError('task-error'),
      );

      final f = r.sub.asFuture<void>();

      // Swallow completer error
      r.result.catchError((_) => null);

      await Future<void>.delayed(Duration.zero);

      await expectLater(f, throwsA(isA<StateError>()));
      await r.taskStream.dispose(force: true);
    });

    test(
        'E10: asFuture() error — already completed with error (after-done branch)',
        () async {
      final r = makeSubscription(
        task: (ctx) async => throw StateError('task-error-2'),
      );

      r.result.catchError((_) => null);
      await Future<void>.delayed(Duration.zero);

      // Now call asFuture after completion — hits lines 241-242
      final f = r.sub.asFuture<void>();
      await expectLater(f, throwsA(isA<StateError>()));
      await r.taskStream.dispose(force: true);
    });

    test('E11: pause with resumeSignal future auto-resumes', () async {
      final data = <dynamic>[];

      final r = makeSubscription(
        task: (ctx) async => 'sig-value',
        onData: data.add,
      );

      final signal = Completer<void>();
      r.sub.pause(signal.future);

      await Future<void>.delayed(Duration.zero);

      signal.complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(data, ['sig-value']);
      await r.taskStream.dispose(force: true);
    });

    test('E12: pause when already paused+canceled is no-op', () async {
      final r = makeSubscription(task: (ctx) async => null);

      r.sub.cancel(); // sets canceledBit
      // pause when canceledBit set → early return (line 211)
      expect(r.sub.pause, returnsNormally);

      await r.result.catchError((_) => null);
      await r.taskStream.dispose(force: true);
    });

    test('E13: resume when not paused is no-op', () async {
      final r = makeSubscription(task: (ctx) async => null);
      // Not paused — resume should be no-op
      expect(r.sub.resume, returnsNormally);
      await r.result;
      await r.taskStream.dispose(force: true);
    });
  });

  // ==========================================================================
  // F. SourceStreamSubscription internals
  // ==========================================================================

  group('F. SourceStreamSubscription', () {
    TaskStream makeTaskStream() => TaskStream(transformer: sequential());

    test('F1: pause sets isPaused; resume clears it', () {
      final ts = makeTaskStream();
      final sub = SourceStreamSubscription(ts, null, null);

      expect(sub.isPaused, isFalse);
      sub.pause();
      expect(sub.isPaused, isTrue);
      sub.resume();
      expect(sub.isPaused, isFalse);

      sub.cancel();
      ts.dispose(force: true);
    });

    test('F2: pause when already paused is no-op', () {
      final ts = makeTaskStream();
      final sub = SourceStreamSubscription(ts, null, null);

      sub.pause();
      expect(sub.isPaused, isTrue);
      sub.pause(); // second pause — idempotent for SourceStreamSubscription
      expect(sub.isPaused, isTrue);

      sub.resume();
      sub.cancel();
      ts.dispose(force: true);
    });

    test('F3: resume when not paused is no-op', () {
      final ts = makeTaskStream();
      final sub = SourceStreamSubscription(ts, null, null);

      expect(sub.resume, returnsNormally);
      expect(sub.isPaused, isFalse);

      sub.cancel();
      ts.dispose(force: true);
    });

    test('F4: pause with resumeSignal future auto-resumes', () async {
      final ts = makeTaskStream();
      final sub = SourceStreamSubscription(ts, null, null);

      final signal = Completer<void>();
      sub.pause(signal.future);
      expect(sub.isPaused, isTrue);

      signal.complete();
      await Future<void>.delayed(Duration.zero);
      expect(sub.isPaused, isFalse);

      sub.cancel();
      ts.dispose(force: true);
    });

    test('F5: onData setter replaces handler', () async {
      final ts = makeTaskStream();
      final received1 = <dynamic>[];
      final received2 = <dynamic>[];

      final sub = SourceStreamSubscription(ts, received1.add, null);
      sub.onData(received2.add);

      // Add an event to the queue and trigger processing
      final completer = Completer<dynamic>();
      final ctx = PipelineEventContext(
        task: (ctx) async => 'test',
        completer: completer,
        taskStream: ts,
      );
      ts.add(ctx);
      await completer.future.catchError((_) => null);
      await Future<void>.delayed(Duration.zero);

      // The source stream emits the ctx object — received by new handler only
      expect(received1, isEmpty, reason: 'old handler was replaced');
      expect(received2, isNotEmpty, reason: 'new handler received event');

      sub.cancel();
      await ts.dispose(force: true);
    });

    test('F6: onError setter is no-op (does not crash)', () {
      final ts = makeTaskStream();
      final sub = SourceStreamSubscription(ts, null, null);
      expect(() => sub.onError(null), returnsNormally);
      sub.cancel();
      ts.dispose(force: true);
    });

    test('F7: onDone setter replaces handler', () async {
      var oldFired = 0;
      var newFired = 0;

      final ts = makeTaskStream();
      final sub = SourceStreamSubscription(ts, null, () => oldFired++);
      sub.onDone(() => newFired++);

      await ts.dispose(); // triggers done

      await Future<void>.delayed(Duration.zero);

      expect(oldFired, 0, reason: 'old onDone was replaced');
      expect(newFired, 1, reason: 'new onDone fired');
      sub.cancel();
    });

    test('F8: asFuture() completes when source stream closes', () async {
      final ts = makeTaskStream();
      final sub = SourceStreamSubscription(ts, null, null);

      final f = sub.asFuture<String>('done');

      await ts.dispose();
      await Future<void>.delayed(Duration.zero);

      final v = await f;
      expect(v, 'done');
      sub.cancel();
    });

    test('F9: cancel when already canceled returns sync future safely', () {
      final ts = makeTaskStream();
      final sub = SourceStreamSubscription(ts, null, null);

      sub.cancel();
      expect(sub.cancel, returnsNormally);
      ts.dispose(force: true);
    });
  });
}
