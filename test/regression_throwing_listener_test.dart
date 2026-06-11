import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

void main() {
  // ============================================================================
  // Bug 1: throwing listener no longer bricks notifications
  // Fixed in reactive_source.dart — notifySubscribers() wraps loops in
  // try/finally so notifyingBit is always cleared.
  // ============================================================================

  group('Regression: throwing listener does not brick notifications', () {
    test('subsequent writes still notify other listeners after one throws', () {
      final s = Store(0);
      final received = <int>[];

      // Listener that always throws.
      s.listen((_) => throw Exception('boom'));
      // Second listener that records values.
      s.listen(received.add);

      // First write — throwing listener fires, exception propagates.
      expect(() => s.value = 1, throwsException);

      // After the throw, a second write must still reach the good listener.
      expect(() => s.value = 2, throwsException);

      expect(received, [1, 2]);

      s.dispose();
    });

    test('new listener added after a throwing write still receives updates', () {
      final s = Store(0);
      s.listen((_) => throw Exception('boom'));

      // First write throws.
      expect(() => s.value = 1, throwsException);

      // Add a new listener after the throw.
      final received = <int>[];
      s.listen(received.add);

      // Should still notify — notifyingBit must have been cleared.
      expect(() => s.value = 2, throwsException);
      expect(received, [2]);

      s.dispose();
    });

    test(
        'dependent Computed is marked dirty once listener stops throwing',
        () {
      final s = Store(0);
      final c = Computed(() => s.value * 10);

      // Prime the computed.
      expect(c.value, 0);

      // Listener throws only on first invocation, then stays silent.
      var throwCount = 0;
      s.listen((_) {
        if (throwCount++ == 0) throw Exception('boom once');
      });

      // First write: listener throws, notifyingBit is cleared by try/finally.
      // The deps loop (markDirty) does NOT run because throw exits the loop early.
      expect(() => s.value = 5, throwsException);

      // Second write: notifyingBit was cleared, so notification runs fully.
      // Listener no longer throws → deps loop runs → computed marked dirty.
      s.value = 7; // does NOT throw

      // Computed must recompute with the latest value.
      expect(c.value, 70);

      s.dispose();
      c.dispose();
    });
  });

  // ============================================================================
  // Bug 2: Computed stays dirty when its compute function throws
  // Fixed in computed_impl.dart — _recompute() keeps dirtyBit set on throw
  // so the next read re-executes instead of hitting LateInitializationError.
  // ============================================================================

  group('Regression: Computed stays dirty when compute throws', () {
    test('first access throws; second access re-runs compute', () {
      var callCount = 0;
      final c = Computed<int>(() {
        callCount++;
        if (callCount == 1) throw Exception('first call fails');
        return 42;
      });

      // First read must throw the original error.
      expect(() => c.value, throwsException);
      expect(callCount, 1);

      // Second read must re-run compute (not hit LateInitializationError).
      expect(c.value, 42);
      expect(callCount, 2);

      c.dispose();
    });

    test('no LateInitializationError on second read after first throws', () {
      final c = Computed<int>(() => throw Exception('always fails'));

      expect(() => c.value, throwsException);
      // Must throw the original exception, NOT LateInitializationError.
      expect(
        () => c.value,
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('always fails'),
        )),
      );

      c.dispose();
    });

    test(
        'Computed that succeeded then throws on dep change re-runs after fix',
        () {
      final shouldThrow = Store(false);
      var callCount = 0;

      final c = Computed<int>(() {
        callCount++;
        if (shouldThrow.value) throw Exception('dep-triggered throw');
        return 99;
      });

      // Initial success.
      expect(c.value, 99);
      expect(callCount, 1);

      // Dependency change makes compute throw.
      shouldThrow.value = true;
      expect(() => c.value, throwsException);
      expect(callCount, 2);

      // Fix the condition — next read must recompute correctly.
      shouldThrow.value = false;
      expect(c.value, 99);
      expect(callCount, 3);

      shouldThrow.dispose();
      c.dispose();
    });
  });
}
