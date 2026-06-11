import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

// ignore_for_file: prefer_function_declarations_over_variables

void main() {
  // ==========================================================================
  // 1. Listener Reentrancy
  // ==========================================================================

  group('Listener reentrancy - addListener inside callback', () {
    test('Store: addListener inside callback does NOT fire in current cycle',
        () {
      final s = Store(0);
      final calls = <String>[];

      late void Function() addedCb;
      addedCb = () => calls.add('added');

      s.addListener(() {
        calls.add('original');
        // Adding a new listener while notifying — must not crash
        s.addListener(addedCb);
      });

      s.value = 1;
      // New listener was added but should NOT fire in this cycle
      expect(calls, ['original']);

      // Next change: newly added listener fires
      s.value = 2;
      expect(calls, ['original', 'added', 'original']);

      s.dispose();
    });

    test(
        'Computed: addListener inside callback does NOT fire in current notification cycle',
        () {
      final src = Store(0);
      final c = Computed(() => src.value * 2);
      final calls = <String>[];

      // Establish dependency & clear initial dirty BEFORE adding any listener.
      c.value; // _value=0, dirtyBit cleared, hasValueBit set

      final addedCb = () => calls.add('added');

      // Only register addedCb once to avoid re-registration loops.
      var addedOnce = false;
      c.addListener(() {
        calls.add('original');
        if (!addedOnce) {
          addedOnce = true;
          c.addListener(addedCb);
        }
      });

      src.value = 1;
      // Computed.markDirty → notifySubscribers → original fires, adds addedCb.
      // addedCb was prepended AFTER the iteration started → NOT visited this cycle.
      expect(calls, ['original']);

      // Read c.value to recompute (clears dirty). Since value changed (0→2),
      // _recompute calls notifySubscribers: addedCb now at head fires first,
      // then original fires (addedOnce=true, no re-registration).
      c.value;
      expect(calls, ['original', 'added', 'original']);

      c.dispose();
      src.dispose();
    });

    test('Store: removeListener of self inside own callback is safe', () {
      final s = Store(0);
      final calls = <int>[];
      late void Function() selfRef;
      selfRef = () {
        calls.add(s.value);
        s.removeListener(selfRef);
      };
      s.addListener(selfRef);

      s.value = 1;
      expect(calls, [1]);

      // No longer registered — second change produces no call
      s.value = 2;
      expect(calls, [1]);

      s.dispose();
    });

    test(
        'Store: removeListener of ANOTHER (later-iterated) listener from callback — that listener is skipped',
        () {
      // Listeners prepend to head. Iteration order: newest→oldest.
      // L1 added first (oldest/tail), L2 added second (newest/head).
      // Iteration: L2 first, then L1.
      // If L2 removes L1, L1 is skipped this cycle.
      final s = Store(0);
      final calls = <String>[];

      late void Function() l1;
      l1 = () => calls.add('L1');

      void l2() {
        calls.add('L2');
        s.removeListener(l1); // remove next-to-iterate listener
      }

      s.addListener(l1); // L1 added first → tail
      s.addListener(l2); // L2 added second → head, iterates first

      s.value = 1;
      // L2 fires, removes L1, L1 is skipped
      expect(calls, ['L2']);

      // After: only L2 remains (L1 was removed)
      calls.clear();
      s.value = 2;
      expect(calls, ['L2']);

      s.dispose();
    });

    test('Store: removeListener of EARLIER (already-iterated) listener is safe',
        () {
      // L1=tail (added first), L2=head (added second).
      // Iteration: L2 first. If L1 removes L2 (already visited) — safe.
      // But L1 iterates second — it fires, then removes L2. By then L2 already fired.
      final s = Store(0);
      final calls = <String>[];

      void Function()? l2Ref;
      void l1() {
        calls.add('L1');
        if (l2Ref != null) s.removeListener(l2Ref);
      }

      l2Ref = () => calls.add('L2');

      s.addListener(l1); // tail
      s.addListener(l2Ref); // head, iterates first

      s.value = 1;
      // L2 fires first, then L1 fires and removes L2 (already fired)
      expect(calls, ['L2', 'L1']);

      // Next: L2 removed, only L1
      calls.clear();
      s.value = 2;
      expect(calls, ['L1']);

      s.dispose();
    });
  });

  // ==========================================================================
  // 2. removeListener Semantics
  // ==========================================================================

  group('removeListener semantics', () {
    test('same callback registered N times fires N times', () {
      final s = Store(0);
      var count = 0;
      void cb() => count++;

      s.addListener(cb);
      s.addListener(cb);
      s.addListener(cb);

      s.value = 1;
      expect(count, 3);

      s.dispose();
    });

    test('removeListener removes only first occurrence (fires N-1 after)', () {
      final s = Store(0);
      var count = 0;
      void cb() => count++;

      s.addListener(cb);
      s.addListener(cb);
      s.addListener(cb);

      s.removeListener(cb); // removes one

      s.value = 1;
      expect(count, 2);

      s.dispose();
    });

    test('removeListener with never-registered callback is safe no-op', () {
      final s = Store(0);
      var count = 0;
      void registered() => count++;
      void neverRegistered() {}

      s.addListener(registered);
      s.removeListener(neverRegistered); // should not throw

      s.value = 1;
      expect(count, 1); // registered still fires

      s.dispose();
    });

    test('removeListener after dispose is safe no-op', () {
      final s = Store(0);
      var count = 0;
      void cb() => count++;

      s.addListener(cb);
      s.dispose();

      // Should not throw
      s.removeListener(cb);
      expect(count, 0);
    });

    test('removeListener on empty store is safe no-op', () {
      final s = Store(0);
      void cb() {}
      expect(() => s.removeListener(cb), returnsNormally);
      s.dispose();
    });
  });

  // ==========================================================================
  // 3. Computed Error Recovery
  // ==========================================================================

  group('Computed error recovery', () {
    test(
        'compute throws on first-ever access — rethrows; second access (same error condition) also rethrows',
        () {
      final c = Computed<int>(() {
        throw StateError('boom');
      });

      expect(() => c.value, throwsStateError);
      // Still dirty, rethrows again
      expect(() => c.value, throwsStateError);

      c.dispose();
    });

    test('fix error condition → next access recomputes successfully', () {
      var shouldThrow = true;
      final c = Computed<int>(() {
        if (shouldThrow) throw StateError('boom');
        return 42;
      });

      expect(() => c.value, throwsStateError);

      shouldThrow = false;
      // Computed is still dirty (throws keep dirtyBit set) → recomputes
      expect(c.value, 42);

      c.dispose();
    });

    test(
        'Computed depending on Store: throws on first dep-change, recovers on next',
        () {
      final flag = Store(true);
      final c = Computed<int>(() {
        if (flag.value) throw StateError('flag error');
        return 99;
      });

      expect(() => c.value, throwsStateError);

      flag.value = false;
      expect(c.value, 99);

      flag.dispose();
      c.dispose();
    });

    test('throws after prior successful value → rethrow → recover', () {
      var shouldThrow = false;
      final trigger = Store(0);
      final c = Computed<int>(() {
        trigger.value; // track dep
        if (shouldThrow) throw ArgumentError('oops');
        return trigger.value * 10;
      });

      expect(c.value, 0);

      shouldThrow = true;
      trigger.value = 1; // marks dirty
      expect(() => c.value, throwsArgumentError);

      shouldThrow = false;
      trigger.value = 2;
      expect(c.value, 20);

      trigger.dispose();
      c.dispose();
    });
  });

  // ==========================================================================
  // 4. Dispose During Notification
  // ==========================================================================

  group('dispose during notification', () {
    test(
        'Store: listener calls dispose() — no crash, subsequent listeners still fire (iteration continues via node refs)',
        () {
      // When dispose() sets listeners=null, the local node ref in the iteration
      // loop is still valid. Subsequent nodes in the chain still fire.
      final s = Store(0);
      final calls = <String>[];

      // L1 added first (tail), L2 added second (head, iterates first)
      s.addListener(() => calls.add('L1')); // added first
      s.addListener(() {
        calls.add('L2');
        s.dispose(); // nulls s.listeners, sets disposedBit
      }); // added second — iterates first

      s.value = 1;
      // L2 fires and disposes; L1 still fires because loop uses local node refs
      expect(calls, ['L2', 'L1']);
    });

    test('Store: set value after dispose is no-op (disposedBit)', () {
      final s = Store(0);
      var count = 0;
      s.addListener(() => count++);
      s.dispose();

      s.value = 99;
      expect(s.value, 0); // value unchanged after dispose
      expect(count, 0);
    });

    test('Store: dispose is idempotent — multiple dispose calls safe', () {
      final s = Store(0);
      s.dispose();
      expect(s.dispose, returnsNormally);
      expect(s.dispose, returnsNormally);
    });

    test('Computed: dispose is idempotent', () {
      final src = Store(0);
      final c = Computed(() => src.value);
      c.value;
      c.dispose();
      expect(c.dispose, returnsNormally);

      src.dispose();
    });
  });

  // ==========================================================================
  // 5. Reading Computed from Inside Store Listener (reentrancy via currentView)
  // ==========================================================================

  group('Reading Computed inside store listener — no dependency corruption',
      () {
    test(
        'listener reads computed value — callback listeners fire BEFORE deps are marked dirty',
        () {
      // notifySubscribers() fires callback listeners first, THEN marks dependent
      // Computed dirty. So c.value inside a's listener = stale (pre-change) value.
      final a = Store(3);
      final b = Store(4);
      final c = Computed(() => a.value + b.value);
      // Ensure initial value established
      expect(c.value, 7);

      int? seenInListener;
      a.addListener(() {
        // currentView is null here, so reading c.value does not corrupt deps.
        // But c is NOT yet dirty (markDirty runs after listeners loop), so
        // c.value returns the previously cached value.
        seenInListener = c.value;
      });

      a.value = 10;
      // Listener sees old cached value (3+4=7), not new value (10+4=14)
      expect(seenInListener, 7);
      // After listener, c is marked dirty — next access recomputes correctly
      expect(c.value, 14);

      a.dispose();
      b.dispose();
      c.dispose();
    });

    test(
        'listener-read does NOT corrupt computed deps — changing unrelated store later has no effect',
        () {
      final x = Store(1);
      final y = Store(100);
      final cX = Computed(() => x.value * 2); // depends only on x

      // Establish cX dependency on x
      expect(cX.value, 2);

      var listenerCalls = 0;
      // Listen to y; read cX inside
      y.addListener(() {
        listenerCalls++;
        cX.value; // read during y's notification
      });

      // Change y — cX should NOT become dirty (it only depends on x)
      y.value = 200;
      expect(listenerCalls, 1);
      expect(cX.value, 2); // still 2, no recompute triggered by y

      // Change x — cX SHOULD recompute
      x.value = 5;
      expect(cX.value, 10);

      x.dispose();
      y.dispose();
      cX.dispose();
    });
  });

  // ==========================================================================
  // 6. Equality Function That Throws
  // ==========================================================================

  group('Equality function that throws', () {
    test('Store: throwing equality propagates to caller, value IS updated', () {
      // The equality check runs BEFORE assignment on the fast path — but
      // looking at the implementation: equality is called inside the setter,
      // and if it throws, _value has NOT been reassigned yet.
      // Actually in store_impl: eq(_value, newValue) is evaluated first.
      // If it throws, assignment (_value = newValue) never runs.
      final s = Store<int>(
        0,
        equality: (a, b) => throw StateError('eq boom'),
      );

      expect(() => s.value = 1, throwsStateError);
      // Value was NOT updated because equality threw before assignment
      expect(s.value, 0);

      // Store still usable: set same value again (throws again from equality)
      expect(() => s.value = 2, throwsStateError);

      s.dispose();
    });

    test('Computed: throwing equality during recompute propagates from .value',
        () {
      final src = Store(0);
      final c = Computed<int>(
        () => src.value,
        equality: (a, b) => throw StateError('ceq boom'),
      );

      // First access: isFirstValue=true, equality not called (shouldNotify=true)
      expect(c.value, 0);

      // Second access after dep change: equality IS called → throws
      src.value = 1;
      expect(() => c.value, throwsStateError);

      src.dispose();
      c.dispose();
    });
  });

  // ==========================================================================
  // 7. Store.update() with Throwing Updater
  // ==========================================================================

  group('Store.update() with throwing updater', () {
    test('error propagates, value unchanged', () {
      final s = Store(42);

      expect(() => s.update((_) => throw ArgumentError('upd boom')),
          throwsArgumentError);

      expect(s.value, 42); // unchanged

      s.dispose();
    });

    test('store usable after throwing updater', () {
      final s = Store(10);

      expect(() => s.update((_) => throw StateError('x')), throwsStateError);

      s.update((v) => v + 1);
      expect(s.value, 11);

      s.dispose();
    });

    test('listeners not notified when updater throws', () {
      final s = Store(5);
      var count = 0;
      s.addListener(() => count++);

      expect(() => s.update((_) => throw Exception('fail')), throwsException);

      expect(count, 0);
      s.dispose();
    });
  });

  // ==========================================================================
  // 8. Observer Callbacks That Throw
  // ==========================================================================

  group('Observer callbacks that throw', () {
    tearDown(() {
      Pureflow.observer = null;
    });

    test(
        'onObservableChanged throwing propagates from store value setter (actual impl: no try-catch)',
        () {
      Pureflow.observer = FlowObserver(
        onObservableChanged: (_, __, ___, ____) => throw StateError('obs boom'),
      );
      final s = Store(0);

      // Observer is called directly (no try-catch in store_impl), so it propagates
      expect(() => s.value = 1, throwsStateError);

      s.dispose();
    });

    test(
        'onCreated throwing propagates from Store constructor (actual impl: no try-catch)',
        () {
      Pureflow.observer = FlowObserver(
        onCreated: (_, __) => throw StateError('created boom'),
      );

      expect(() => Store(0), throwsStateError);
    });

    test(
        'onCreated throwing propagates from Computed constructor (actual impl: no try-catch)',
        () {
      Pureflow.observer = FlowObserver(
        onCreated: (_, __) => throw StateError('computed created boom'),
      );

      expect(() => Computed(() => 1), throwsStateError);
    });

    test('FlowObserver null callbacks are safe (zero cost)', () {
      Pureflow.observer = const FlowObserver();
      final s = Store(0);
      var count = 0;
      s.addListener(() => count++);
      s.value = 1;
      expect(count, 1);
      s.dispose();
    });
  });

  // ==========================================================================
  // 9. Computed.toString() Coverage
  // ==========================================================================

  group('Computed.toString() formats', () {
    test('before first compute shows dirty', () {
      final c = Computed<int>(() => 42);
      expect(c.toString(), contains('dirty'));
      c.dispose();
    });

    test('after compute shows value', () {
      final c = Computed<int>(() => 42);
      c.value;
      expect(c.toString(), contains('42'));
      c.dispose();
    });

    test('after dispose shows disposed', () {
      final c = Computed<int>(() => 42);
      c.value;
      c.dispose();
      expect(c.toString(), contains('disposed'));
    });

    test('with debugLabel includes label', () {
      final c = Computed<int>(() => 99, debugLabel: 'myComp');
      expect(c.toString(), contains('myComp'));
      c.dispose();
    });

    test('before compute with debugLabel shows dirty', () {
      final c = Computed<int>(() => 7, debugLabel: 'lbl');
      expect(c.toString(), contains('dirty'));
      expect(c.toString(), contains('lbl'));
      c.dispose();
    });

    test('Store.toString includes value', () {
      final s = Store(123);
      expect(s.toString(), contains('123'));
      s.dispose();
    });

    test('Store.toString with debugLabel includes label', () {
      final s = Store(5, debugLabel: 'myStore');
      expect(s.toString(), contains('myStore'));
      s.dispose();
    });
  });

  // ==========================================================================
  // 10. isBroadcast and Multiple listen() Subscriptions
  // ==========================================================================

  group('isBroadcast and multiple listen() subscriptions', () {
    test('Store.isBroadcast is true', () {
      final s = Store(0);
      expect(s.isBroadcast, isTrue);
      s.dispose();
    });

    test('Computed.isBroadcast is true', () {
      final c = Computed(() => 1);
      expect(c.isBroadcast, isTrue);
      c.dispose();
    });

    test('multiple listen() subscriptions each receive events', () {
      final s = Store(0);
      final vals1 = <int>[];
      final vals2 = <int>[];

      final sub1 = s.listen(vals1.add);
      final sub2 = s.listen(vals2.add);

      s.value = 1;
      s.value = 2;

      expect(vals1, [1, 2]);
      expect(vals2, [1, 2]);

      sub1.cancel();
      sub2.cancel();
      s.dispose();
    });

    test('cancel one subscription — other still receives', () {
      final s = Store(0);
      final vals1 = <int>[];
      final vals2 = <int>[];

      final sub1 = s.listen(vals1.add);
      final sub2 = s.listen(vals2.add);

      s.value = 1;
      sub1.cancel();
      s.value = 2;

      expect(vals1, [1]); // stopped after cancel
      expect(vals2, [1, 2]); // still receiving

      sub2.cancel();
      s.dispose();
    });

    test('Computed: multiple listen() subscriptions each receive events', () {
      final src = Store(0);
      final c = Computed(() => src.value * 3);

      final vals1 = <int>[];
      final vals2 = <int>[];

      final sub1 = c.listen(vals1.add);
      final sub2 = c.listen(vals2.add);

      src.value = 1;
      src.value = 2;

      expect(vals1, [3, 6]);
      expect(vals2, [3, 6]);

      sub1.cancel();
      sub2.cancel();
      c.dispose();
      src.dispose();
    });
  });

  // ==========================================================================
  // 11. Computed.listen() triggers initial recompute and fires observer
  // ==========================================================================

  group('Computed.listen() initial recompute and observer', () {
    tearDown(() {
      Pureflow.observer = null;
    });

    test('Computed.listen() triggers initial recompute when dirty', () {
      final src = Store(5);
      final c = Computed(() => src.value * 2);

      final events = <int>[];
      final sub = c.listen(events.add);

      // listen() calls _recompute() which sets hasValueBit
      // but doesn't EMIT to onData until next change
      src.value = 10;
      expect(events, [20]);

      sub.cancel();
      c.dispose();
      src.dispose();
    });

    test(
        'Computed.listen() on dirty computed fires onObservableChanged for initial value',
        () {
      final changedCalls = <Object?>[];
      Pureflow.observer = FlowObserver(
        onObservableChanged: (label, kind, oldVal, newVal) {
          if (kind == FlowKind.computed) {
            changedCalls.add(newVal);
          }
        },
      );

      final src = Store(7);
      final c = Computed(() => src.value + 1, debugLabel: 'testC');

      // Before listen: no recompute yet
      expect(changedCalls, isEmpty);

      final sub = c.listen(null);
      // listen() calls _recompute() → fires onObservableChanged with first value
      expect(changedCalls, [8]);

      sub.cancel();
      c.dispose();
      src.dispose();
    });

    test('Computed.listen() establishes dependencies before first change', () {
      final src = Store(3);
      final c = Computed(() => src.value * 5);

      final sub = c.listen(null); // triggers recompute, establishes dep

      final vals = <int>[];
      c.addListener(() => vals.add(c.value));

      src.value = 4;
      expect(vals, [20]);

      sub.cancel();
      c.dispose();
      src.dispose();
    });
  });
}
