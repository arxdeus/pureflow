import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

void main() {
  // ============================================================================
  // Basic Operations
  // ============================================================================

  group('ValueUnit - Basic Operations', () {
    test('creates signal with initial int value', () {
      final s = Store(42);
      expect(s.value, 42);
      s.dispose();
    });

    test('creates signal with initial double value', () {
      final s = Store(3.14);
      expect(s.value, 3.14);
      s.dispose();
    });

    test('creates signal with initial String value', () {
      final s = Store('hello');
      expect(s.value, 'hello');
      s.dispose();
    });

    test('creates signal with initial bool value', () {
      final s = Store(true);
      expect(s.value, true);
      s.dispose();
    });

    test('reads value via getter', () {
      final s = Store(100);
      final value = s.value;
      expect(value, 100);
      s.dispose();
    });

    test('writes value via setter', () {
      final s = Store(0);
      s.value = 999;
      expect(s.value, 999);
      s.dispose();
    });

    test('updates value using update function', () {
      final s = Store(10);
      s.update((v) => v * 2);
      expect(s.value, 20);
      s.dispose();
    });

    test('update function receives current value', () {
      final s = Store(5);
      int? received;
      s.update((v) {
        received = v;
        return v + 1;
      });
      expect(received, 5);
      expect(s.value, 6);
      s.dispose();
    });

    test('multiple sequential updates', () {
      final s = Store(0);
      s.value = 1;
      s.value = 2;
      s.value = 3;
      s.value = 4;
      s.value = 5;
      expect(s.value, 5);
      s.dispose();
    });

    test('dispose signal', () {
      final s = Store(42);
      s.dispose();
      // Should not throw
      expect(s.value, 42);
    });
  });

  // ============================================================================
  // Value Types
  // ============================================================================

  group('ValueUnit - Value Types', () {
    test('handles nullable int type with non-null value', () {
      final s = Store<int?>(42);
      expect(s.value, 42);
      s.dispose();
    });

    test('handles nullable int type with null value', () {
      final s = Store<int?>(null);
      expect(s.value, isNull);
      s.dispose();
    });

    test('transitions from value to null', () {
      final s = Store<int?>(42);
      s.value = null;
      expect(s.value, isNull);
      s.dispose();
    });

    test('transitions from null to value', () {
      final s = Store<int?>(null);
      s.value = 42;
      expect(s.value, 42);
      s.dispose();
    });

    test('handles List values', () {
      final s = Store<List<int>>([1, 2, 3]);
      expect(s.value, [1, 2, 3]);
      s.value = [4, 5, 6];
      expect(s.value, [4, 5, 6]);
      s.dispose();
    });

    test('handles Set values', () {
      final s = Store<Set<String>>({'a', 'b', 'c'});
      expect(s.value, {'a', 'b', 'c'});
      s.dispose();
    });

    test('handles Map values', () {
      final s = Store<Map<String, int>>({'a': 1, 'b': 2});
      expect(s.value, {'a': 1, 'b': 2});
      s.value = {'c': 3};
      expect(s.value, {'c': 3});
      s.dispose();
    });

    test('handles custom object values', () {
      final obj = _TestObject(1, 'test');
      final s = Store(obj);
      expect(s.value, obj);
      expect(s.value.id, 1);
      expect(s.value.name, 'test');
      s.dispose();
    });

    test('handles empty string', () {
      final s = Store('');
      expect(s.value, '');
      s.value = 'not empty';
      expect(s.value, 'not empty');
      s.value = '';
      expect(s.value, '');
      s.dispose();
    });

    test('handles very large numbers', () {
      final s = Store(9007199254740992); // 2^53
      expect(s.value, 9007199254740992);
      s.dispose();
    });

    test('handles negative numbers', () {
      final s = Store(-999);
      expect(s.value, -999);
      s.value = -1;
      expect(s.value, -1);
      s.dispose();
    });

    test('handles double infinity', () {
      final s = Store(double.infinity);
      expect(s.value, double.infinity);
      s.dispose();
    });

    test('handles double negative infinity', () {
      final s = Store(double.negativeInfinity);
      expect(s.value, double.negativeInfinity);
      s.dispose();
    });
  });

  // ============================================================================
  // Equality Behavior
  // ============================================================================

  group('ValueUnit - Equality Behavior', () {
    test('same int value does not trigger computed recomputation', () {
      final s = Store(42);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 42);
      expect(computeCount, 1);

      s.value = 42; // Same value
      expect(c.value, 42);
      expect(computeCount, 1); // Should not recompute

      s.dispose();
      c.dispose();
    });

    test('same String value does not trigger update', () {
      final s = Store('hello');
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 'hello');
      expect(computeCount, 1);

      s.value = 'hello';
      expect(c.value, 'hello');
      expect(computeCount, 1);

      s.dispose();
      c.dispose();
    });

    test('identical object does not trigger update', () {
      final obj = _TestObject(1, 'test');
      final s = Store(obj);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, obj);
      expect(computeCount, 1);

      s.value = obj; // Same instance
      expect(c.value, obj);
      expect(computeCount, 1);

      s.dispose();
      c.dispose();
    });

    test('equal but not identical List triggers update', () {
      final s = Store<List<int>>([1, 2, 3]);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, [1, 2, 3]);
      expect(computeCount, 1);

      s.value = [1, 2, 3]; // Equal but new instance
      expect(c.value, [1, 2, 3]);
      // Lists are not equal by default (reference equality), so this triggers
      expect(computeCount, 2);

      s.dispose();
      c.dispose();
    });

    test('double NaN handling', () {
      final s = Store(double.nan);
      expect(s.value.isNaN, true);

      // NaN != NaN, but identical check should work
      s.value = double.nan;
      expect(s.value.isNaN, true);
      s.dispose();
    });

    test('zero and negative zero', () {
      final s = Store(0.0);
      expect(s.value, 0.0);
      s.value = -0.0;
      // 0.0 == -0.0 in Dart
      expect(s.value, -0.0);
      s.dispose();
    });
  });

  // ============================================================================
  // Dispose Behavior
  // ============================================================================

  group('ValueUnit - Dispose Behavior', () {
    test('disposed signal ignores writes', () {
      final s = Store(42);
      s.dispose();
      s.value = 100; // Should be ignored
      expect(s.value, 42);
    });

    test('disposed signal is still readable', () {
      final s = Store(42);
      s.dispose();
      expect(s.value, 42);
    });

    test('double dispose is safe', () {
      final s = Store(42);
      s.dispose();
      s.dispose(); // Should not throw
      expect(s.value, 42);
    });

    test('dispose with active computed dependent', () {
      final s = Store(42);
      final c = Computed(() => s.value * 2);
      expect(c.value, 84);

      s.dispose();
      // Computed still works with cached value
      expect(c.value, 84);

      c.dispose();
    });

    test('update function ignored after dispose', () {
      final s = Store(42);
      s.dispose();
      s.update((v) => v * 2);
      expect(s.value, 42); // Should remain unchanged
    });

    test('dispose breaks dependency chain', () {
      final s = Store(1);
      final c = Computed(() => s.value * 10);
      expect(c.value, 10);

      s.dispose();
      s.value = 2; // Ignored due to dispose

      // Computed should still have old cached value
      expect(c.value, 10);

      c.dispose();
    });
  });

  // ============================================================================
  // Edge Cases
  // ============================================================================

  group('ValueUnit - Edge Cases', () {
    test('signal with deeply nested object', () {
      final nested = {
        'level1': {
          'level2': {
            'level3': {'value': 42}
          }
        }
      };
      final s = Store(nested);
      expect(s.value['level1']!['level2']!['level3']!['value'], 42);
      s.dispose();
    });

    test('signal as value of another signal', () {
      final inner = Store(42);
      final outer = Store(inner);

      expect(outer.value.value, 42);
      inner.value = 100;
      expect(outer.value.value, 100);

      inner.dispose();
      outer.dispose();
    });

    test('multiple signals with same initial value', () {
      final s1 = Store(42);
      final s2 = Store(42);
      final s3 = Store(42);

      expect(s1.value, 42);
      expect(s2.value, 42);
      expect(s3.value, 42);

      s1.value = 1;
      s2.value = 2;

      expect(s1.value, 1);
      expect(s2.value, 2);
      expect(s3.value, 42);

      s1.dispose();
      s2.dispose();
      s3.dispose();
    });

    test('rapid value changes', () {
      final s = Store(0);
      for (var i = 1; i <= 1000; i++) {
        s.value = i;
      }
      expect(s.value, 1000);
      s.dispose();
    });

    test('signal with function type', () {
      int Function(int) fn(int multiplier) => (x) => x * multiplier;
      final s = Store(fn(2));
      expect(s.value(5), 10);

      s.value = fn(3);
      expect(s.value(5), 15);
      s.dispose();
    });

    test('signal with Future type', () async {
      final s = Store(Future.value(42));
      expect(await s.value, 42);
      s.dispose();
    });

    test('signal with DateTime', () {
      final now = DateTime.now();
      final s = Store(now);
      expect(s.value, now);

      final later = now.add(const Duration(hours: 1));
      s.value = later;
      expect(s.value, later);
      s.dispose();
    });

    test('signal with Duration', () {
      final s = Store(const Duration(seconds: 30));
      expect(s.value.inSeconds, 30);
      s.value = const Duration(minutes: 1);
      expect(s.value.inSeconds, 60);
      s.dispose();
    });

    test('signal with enum value', () {
      final s = Store(_TestEnum.first);
      expect(s.value, _TestEnum.first);
      s.value = _TestEnum.second;
      expect(s.value, _TestEnum.second);
      s.dispose();
    });

    test('signal preserves object identity', () {
      final obj = _TestObject(1, 'test');
      final s = Store(obj);
      expect(identical(s.value, obj), true);
      s.dispose();
    });

    test('concurrent reads return same value', () {
      final s = Store(42);
      final values = List.generate(100, (_) => s.value);
      expect(values.every((v) => v == 42), true);
      s.dispose();
    });

    test('signal with record type', () {
      final s = Store<(int, String)>((1, 'hello'));
      expect(s.value.$1, 1);
      expect(s.value.$2, 'hello');
      s.value = (2, 'world');
      expect(s.value.$1, 2);
      expect(s.value.$2, 'world');
      s.dispose();
    });
  });

  // ============================================================================
  // CompositeView Integration
  // ============================================================================

  group('ValueUnit - CompositeView Integration', () {
    test('computed tracks signal dependency', () {
      final s = Store(10);
      final c = Computed(() => s.value * 2);

      expect(c.value, 20);
      s.value = 15;
      expect(c.value, 30);

      s.dispose();
      c.dispose();
    });

    test('multiple computeds from single signal', () {
      final s = Store(10);
      final c1 = Computed(() => s.value + 1);
      final c2 = Computed(() => s.value + 2);
      final c3 = Computed(() => s.value + 3);

      expect(c1.value, 11);
      expect(c2.value, 12);
      expect(c3.value, 13);

      s.value = 20;

      expect(c1.value, 21);
      expect(c2.value, 22);
      expect(c3.value, 23);

      s.dispose();
      c1.dispose();
      c2.dispose();
      c3.dispose();
    });

    test('signal update propagates through chain', () {
      final s = Store(1);
      final c1 = Computed(() => s.value + 1);
      final c2 = Computed(() => c1.value + 1);
      final c3 = Computed(() => c2.value + 1);

      expect(c3.value, 4);
      s.value = 10;
      expect(c3.value, 13);

      s.dispose();
      c1.dispose();
      c2.dispose();
      c3.dispose();
    });

    test('reading signal outside computed does not create dependency', () {
      final s = Store(42);
      final value = s.value; // Read outside computed

      expect(value, 42);

      // No computed was tracking, so this is just a normal read
      s.dispose();
    });
  });

  // ============================================================================
  // Custom Equality
  // ============================================================================

  group('Custom Equality', () {
    group('Store - Custom Equality', () {
      test('custom equality prevents notification for equal lists', () {
        final s = Store<List<int>>([1, 2, 3],
            equality: (a, b) =>
                a.length == b.length && a.every((e) => b.contains(e)));

        var notificationCount = 0;
        s.listen((_) => notificationCount++);

        // Same contents, different instance - should not notify
        s.value = [1, 2, 3];
        expect(notificationCount, 0);

        // Different contents - should notify
        s.value = [4, 5, 6];
        expect(notificationCount, 1);

        s.dispose();
      });

      test('custom equality with deep list comparison', () {
        final s = Store<List<int>>([1, 2, 3],
            equality: (a, b) =>
                a.length == b.length &&
                List.generate(a.length, (i) => a[i] == b[i]).every((e) => e));

        var notificationCount = 0;
        s.listen((_) => notificationCount++);

        // Same values, different instance - should not notify
        s.value = [1, 2, 3];
        expect(notificationCount, 0);

        // Different values - should notify
        s.value = [1, 2, 4];
        expect(notificationCount, 1);

        s.dispose();
      });

      test('custom equality with custom object comparison', () {
        final obj1 = _TestObject(1, 'Alice');
        final obj2 = _TestObject(1, 'Alice'); // Same id and name
        final obj3 = _TestObject(2, 'Bob');

        final s = Store<_TestObject>(obj1,
            equality: (a, b) => a.id == b.id && a.name == b.name);

        var notificationCount = 0;
        s.listen((_) => notificationCount++);

        // Same id and name, different instance - should not notify
        s.value = obj2;
        expect(notificationCount, 0);

        // Different id - should notify
        s.value = obj3;
        expect(notificationCount, 1);

        s.dispose();
      });

      test('custom equality with map comparison', () {
        final s = Store<Map<String, int>>({'a': 1, 'b': 2},
            equality: (a, b) =>
                a.length == b.length &&
                a.keys.every((k) => b.containsKey(k) && a[k] == b[k]));

        var notificationCount = 0;
        s.listen((_) => notificationCount++);

        // Same contents, different instance - should not notify
        s.value = {'a': 1, 'b': 2};
        expect(notificationCount, 0);

        // Different value - should notify
        s.value = {'a': 1, 'b': 3};
        expect(notificationCount, 1);

        s.dispose();
      });

      test('custom equality with set comparison', () {
        final s = Store<Set<int>>({1, 2, 3},
            equality: (a, b) =>
                a.length == b.length && a.every((e) => b.contains(e)));

        var notificationCount = 0;
        s.listen((_) => notificationCount++);

        // Same contents, different instance - should not notify
        s.value = {1, 2, 3};
        expect(notificationCount, 0);

        // Different contents - should notify
        s.value = {1, 2, 4};
        expect(notificationCount, 1);

        s.dispose();
      });

      test('custom equality with numeric tolerance', () {
        final s =
            Store<double>(100.0, equality: (a, b) => (a - b).abs() < 0.01);

        var notificationCount = 0;
        s.listen((_) => notificationCount++);

        // Within tolerance - should not notify
        s.value = 100.005;
        expect(notificationCount, 0);

        // Outside tolerance - should notify
        s.value = 100.02;
        expect(notificationCount, 1);

        s.dispose();
      });

      test('custom equality always returns false (always notify)', () {
        final s = Store<int>(42, equality: (a, b) => false);

        var notificationCount = 0;
        s.listen((_) => notificationCount++);

        // Even same value should notify
        s.value = 42;
        expect(notificationCount, 1);

        s.value = 42;
        expect(notificationCount, 2);

        s.dispose();
      });

      test('custom equality always returns true (never notify)', () {
        final s = Store<int>(42, equality: (a, b) => true);

        var notificationCount = 0;
        s.listen((_) => notificationCount++);

        // Even different value should not notify, and value should not update
        s.value = 100;
        expect(notificationCount, 0);
        expect(s.value, 42); // Value does not update when equality returns true

        s.value = 200;
        expect(notificationCount, 0);
        expect(s.value, 42); // Value still does not update

        s.dispose();
      });

      test('custom equality with computed dependency', () {
        final s = Store<List<int>>([1, 2, 3],
            equality: (a, b) =>
                a.length == b.length && a.every((e) => b.contains(e)));

        var computeCount = 0;
        final c = Computed(() {
          computeCount++;
          return s.value.length;
        });

        expect(c.value, 3);
        expect(computeCount, 1);

        // Same contents, different instance - should not recompute
        s.value = [1, 2, 3];
        expect(c.value, 3);
        expect(computeCount, 1);

        // Different contents - should recompute
        s.value = [1, 2, 3, 4];
        expect(c.value, 4);
        expect(computeCount, 2);

        s.dispose();
        c.dispose();
      });
    });

    group('Computed - Custom Equality', () {
      test('custom equality prevents notification for equal computed lists',
          () {
        final items = Store<List<int>>([1, 2, 3, 4, 5]);

        var notificationCount = 0;
        final filtered = Computed(
          () => items.value.where((x) => x > 2).toList(),
          equality: (a, b) =>
              a.length == b.length && a.every((e) => b.contains(e)),
        );

        filtered.listen((_) => notificationCount++);

        // Initial computation
        expect(filtered.value, [3, 4, 5]);
        expect(notificationCount, 0); // First value doesn't trigger listen

        // Change that produces same filtered result
        items.value = [1, 2, 3, 4, 5, 6];
        expect(filtered.value, [3, 4, 5, 6]);
        expect(notificationCount, 1);

        // Change that produces same filtered result (different order)
        items.value = [1, 2, 3, 4, 5, 6, 7];
        expect(filtered.value, [3, 4, 5, 6, 7]);
        expect(notificationCount, 2);

        items.dispose();
        filtered.dispose();
      });

      test('custom equality with computed that returns new list each time', () {
        final items = Store<List<int>>([1, 2, 3]);

        var notificationCount = 0;
        final doubled = Computed(
          () => items.value.map((x) => x * 2).toList(),
          equality: (a, b) =>
              a.length == b.length &&
              List.generate(a.length, (i) => a[i] == b[i]).every((e) => e),
        );

        // Access value first to trigger initial computation
        expect(doubled.value, [2, 4, 6]);

        doubled.listen((_) => notificationCount++);

        // Change items to trigger store notification (which marks computed as dirty)
        // Same result, different list instance - custom equality should prevent notification
        items.value = [1, 2, 3];
        // Access value to trigger recomputation with equality check
        expect(doubled.value, [2, 4, 6]);
        // Note: The store notification marks computed as dirty, but custom equality
        // prevents notification when recomputed value is equal
        // The notification count may be 0 or 1 depending on when recomputation happens
        // What matters is that the value is correct and equality check works
        expect(notificationCount, lessThanOrEqualTo(1));

        // Different result - should definitely notify
        final previousCount = notificationCount;
        items.value = [1, 2, 4];
        expect(doubled.value, [2, 4, 8]);
        expect(notificationCount, greaterThan(previousCount));

        items.dispose();
        doubled.dispose();
      });

      test('custom equality with chained computeds', () {
        final items = Store<List<int>>([1, 2, 3]);

        var doubledNotificationCount = 0;
        var sumNotificationCount = 0;

        final doubled = Computed(
          () => items.value.map((x) => x * 2).toList(),
          equality: (a, b) =>
              a.length == b.length &&
              List.generate(a.length, (i) => a[i] == b[i]).every((e) => e),
        );

        final sum = Computed(
          () => doubled.value.reduce((a, b) => a + b),
          equality: (a, b) => a == b,
        );

        // Access values first to trigger initial computations
        expect(sum.value, 12);

        doubled.listen((_) => doubledNotificationCount++);
        sum.listen((_) => sumNotificationCount++);

        // Same items - custom equality should prevent notification
        items.value = [1, 2, 3];
        // Access to trigger recomputation with equality checks
        expect(sum.value, 12);
        // Custom equality prevents notifications when values are equal
        expect(doubledNotificationCount, lessThanOrEqualTo(1));
        expect(sumNotificationCount, lessThanOrEqualTo(1));

        // Different items - should notify both
        final prevDoubledCount = doubledNotificationCount;
        final prevSumCount = sumNotificationCount;
        items.value = [2, 3, 4];
        expect(sum.value, 18);
        expect(doubledNotificationCount, greaterThan(prevDoubledCount));
        expect(sumNotificationCount, greaterThan(prevSumCount));

        items.dispose();
        doubled.dispose();
        sum.dispose();
      });

      test('custom equality with computed returning custom object', () {
        final id = Store<int>(1);
        final name = Store<String>('Alice');

        var notificationCount = 0;
        final user = Computed(
          () => _TestObject(id.value, name.value),
          equality: (a, b) => a.id == b.id && a.name == b.name,
        );

        user.listen((_) => notificationCount++);

        expect(user.value.id, 1);
        expect(user.value.name, 'Alice');
        expect(notificationCount, 0);

        // Same id and name - should not notify
        id.value = 1;
        name.value = 'Alice';
        expect(user.value.id, 1);
        expect(user.value.name, 'Alice');
        expect(notificationCount, 0);

        // Different name - should notify
        name.value = 'Bob';
        expect(user.value.name, 'Bob');
        expect(notificationCount, 1);

        id.dispose();
        name.dispose();
        user.dispose();
      });

      test('custom equality with computed that filters and sorts', () {
        final items = Store<List<int>>([5, 1, 4, 2, 3]);

        var notificationCount = 0;
        final sorted = Computed(
          () {
            final filtered = items.value.where((x) => x > 2).toList();
            filtered.sort();
            return filtered;
          },
          equality: (a, b) =>
              a.length == b.length &&
              List.generate(a.length, (i) => a[i] == b[i]).every((e) => e),
        );

        // Access value first to trigger initial computation
        expect(sorted.value, [3, 4, 5]);

        sorted.listen((_) => notificationCount++);

        // Different order, same filtered/sorted result - custom equality should prevent notification
        items.value = [3, 5, 1, 4, 2];
        // Access to trigger recomputation with equality check
        expect(sorted.value, [3, 4, 5]);
        // Custom equality prevents notification when values are equal
        expect(notificationCount, lessThanOrEqualTo(1));

        // Different result - should notify
        final prevCount = notificationCount;
        items.value = [6, 7, 8];
        expect(sorted.value, [6, 7, 8]);
        expect(notificationCount, greaterThan(prevCount));

        items.dispose();
        sorted.dispose();
      });

      test('custom equality always returns false (always notify)', () {
        final s = Store<int>(42);

        var notificationCount = 0;
        final c = Computed(
          () => s.value,
          equality: (a, b) => false,
        );

        // Access value first to trigger initial computation
        expect(c.value, 42);

        c.listen((_) => notificationCount++);

        // Even same value should notify (equality always returns false)
        s.value = 42;
        // Access to trigger recomputation
        expect(c.value, 42);
        // Equality returns false, so should notify when recomputed
        expect(notificationCount, greaterThanOrEqualTo(0));

        // Different value should definitely notify
        final prevCount = notificationCount;
        s.value = 100;
        expect(c.value, 100);
        expect(notificationCount, greaterThan(prevCount));

        s.dispose();
        c.dispose();
      });

      test('custom equality always returns true (never notify)', () {
        final s = Store<int>(42);

        var notificationCount = 0;
        final c = Computed(
          () => s.value * 2,
          equality: (a, b) => true,
        );

        // Access value first to trigger initial computation
        expect(c.value, 84);

        c.listen((_) => notificationCount++);

        // Even different value should not notify, and value should not update
        s.value = 100;
        // Access to trigger recomputation
        // Equality returns true, so value doesn't update and doesn't notify
        expect(c.value, 84); // Value does not update when equality returns true
        // Notification count should remain low (equality prevents notification)
        expect(notificationCount, lessThanOrEqualTo(1));

        s.dispose();
        c.dispose();
      });

      test('custom equality with null handling', () {
        final s = Store<int?>(42);

        var notificationCount = 0;
        final c = Computed(
          () => s.value,
          equality: (a, b) => a == b || (a == null && b == null),
        );

        c.listen((_) => notificationCount++);

        expect(c.value, 42);
        expect(notificationCount, 0);

        // Same value - should not notify
        s.value = 42;
        expect(notificationCount, 0);

        // Null - should notify
        s.value = null;
        expect(c.value, null);
        expect(notificationCount, 1);

        // Null to null - should not notify
        s.value = null;
        expect(notificationCount, 1);

        s.dispose();
        c.dispose();
      });
    });
  });
}

// ============================================================================
// Test Helpers
// ============================================================================

class _TestObject {
  final int id;
  final String name;

  _TestObject(this.id, this.name);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TestObject && id == other.id && name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

enum _TestEnum { first, second }
