import '../packages/pureflow/lib/pureflow.dart';
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
