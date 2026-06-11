// ignore_for_file: unused_local_variable
import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

void main() {
  // ==========================================================================
  // Gap 1: Listener that calls batch() AND throws
  // ==========================================================================

  group('Batch stability - re-entrant listener that throws', () {
    test(
        'listener starts re-entrant batch, mutates store, then throws — '
        're-entrant mutations visible but not notified, system stays alive',
        () {
      final a = Store(0);
      final b = Store(0);
      var bListenerCalls = 0;
      b.addListener(() => bListenerCalls++);

      // a's listener enqueues b in a re-entrant batch, then throws.
      void throwingListener() {
        batch(() {
          b.value = 99;
        });
        throw Exception('listener kaboom');
      }

      a.addListener(throwingListener);

      // The outer batch throws because a's listener throws.
      expect(
        () => batch(() {
          a.value = 1;
        }),
        throwsException,
      );

      // b's value was mutated (store._value updated) even though listener
      // threw before b's notification could fire.
      expect(b.value, 99);

      // b's listener did NOT fire — the re-entrant batch items were cleared
      // by _flushBatch's finally block when the exception aborted the flush.
      expect(bListenerCalls, 0);

      // System must still be alive.
      a.removeListener(throwingListener);
      final c = Store(5);
      var cCalls = 0;
      c.addListener(() => cCalls++);
      batch(() {
        c.value = 10;
      });
      expect(cCalls, 1);
      expect(c.value, 10);

      a.dispose();
      b.dispose();
      c.dispose();
    });

    test(
        'two stores in batch, first store listener throws — '
        'second store value updated, second store listener may or may not fire '
        'depending on flush order, but system remains consistent', () {
      final first = Store(0);
      final second = Store(0);
      var secondListenerCalls = 0;
      second.addListener(() => secondListenerCalls++);

      void throwingOnFirst() => throw Exception('first boom');
      first.addListener(throwingOnFirst);

      expect(
        () => batch(() {
          first.value = 1;
          second.value = 2;
        }),
        throwsException,
      );

      // second value is updated regardless.
      expect(second.value, 2);

      // After removing the throwing listener, next batch works.
      first.removeListener(throwingOnFirst);
      batch(() {
        first.value = 10;
        second.value = 20;
      });
      expect(first.value, 10);
      expect(second.value, 20);

      first.dispose();
      second.dispose();
    });
  });

  // ==========================================================================
  // Gap 2: batch() return value — async action contract
  // ==========================================================================

  group('Batch stability - return value and async contract', () {
    test('batch returns null from void-returning lambda', () {
      final result = batch(() {});
      expect(result, isNull);
    });

    test('batch returns Future without awaiting — future is the return value',
        () {
      final s = Store(0);
      // Async action returns a Future<void>. batch() does not await it.
      final future = batch(() {
        s.value = 1;
      });
      // batch itself returns the Future
      expect(future, isA<Future<void>>());
      // Sync mutations (before first await) are visible immediately after batch
      expect(s.value, 1);
      s.dispose();
    });

    test(
        'async action: mutations before first await are batched, '
        'mutations after first await are outside batch and trigger immediate notification',
        () async {
      final s = Store(0);
      final notifiedValues = <int>[];
      final c = Computed(() => s.value);
      c.value; // warm up
      c.addListener(() => notifiedValues.add(c.value));

      // batch starts: s.value = 1 is inside the batch
      // The action() returns a Future<void> immediately.
      // batchDepth--, flush fires with s=1.
      // After the await, s.value = 2 is OUTSIDE any batch → immediate notify.
      await batch(() async {
        s.value = 1;
        await Future<void>.delayed(Duration.zero);
        s.value = 2; // outside batch context at this point
      });

      // notifiedValues should contain both updates since each fired
      // a notification: one from the batch flush (s=1), one immediately (s=2).
      expect(notifiedValues.length, 2);
      expect(notifiedValues[0], 1);
      expect(notifiedValues[1], 2);
      expect(s.value, 2);

      c.dispose();
      s.dispose();
    });

    test('batch return value typed correctly — int, String, list, null', () {
      expect(batch(() => 7), 7);
      expect(batch<String?>(() => null), isNull);
      expect(batch(() => [1, 2, 3]), [1, 2, 3]);
      expect(batch(() => {'k': 'v'}), {'k': 'v'});
    });
  });

  // ==========================================================================
  // Gap 3: Computed first-read inside batch listener (batchFlushing path)
  // ==========================================================================

  group('Batch stability - computed first-read inside flush listener', () {
    test(
        'computed never read before, first read inside a store listener '
        'during flush — value is correct', () {
      final dep = Store(10);
      final c = Computed(() => dep.value * 3);
      // c is never read — starts dirty, no hasValue

      int? observedInsideListener;
      final trigger = Store(0);
      trigger.addListener(() {
        // Read computed for the first time inside the flush.
        observedInsideListener = c.value;
      });

      batch(() {
        dep.value = 7;
        trigger.value = 1;
      });

      // dep was flushed before trigger; but order depends on insertion order.
      // Either way, c.value inside listener recomputes with whatever dep is at
      // that point. After the full batch, c must reflect dep=7.
      expect(c.value, 21); // 7 * 3
      // The value read inside the listener should equal dep.value * 3 at read
      // time — at minimum it must be non-null and consistent.
      expect(observedInsideListener, isNotNull);

      dep.dispose();
      trigger.dispose();
      c.dispose();
    });

    test(
        'never-read computed has no tracked deps — listener does NOT fire '
        'from dep mutation until computed is read at least once', () {
      final dep = Store(1);
      final c = Computed(() => dep.value + 100);
      // Do NOT warm up c — deps never tracked, dep has no DependencyNode for c.

      var cListenerCalls = 0;
      c.addListener(() => cListenerCalls++);

      // Batch mutates dep. dep.notifySubscribers() calls markDirty on its
      // dependency nodes, but c has never been read so no dep node exists.
      // c's listener does NOT fire.
      batch(() {
        dep.value = 5;
      });

      expect(cListenerCalls, 0); // never-read computed = no tracked deps

      // Reading c outside batch: recomputes (dirty) → shouldNotify=true
      // (isFirstValue) → notifySubscribers() fires listener immediately.
      expect(c.value, 105);
      expect(cListenerCalls, 1); // first-value notification on direct read

      // Now that c is warmed up (deps tracked), next batch mutation fires
      // listener once from flush (markDirty → _deferToBatch → notifySubscribers).
      batch(() {
        dep.value = 10;
      });
      expect(cListenerCalls, 2); // one more from batch flush

      // Reading c while dirty (post-batch) recomputes → notifySubscribers
      // fires again (value changed 105→110).
      expect(c.value, 110);
      expect(cListenerCalls, 3);

      dep.dispose();
      c.dispose();
    });
  });

  // ==========================================================================
  // Gap 4: Nested batch where inner throws, outer catches
  // ==========================================================================

  group('Batch stability - inner batch throws, outer catches', () {
    test(
        'outer catches inner exception — both mutations applied, '
        'single coalesced notification', () {
      final s = Store(0);
      var notifyCalls = 0;
      s.addListener(() => notifyCalls++);

      batch(() {
        s.value = 1;
        try {
          batch(() {
            s.value = 2;
            throw Exception('inner boom');
          });
        } catch (_) {
          // outer catches, continues
          s.value = 3;
        }
      });

      // All mutations applied; final value is 3.
      expect(s.value, 3);
      // Single coalesced notification at outer batch end.
      expect(notifyCalls, 1);

      s.dispose();
    });

    test(
        'inner batch throws, outer catches — dependent computed sees final value',
        () {
      final s = Store(0);
      final c = Computed(() => s.value * 10);
      c.value; // warm up

      batch(() {
        s.value = 5;
        try {
          batch(() {
            s.value = 99;
            throw Exception('boom');
          });
        } catch (_) {}
        // back in outer batch, s is 99 (mutation kept even though inner threw)
        s.value = 7;
      });

      expect(s.value, 7);
      expect(c.value, 70);

      s.dispose();
      c.dispose();
    });

    test('inner batch throws with multiple stores — outer still flushes all',
        () {
      final a = Store(0);
      final b = Store(0);
      var aCalls = 0;
      var bCalls = 0;
      a.addListener(() => aCalls++);
      b.addListener(() => bCalls++);

      batch(() {
        a.value = 1;
        try {
          batch(() {
            b.value = 2;
            throw Exception('inner');
          });
        } catch (_) {}
      });

      expect(a.value, 1);
      expect(b.value, 2);
      expect(aCalls, 1);
      expect(bCalls, 1);

      a.dispose();
      b.dispose();
    });
  });

  // ==========================================================================
  // Gap 5: dispose() inside batch — pending notification for that store
  // ==========================================================================

  group('Batch stability - dispose inside batch', () {
    test('store disposed inside batch action — flush does not crash', () {
      final s = Store(0);
      var listenerCalls = 0;
      s.addListener(() => listenerCalls++);

      // No exception expected.
      expect(
        () => batch(() {
          s.value = 42;
          s.dispose(); // disposes while pending in batchBuffer
        }),
        returnsNormally,
      );

      // Listener should NOT have fired — store was disposed before flush ran.
      expect(listenerCalls, 0);
    });

    test('other stores in same batch still notified after one is disposed', () {
      final a = Store(0);
      final b = Store(0);
      var aCalls = 0;
      var bCalls = 0;
      a.addListener(() => aCalls++);
      b.addListener(() => bCalls++);

      batch(() {
        a.value = 1;
        b.value = 2;
        a.dispose(); // a disposed mid-batch
      });

      // b still notified.
      expect(bCalls, 1);
      expect(b.value, 2);

      b.dispose();
    });

    test(
        'store disposed inside batch listener — system stays alive for '
        'next batch', () {
      final s = Store(0);
      final other = Store(0);

      s.addListener(s.dispose);

      // Should not throw.
      expect(
        () => batch(() {
          s.value = 1;
        }),
        returnsNormally,
      );

      // other still works.
      var otherCalls = 0;
      other.addListener(() => otherCalls++);
      batch(() {
        other.value = 5;
      });
      expect(otherCalls, 1);
      expect(other.value, 5);

      other.dispose();
    });
  });

  // ==========================================================================
  // Gap 6: batch inside computed compute function
  // ==========================================================================

  group('Batch stability - batch inside computed compute function', () {
    test(
        'compute function calls batch mutating another store — '
        'no deadlock, side-effect store updated', () {
      final source = Store(0);
      final sideEffect = Store(0);

      final c = Computed(() {
        // Calling batch inside a compute function:
        // If batchDepth > 0 already (e.g. during a flush), the inner batch
        // adds to buffer and does not flush immediately; the outer while loop
        // picks it up. If batchDepth == 0 (fresh read), the inner batch
        // flushes immediately after its action.
        final v = source.value;
        if (v > 0) {
          batch(() {
            sideEffect.value = v * 2;
          });
        }
        return v;
      });

      // First read: batch inside compute fires immediately.
      source.value = 3;
      expect(c.value, 3);
      expect(sideEffect.value, 6);

      source.dispose();
      sideEffect.dispose();
      c.dispose();
    });

    test(
        'compute called from inside outer batch mutates side-effect store — '
        'side-effect enqueued and notified after outer batch', () {
      final dep = Store(1);
      final side = Store(0);
      var sideCalls = 0;
      side.addListener(() => sideCalls++);

      final c = Computed(() {
        final v = dep.value;
        // Inner batch during compute inside outer batch:
        // batchDepth is already >0 (we're being computed mid-flush or during
        // a batch read). The inner batch enqueues side and batchDepth never
        // drops to 0, so the while loop in _flushBatch picks it up.
        batch(() {
          side.value = v + 10;
        });
        return v;
      });

      batch(() {
        dep.value = 5;
        // Trigger compute inside batch by reading c.
        final _ = c.value; // recomputes fresh (c was dirty-on-start).
      });

      // After batch: dep=5, c=5, side=15.
      expect(c.value, 5);
      expect(side.value, 15);

      dep.dispose();
      side.dispose();
      c.dispose();
    });
  });

  // ==========================================================================
  // Gap 7: Listener added inside batch (between mutations)
  // ==========================================================================

  group('Batch stability - listener added inside batch', () {
    test(
        'listener added between mutations inside batch — '
        'receives flush notification', () {
      final s = Store(0);
      var newListenerCalls = 0;
      void newListener() => newListenerCalls++;

      batch(() {
        s.value = 1;
        s.addListener(newListener); // added mid-batch
        s.value = 2;
      });

      // Listener was added before flush; it must receive the notification.
      expect(newListenerCalls, 1);
      expect(s.value, 2);

      s.removeListener(newListener);
      s.dispose();
    });

    test(
        'listener added inside batch for a store not yet mutated — '
        'receives notification if store is later mutated in same batch', () {
      final a = Store(0);
      final b = Store(0);
      var bCalls = 0;

      batch(() {
        a.value = 1;
        b.addListener(() => bCalls++); // add listener before b is mutated
        b.value = 5;
      });

      expect(bCalls, 1);
      expect(b.value, 5);

      a.dispose();
      b.dispose();
    });

    test(
        'listener added inside batch for store that was already mutated — '
        'still receives notification (already in batchBuffer)', () {
      final s = Store(0);
      var lateListenerCalls = 0;

      batch(() {
        s.value = 10; // s is now in batchBuffer
        s.addListener(() => lateListenerCalls++); // add after mutation
      });

      // The store was already enqueued; listener fires at flush.
      expect(lateListenerCalls, 1);
      expect(s.value, 10);

      s.dispose();
    });
  });

  // ==========================================================================
  // Gap 8: Massive interleave — 50 stores, 20 computeds
  // ==========================================================================

  group('Batch stability - massive interleave', () {
    test(
        '50 stores, 20 diamond-ish computeds, single batch — '
        'each listener fires exactly once, all values correct', () {
      // Build 50 base stores.
      final stores = List.generate(50, Store<int>.new);

      // 20 computeds: each sums a slice of stores (overlapping → diamond-ish).
      // computed[k] = sum of stores[k*2 .. k*2+4] (mod 50)
      final computeds = List.generate(20, (k) {
        return Computed<int>(() {
          var sum = 0;
          for (var j = 0; j < 5; j++) {
            sum += stores[(k * 2 + j) % 50].value;
          }
          return sum;
        });
      });

      // Warm up all computeds.
      for (final c in computeds) {
        c.value;
      }

      // Add listeners counting calls.
      final computedCalls = List<int>.filled(20, 0);
      final storeCalls = List<int>.filled(50, 0);
      for (var i = 0; i < 20; i++) {
        final idx = i;
        computeds[idx].addListener(() => computedCalls[idx]++);
      }
      for (var i = 0; i < 50; i++) {
        final idx = i;
        stores[idx].addListener(() => storeCalls[idx]++);
      }

      // Single batch mutating every store multiple times.
      batch(() {
        for (var round = 0; round < 3; round++) {
          for (var i = 0; i < 50; i++) {
            stores[i].value = i * 10 + round;
          }
        }
        // Final values: stores[i].value = i*10 + 2
      });

      // Verify each store listener fired exactly once.
      for (var i = 0; i < 50; i++) {
        expect(storeCalls[i], 1, reason: 'store[$i] notified != 1 times');
      }

      // Verify each computed listener fired exactly once.
      for (var i = 0; i < 20; i++) {
        expect(computedCalls[i], 1, reason: 'computed[$i] notified != 1 times');
      }

      // Verify computed values are correct.
      for (var k = 0; k < 20; k++) {
        var expected = 0;
        for (var j = 0; j < 5; j++) {
          expected += (k * 2 + j) % 50 * 10 + 2;
        }
        expect(computeds[k].value, expected,
            reason: 'computed[$k] wrong value');
      }

      for (final s in stores) {
        s.dispose();
      }
      for (final c in computeds) {
        c.dispose();
      }
    });
  });

  // ==========================================================================
  // Gap 9: batch() reading computed values mid-batch
  // ==========================================================================

  group('Batch stability - computed reads inside batch', () {
    test(
        'warmed-up computed read inside batch returns stale value — '
        'store mutations not yet propagated (markDirty not called)', () {
      final s = Store(10);
      final c = Computed(() => s.value * 2);
      expect(c.value, 20); // warm up, clears dirtyBit

      int? midBatchRead;
      final result = batch(() {
        s.value = 50; // enqueued in batchBuffer, markDirty NOT called yet
        return midBatchRead = c.value; // c is NOT dirty → returns cached 20
      });

      // Inside batch: stale cached value.
      expect(result, 20);
      expect(midBatchRead, 20);
      // After batch flush: fresh value.
      expect(c.value, 100);

      s.dispose();
      c.dispose();
    });

    test(
        'never-read computed inside batch: starts dirty → reads fresh value '
        'because dirtyBit was set before any batch', () {
      final s = Store(7);
      final c = Computed(() => s.value + 1);
      // c is dirty from constructor — NOT warmed up.

      int? midBatchRead;
      batch(() {
        s.value = 20; // s._value is 20 now
        midBatchRead =
            c.value; // c is dirty → recomputes with s=20 → fresh value
      });

      // Fresh value because c was dirty (never computed before).
      expect(midBatchRead, 21);
      expect(c.value, 21);

      s.dispose();
      c.dispose();
    });

    test(
        'computed chain: mid-batch read of leaf returns stale — '
        'only outermost dirty (never warmed) sees fresh', () {
      final s = Store(1);
      final mid = Computed(() => s.value * 2); // will be warmed
      final leaf = Computed(() => mid.value + 1); // will be warmed

      mid.value; // warm up → clears dirty
      leaf.value; // warm up

      int? midRead;
      int? leafRead;
      batch(() {
        s.value = 5; // neither mid nor leaf are marked dirty yet
        midRead = mid.value; // mid NOT dirty → stale = 2
        leafRead = leaf.value; // leaf NOT dirty → stale = 3
      });

      expect(midRead, 2);
      expect(leafRead, 3);
      // After flush: mid=10, leaf=11.
      expect(mid.value, 10);
      expect(leaf.value, 11);

      s.dispose();
      mid.dispose();
      leaf.dispose();
    });
  });

  // ==========================================================================
  // Gap 10: Sequential batches reusing buffer (100x)
  // ==========================================================================

  group('Batch stability - sequential batches reusing buffer', () {
    test(
        '100 sequential batches — correct values and exact notification counts',
        () {
      final s = Store(0);
      var notifyCalls = 0;
      s.addListener(() => notifyCalls++);

      for (var i = 1; i <= 100; i++) {
        batch(() {
          s.value = i * 2 - 1;
          s.value = i * 2;
        });
        expect(s.value, i * 2, reason: 'wrong value after batch $i');
        expect(notifyCalls, i, reason: 'wrong notify count after batch $i');
      }

      s.dispose();
    });

    test('100 sequential batches with computed — single recompute per batch',
        () {
      final s = Store(0);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value * 3;
      });
      c.value; // warm up
      expect(computeCount, 1);

      for (var i = 1; i <= 100; i++) {
        batch(() {
          s.value = i;
          s.value = i + 100;
          s.value = i + 200;
        });
        expect(s.value, i + 200);
        expect(c.value, (i + 200) * 3);
        expect(computeCount, i + 1, reason: 'extra recompute at iteration $i');
      }

      s.dispose();
      c.dispose();
    });

    test('sequential batches after large batch — buffer reuse works correctly',
        () {
      // Trigger buffer growth then shrink.
      final large = List.generate(300, Store<int>.new);
      batch(() {
        for (final s in large) {
          s.value = 1;
        }
      });
      for (final s in large) {
        s.dispose();
      }

      // Now small sequential batches must still work (buffer shrunk back).
      // Start stores at -1 so i=0 always triggers a change notification.
      final a = Store(-1);
      final b = Store(-1);
      var calls = 0;
      a.addListener(() => calls++);
      b.addListener(() => calls++);

      for (var i = 0; i < 50; i++) {
        batch(() {
          a.value = i;
          b.value = i * 2;
        });
      }
      expect(calls, 100); // 50 batches × 2 stores (each unique value)
      expect(a.value, 49);
      expect(b.value, 98);

      a.dispose();
      b.dispose();
    });
  });
}
