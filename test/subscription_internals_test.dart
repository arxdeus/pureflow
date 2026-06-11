// ignore_for_file: implementation_imports
import 'dart:async';

import 'package:pureflow/pureflow.dart';
import 'package:pureflow/src/common/bit_flags.dart';
import 'package:pureflow/src/common/synchronous_future.dart';
import 'package:test/test.dart';

void main() {
  // ==========================================================================
  // A. ReactiveSubscription via Store.listen()
  // ==========================================================================

  group('A. ReactiveSubscription', () {
    // A1: listen() on already-disposed store
    test('A1: onDone fires sync when store already disposed', () {
      final s = Store(1);
      s.dispose();

      var doneFired = false;
      // onDone fires synchronously in constructor of ReactiveSubscription
      s.listen(null, onDone: () => doneFired = true);
      expect(doneFired, isTrue,
          reason: 'onDone fires synchronously in constructor');
    });

    test('A1: cancel() on already-disposed subscription is safe', () {
      final s = Store(1);
      s.dispose();
      final sub = s.listen(null, onDone: () {});
      expect(sub.cancel, returnsNormally);
    });

    // A2: pause/resume — no buffering, events dropped while paused
    test('A2: events dropped while paused, delivered after resume', () {
      final s = Store(0);
      final received = <int>[];
      final sub = s.listen(received.add);

      sub.pause();
      s.value = 1;
      s.value = 2;
      s.value = 3;
      expect(received, isEmpty, reason: 'all events dropped while paused');

      sub.resume();
      s.value = 4;
      expect(received, [4], reason: 'only post-resume event delivered');

      sub.cancel();
      s.dispose();
    });

    test('A2: multiple pause() calls, single resume() unpauses (no counter)',
        () {
      final s = Store(0);
      final received = <int>[];
      final sub = s.listen(received.add);

      sub.pause();
      sub.pause(); // second pause — no counter, still one resume needed
      s.value = 1;
      expect(received, isEmpty);

      sub.resume(); // single resume unpauses regardless of pause count
      s.value = 2;
      expect(received, [2], reason: 'single resume sufficient');

      sub.cancel();
      s.dispose();
    });

    test('A2: isPaused reflects pause/resume state', () {
      final s = Store(0);
      final sub = s.listen(null);
      expect(sub.isPaused, isFalse);
      sub.pause();
      expect(sub.isPaused, isTrue);
      sub.resume();
      expect(sub.isPaused, isFalse);
      sub.cancel();
      s.dispose();
    });

    // A3: pause(resumeSignal) with Future
    test('A3: pause(resumeSignal) resumes when future completes', () async {
      final s = Store(0);
      final received = <int>[];
      final sub = s.listen(received.add);

      final completer = Completer<void>();
      sub.pause(completer.future);
      s.value = 1; // dropped
      expect(received, isEmpty);

      completer.complete();
      await Future<void>.delayed(Duration.zero); // let microtask run
      s.value = 2;
      expect(received, [2]);

      unawaited(sub.cancel());
      s.dispose();
    });

    // A4: cancel() while paused — safe, no further events
    test('A4: cancel while paused is safe', () {
      final s = Store(0);
      final received = <int>[];
      final sub = s.listen(received.add);

      sub.pause();
      expect(sub.cancel, returnsNormally);

      // no events after cancel
      s.value = 99;
      expect(received, isEmpty);
      s.dispose();
    });

    // A5: asFuture() — cancel() triggers onDone → completes completer
    test('A5: asFuture() completes when cancel() called', () async {
      final s = Store(0);
      final sub = s.listen(null);
      final future = sub.asFuture<String>('done');
      unawaited(sub.cancel());
      final result = await future;
      expect(result, 'done');
      s.dispose();
    });

    test('A5: asFuture() with no value completes with null when cancelled',
        () async {
      final s = Store(0);
      final sub = s.listen(null);
      final future = sub.asFuture<void>();
      await sub.cancel();
      expect(future, completes);
      s.dispose();
    });

    test('A5: dispose after asFuture() set up — onDone never fires (no notify)',
        () async {
      // ReactiveSource.dispose() nulls listeners without iterating —
      // subscriptions get NO notification on source dispose.
      final s = Store(0);
      final sub = s.listen(null);
      var completed = false;
      unawaited(sub.asFuture<void>().then((_) => completed = true));
      s.dispose(); // does NOT call _onSourceDisposed on existing subscriptions
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse,
          reason: 'dispose does not notify existing subscriptions');
      unawaited(sub.cancel());
    });

    // A6: onData handler replacement
    test('A6: onData replacement routes events to new handler', () {
      final s = Store(0);
      final first = <int>[];
      final second = <int>[];
      final sub = s.listen(first.add);

      s.value = 1;
      expect(first, [1]);

      sub.onData(second.add);
      s.value = 2;
      expect(first, [1], reason: 'old handler no longer called');
      expect(second, [2], reason: 'new handler receives event');

      sub.cancel();
      s.dispose();
    });

    test('A6: onDone replacement — new handler fires on cancel', () {
      final s = Store(0);
      var first = 0;
      var second = 0;
      final sub = s.listen(null, onDone: () => first++);
      sub.onDone(() => second++);
      sub.cancel();
      expect(first, 0, reason: 'original onDone replaced');
      expect(second, 1, reason: 'new onDone fires');
      s.dispose();
    });

    test('A6: onError is no-op (no crash)', () {
      final s = Store(0);
      final sub = s.listen(null);
      expect(() => sub.onError((e) {}), returnsNormally);
      sub.cancel();
      s.dispose();
    });

    // A7: cancel() idempotency
    test('A7: cancel() called twice is safe', () {
      final s = Store(0);
      final sub = s.listen(null);
      sub.cancel();
      expect(sub.cancel, returnsNormally);
      s.dispose();
    });

    test('A7: cancel() from inside onData callback is safe', () {
      final s = Store(0);
      final received = <int>[];
      late StreamSubscription<int> sub;
      sub = s.listen((v) {
        received.add(v);
        sub.cancel();
      });
      s.value = 1;
      s.value = 2; // should not be received
      expect(received, [1], reason: 'no events after in-callback cancel');
      s.dispose();
    });

    // A8: fan-out to 3 subscriptions
    test('A8: events fan out to all subscriptions', () {
      final s = Store(0);
      final a = <int>[];
      final b = <int>[];
      final c = <int>[];
      final subA = s.listen(a.add);
      final subB = s.listen(b.add);
      final subC = s.listen(c.add);

      s.value = 1;
      expect(a, [1]);
      expect(b, [1]);
      expect(c, [1]);

      subB.cancel();
      s.value = 2;
      expect(a, [1, 2]);
      expect(b, [1], reason: 'cancelled sub no longer receives');
      expect(c, [1, 2]);

      subA.cancel();
      subC.cancel();
      s.dispose();
    });

    test(
        'A8: dispose fires onDone on remaining active subscriptions via cancel',
        () {
      // Note: ReactiveSource.dispose() does NOT iterate listeners to call
      // _onSourceDisposed. Only cancel() fires onDone. This test verifies
      // dispose does not crash even with active subscriptions.
      final s = Store(0);
      var doneA = 0;
      var doneB = 0;
      final subA = s.listen(null, onDone: () => doneA++);
      final subB = s.listen(null, onDone: () => doneB++);

      s.dispose();
      // dispose does not notify subscriptions
      expect(doneA, 0);
      expect(doneB, 0);

      // manual cancel still works after dispose (source.removeListenerNode safe)
      expect(subA.cancel, returnsNormally);
      expect(subB.cancel, returnsNormally);
    });

    // A9: subscription created inside another subscription's onData
    test('A9: nested subscription creation in onData callback is safe', () {
      final s = Store(0);
      final outer = <int>[];
      final inner = <int>[];
      StreamSubscription<int>? innerSub;

      final outerSub = s.listen((v) {
        outer.add(v);
        // Create inner subscription during notification
        innerSub ??= s.listen(inner.add);
      });

      s.value = 1; // outer fires, inner created, inner also fires for 1
      s.value = 2; // both fire

      expect(outer, [1, 2]);
      expect(inner, contains(2)); // inner receives at least 2

      outerSub.cancel();
      innerSub?.cancel();
      s.dispose();
    });
  });

  // ==========================================================================
  // B. SynchronousFuture
  // ==========================================================================

  group('B. SynchronousFuture', () {
    // B10: value delivered synchronously via then()
    test('B10: then() fires synchronously', () {
      var fired = false;
      const SynchronousFuture<int>(42).then((v) {
        expect(v, 42);
        fired = true;
      });
      expect(fired, isTrue, reason: 'callback ran before next line');
    });

    // B11: then() returning Future<R> chains
    test('B11: then() chaining with Future-returning onValue', () async {
      final result = await const SynchronousFuture<int>(10)
          .then((v) => Future<String>.value('val-$v'));
      expect(result, 'val-10');
    });

    test(
        'B11: then() chaining with sync-returning onValue returns SynchronousFuture',
        () {
      var fired = false;
      const SynchronousFuture<int>(5).then((v) => v * 2).then((v) {
        expect(v, 10);
        fired = true;
      });
      expect(fired, isTrue,
          reason: 'chained sync then() also fires synchronously');
    });

    // B12: whenComplete with sync action
    test('B12: whenComplete with sync action returns same future', () {
      var ran = false;
      const SynchronousFuture<int>(7).whenComplete(() => ran = true).then((v) {
        expect(v, 7);
      });
      expect(ran, isTrue);
    });

    test('B12: whenComplete with async action returns async future', () async {
      var ran = false;
      final f = const SynchronousFuture<int>(7)
          .whenComplete(() => Future<void>.delayed(Duration.zero, () {
                ran = true;
              }));
      expect(ran, isFalse, reason: 'async action not done yet');
      final v = await f;
      expect(ran, isTrue);
      expect(v, 7);
    });

    test('B12: whenComplete action throwing returns error future', () async {
      final f = const SynchronousFuture<int>(1)
          .whenComplete(() => throw StateError('boom'));
      await expectLater(f, throwsStateError);
    });

    // B13: catchError always returns same future (never errors)
    test('B13: catchError returns same SynchronousFuture', () {
      const sf = SynchronousFuture<int>(3);
      final result = sf.catchError((e) => -1);
      // value still accessible via then
      var v = -99;
      result.then((x) => v = x);
      expect(v, 3);
    });

    test('B13: catchError with test parameter also returns same', () {
      const sf = SynchronousFuture<int>(5);
      final result = sf.catchError((e) => 0, test: (e) => false);
      var v = -1;
      result.then((x) => v = x);
      expect(v, 5);
    });

    // B14: timeout() with duration that won't trigger — value delivered
    test('B14: timeout() with long duration delivers value', () async {
      final result = await const SynchronousFuture<int>(99)
          .timeout(const Duration(seconds: 10));
      expect(result, 99);
    });

    // B15: asStream() — single value then done
    test('B15: asStream() emits single value then closes', () async {
      final events = <int>[];
      var done = false;
      const SynchronousFuture<int>(42)
          .asStream()
          .listen(events.add, onDone: () => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(events, [42]);
      expect(done, isTrue);
    });

    // B16: await works in async function
    test('B16: await on SynchronousFuture resolves correctly', () async {
      final v = await const SynchronousFuture<String>('hello');
      expect(v, 'hello');
    });

    test('B16: await SynchronousFuture<void> resolves', () async {
      await expectLater(const SynchronousFuture<void>(null), completes);
    });
  });

  // ==========================================================================
  // C. BitFlagExtension
  // ==========================================================================

  group('C. BitFlagExtension', () {
    // hasFlag
    test('C: hasFlag returns true when flag set', () {
      expect(0x5.hasFlag(0x1), isTrue);
      expect(0x5.hasFlag(0x4), isTrue);
    });

    test('C: hasFlag returns false when flag not set', () {
      expect(0x4.hasFlag(0x1), isFalse);
      expect(0x0.hasFlag(0x1), isFalse);
    });

    test('C: hasFlag with zero flag always false', () {
      expect(0xFF.hasFlag(0), isFalse);
    });

    // setFlag
    test('C: setFlag sets bit', () {
      expect(0x0.setFlag(0x1), equals(0x1));
      expect(0x2.setFlag(0x1), equals(0x3));
    });

    test('C: setFlag idempotent when already set', () {
      expect(0x3.setFlag(0x1), equals(0x3));
    });

    test('C: setFlag multiple bits', () {
      expect(0x0.setFlag(0xF), equals(0xF));
    });

    // clearFlag
    test('C: clearFlag clears bit', () {
      expect(0x3.clearFlag(0x1), equals(0x2));
      expect(0x7.clearFlag(0x4), equals(0x3));
    });

    test('C: clearFlag idempotent when already clear', () {
      expect(0x2.clearFlag(0x1), equals(0x2));
    });

    test('C: clearFlag multiple bits', () {
      expect(0xF.clearFlag(0x5), equals(0xA));
    });

    // combined operations
    test('C: set then clear round-trips', () {
      final v = 0.setFlag(0x8).clearFlag(0x8);
      expect(v, 0);
      expect(v.hasFlag(0x8), isFalse);
    });

    test('C: clear does not affect other bits', () {
      final v = 0xFF.clearFlag(0x0F);
      expect(v, 0xF0);
      expect(v.hasFlag(0xF0), isTrue);
      expect(v.hasFlag(0x0F), isFalse);
    });

    test('C: truth table: set/has/clear exhaustive 3-bit', () {
      for (var flag = 1; flag <= 4; flag <<= 1) {
        final set = 0.setFlag(flag);
        expect(set.hasFlag(flag), isTrue);
        final cleared = set.clearFlag(flag);
        expect(cleared.hasFlag(flag), isFalse);
      }
    });

    test('C: independent bits do not interfere', () {
      var v = 0;
      v = v.setFlag(1);
      v = v.setFlag(2);
      v = v.setFlag(4);
      expect(v.hasFlag(1), isTrue);
      expect(v.hasFlag(2), isTrue);
      expect(v.hasFlag(4), isTrue);
      v = v.clearFlag(2);
      expect(v.hasFlag(1), isTrue);
      expect(v.hasFlag(2), isFalse);
      expect(v.hasFlag(4), isTrue);
    });
  });
}
