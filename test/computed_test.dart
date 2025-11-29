import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

void main() {
  // ============================================================================
  // Basic Operations
  // ============================================================================

  group('Computed - Basic Operations', () {
    test('creates computed with function', () {
      final c = Computed(() => 42);
      expect(c.value, 42);
      c.dispose();
    });

    test('creates computed with complex expression', () {
      final c = Computed(() => (10 + 20) * 2 - 5);
      expect(c.value, 55);
      c.dispose();
    });

    test('reads value multiple times returns same result', () {
      var callCount = 0;
      final c = Computed(() {
        callCount++;
        return 42;
      });

      expect(c.value, 42);
      expect(c.value, 42);
      expect(c.value, 42);
      expect(callCount, 1); // Only computed once

      c.dispose();
    });

    test('lazy evaluation - not computed until accessed', () {
      var computed = false;
      final c = Computed(() {
        computed = true;
        return 42;
      });

      expect(computed, false);
      c.value; // Access triggers computation
      expect(computed, true);

      c.dispose();
    });

    test('recomputes when dependency changes', () {
      final s = Signal(10);
      final c = Computed(() => s.value * 2);

      expect(c.value, 20);
      s.value = 15;
      expect(c.value, 30);

      s.dispose();
      c.dispose();
    });

    test('dispose computed', () {
      final c = Computed(() => 42);
      c.dispose();
      // Still readable after dispose
      expect(c.value, 42);
    });
  });

  // ============================================================================
  // Dependency Tracking
  // ============================================================================

  group('Computed - Dependency Tracking', () {
    test('tracks single signal dependency', () {
      final s = Signal(5);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 5);
      expect(computeCount, 1);

      s.value = 10;
      expect(c.value, 10);
      expect(computeCount, 2);

      s.dispose();
      c.dispose();
    });

    test('tracks two signal dependencies', () {
      final a = Signal(1);
      final b = Signal(2);
      final c = Computed(() => a.value + b.value);

      expect(c.value, 3);

      a.value = 10;
      expect(c.value, 12);

      b.value = 20;
      expect(c.value, 30);

      a.dispose();
      b.dispose();
      c.dispose();
    });

    test('tracks five signal dependencies', () {
      final signals = List.generate(5, (i) => Signal(i + 1));
      final c = Computed(() => signals.fold<int>(0, (sum, s) => sum + s.value));

      expect(c.value, 15); // 1+2+3+4+5

      signals[0].value = 10;
      expect(c.value, 24); // 10+2+3+4+5

      for (final s in signals) {
        s.dispose();
      }
      c.dispose();
    });

    test('tracks ten signal dependencies', () {
      final signals = List.generate(10, (i) => Signal(1));
      final c = Computed(() => signals.fold<int>(0, (sum, s) => sum + s.value));

      expect(c.value, 10);

      for (var i = 0; i < 10; i++) {
        signals[i].value = 2;
      }
      expect(c.value, 20);

      for (final s in signals) {
        s.dispose();
      }
      c.dispose();
    });

    test('computed depending on computed', () {
      final s = Signal(1);
      final c1 = Computed(() => s.value * 2);
      final c2 = Computed(() => c1.value + 10);

      expect(c2.value, 12); // (1*2)+10

      s.value = 5;
      expect(c2.value, 20); // (5*2)+10

      s.dispose();
      c1.dispose();
      c2.dispose();
    });

    test('diamond dependency pattern', () {
      final source = Signal(1);
      final left = Computed(() => source.value + 1);
      final right = Computed(() => source.value + 2);
      final bottom = Computed(() => left.value + right.value);

      expect(bottom.value, 5); // (1+1) + (1+2)

      source.value = 10;
      expect(bottom.value, 23); // (10+1) + (10+2)

      source.dispose();
      left.dispose();
      right.dispose();
      bottom.dispose();
    });

    test('deep dependency chain of 5 levels', () {
      final s = Signal(1);
      final c1 = Computed(() => s.value + 1);
      final c2 = Computed(() => c1.value + 1);
      final c3 = Computed(() => c2.value + 1);
      final c4 = Computed(() => c3.value + 1);
      final c5 = Computed(() => c4.value + 1);

      expect(c5.value, 6);

      s.value = 10;
      expect(c5.value, 15);

      s.dispose();
      c1.dispose();
      c2.dispose();
      c3.dispose();
      c4.dispose();
      c5.dispose();
    });

    test('deep dependency chain of 10 levels', () {
      final s = Signal(0);
      var current = Computed(() => s.value);
      final computeds = <Computed<int>>[current];

      for (var i = 1; i < 10; i++) {
        final prev = current;
        current = Computed(() => prev.value + 1);
        computeds.add(current);
      }

      expect(current.value, 9);

      s.value = 10;
      expect(current.value, 19);

      s.dispose();
      for (final c in computeds) {
        c.dispose();
      }
    });

    test('dynamic dependency - conditional tracking', () {
      final condition = Signal(true);
      final a = Signal(1);
      final b = Signal(2);

      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return condition.value ? a.value : b.value;
      });

      expect(c.value, 1);
      expect(computeCount, 1);

      // Changing b should not trigger recompute when condition is true
      b.value = 20;
      expect(c.value, 1);
      expect(computeCount, 1); // b is not tracked

      // Change condition to false
      condition.value = false;
      expect(c.value, 20);
      expect(computeCount, 2);

      // Now a changes should not trigger
      a.value = 100;
      expect(c.value, 20);
      expect(computeCount, 2); // a is no longer tracked

      condition.dispose();
      a.dispose();
      b.dispose();
      c.dispose();
    });

    test('unused dependencies are cleaned up', () {
      final a = Signal(1);
      final b = Signal(2);
      final useA = Signal(true);

      var aAccessCount = 0;
      var bAccessCount = 0;

      final c = Computed(() {
        if (useA.value) {
          aAccessCount++;
          return a.value;
        } else {
          bAccessCount++;
          return b.value;
        }
      });

      expect(c.value, 1);
      expect(aAccessCount, 1);
      expect(bAccessCount, 0);

      // Switch to b
      useA.value = false;
      expect(c.value, 2);
      expect(bAccessCount, 1);

      // Now changing a should not affect computed
      a.value = 100;
      // Accessing value should not increment aAccessCount
      expect(c.value, 2);

      a.dispose();
      b.dispose();
      useA.dispose();
      c.dispose();
    });
  });

  // ============================================================================
  // Lazy Evaluation & Caching
  // ============================================================================

  group('Computed - Lazy Evaluation & Caching', () {
    test('not computed until first access', () {
      var computeCount = 0;
      final s = Signal(1);
      final c = Computed(() {
        computeCount++;
        return s.value * 2;
      });

      expect(computeCount, 0);

      s.value = 10; // Change before first access
      expect(computeCount, 0);

      expect(c.value, 20); // First access
      expect(computeCount, 1);

      s.dispose();
      c.dispose();
    });

    test('cached until dependency changes', () {
      var computeCount = 0;
      final s = Signal(1);
      final c = Computed(() {
        computeCount++;
        return s.value * 2;
      });

      expect(c.value, 2);
      expect(computeCount, 1);

      expect(c.value, 2);
      expect(c.value, 2);
      expect(c.value, 2);
      expect(computeCount, 1); // Still 1

      s.value = 5;
      expect(c.value, 10);
      expect(computeCount, 2);

      s.dispose();
      c.dispose();
    });

    test('only recomputes dirty values', () {
      var compute1Count = 0;
      var compute2Count = 0;

      final s1 = Signal(1);
      final s2 = Signal(10);

      final c1 = Computed(() {
        compute1Count++;
        return s1.value * 2;
      });

      final c2 = Computed(() {
        compute2Count++;
        return s2.value * 2;
      });

      expect(c1.value, 2);
      expect(c2.value, 20);
      expect(compute1Count, 1);
      expect(compute2Count, 1);

      s1.value = 5; // Only affects c1
      expect(c1.value, 10);
      expect(c2.value, 20);
      expect(compute1Count, 2);
      expect(compute2Count, 1); // c2 not recomputed

      s1.dispose();
      s2.dispose();
      c1.dispose();
      c2.dispose();
    });

    test('recomputes on access after dependency change', () {
      var computeCount = 0;
      final s = Signal(1);
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 1);
      expect(computeCount, 1);

      s.value = 2;
      s.value = 3;
      s.value = 4;
      // Not yet recomputed, just marked dirty

      expect(c.value, 4);
      expect(computeCount, 2); // Only one recompute

      s.dispose();
      c.dispose();
    });
  });

  // ============================================================================
  // Cycle Detection
  // ============================================================================

  group('Computed - Cycle Detection', () {
    test('direct self-reference throws StateError', () {
      late Computed<int> c;
      c = Computed(() => c.value + 1);

      expect(() => c.value, throwsStateError);

      c.dispose();
    });

    test('indirect cycle through computed throws StateError', () {
      late Computed<int> c1;
      late Computed<int> c2;

      c1 = Computed(() => c2.value + 1);
      c2 = Computed(() => c1.value + 1);

      expect(() => c1.value, throwsStateError);

      c1.dispose();
      c2.dispose();
    });

    test('three-node cycle throws StateError', () {
      late Computed<int> c1;
      late Computed<int> c2;
      late Computed<int> c3;

      c1 = Computed(() => c3.value + 1);
      c2 = Computed(() => c1.value + 1);
      c3 = Computed(() => c2.value + 1);

      expect(() => c1.value, throwsStateError);

      c1.dispose();
      c2.dispose();
      c3.dispose();
    });
  });

  // ============================================================================
  // Dispose Behavior
  // ============================================================================

  group('Computed - Dispose Behavior', () {
    test('disposed computed returns cached value', () {
      final s = Signal(42);
      final c = Computed(() => s.value * 2);

      expect(c.value, 84);

      c.dispose();

      expect(c.value, 84); // Still returns cached value

      s.dispose();
    });

    test('disposed computed stops tracking dependencies', () {
      var computeCount = 0;
      final s = Signal(1);
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 1);
      expect(computeCount, 1);

      c.dispose();

      s.value = 10;
      expect(c.value, 1); // Returns old cached value, doesn't recompute
      expect(computeCount, 1);

      s.dispose();
    });

    test('double dispose is safe', () {
      final c = Computed(() => 42);
      c.dispose();
      c.dispose(); // Should not throw
      expect(c.value, 42);
    });

    test('dispose in middle of chain', () {
      final s = Signal(1);
      final c1 = Computed(() => s.value * 2);
      final c2 = Computed(() => c1.value + 10);

      expect(c2.value, 12);

      c1.dispose();

      // c2 can still access c1's cached value
      s.value = 5;
      expect(c1.value, 2); // c1 returns cached
      expect(c2.value, 12); // c2 sees c1's cached value

      s.dispose();
      c2.dispose();
    });

    test('dispose source signal', () {
      final s = Signal(42);
      final c = Computed(() => s.value * 2);

      expect(c.value, 84);

      s.dispose();
      s.value = 100; // Ignored

      expect(c.value, 84); // Still cached

      c.dispose();
    });
  });

  // ============================================================================
  // Complex Scenarios
  // ============================================================================

  group('Computed - Complex Scenarios', () {
    test('many computeds from one signal', () {
      final s = Signal(10);
      final computeds = List.generate(20, (i) => Computed(() => s.value + i));

      for (var i = 0; i < 20; i++) {
        expect(computeds[i].value, 10 + i);
      }

      s.value = 100;

      for (var i = 0; i < 20; i++) {
        expect(computeds[i].value, 100 + i);
      }

      s.dispose();
      for (final c in computeds) {
        c.dispose();
      }
    });

    test('conditional dependency switching', () {
      final selector = Signal(0);
      final sources = [Signal(10), Signal(20), Signal(30)];

      final c = Computed(() => sources[selector.value].value);

      expect(c.value, 10);

      selector.value = 1;
      expect(c.value, 20);

      sources[1].value = 25;
      expect(c.value, 25);

      selector.value = 2;
      expect(c.value, 30);

      selector.dispose();
      for (final s in sources) {
        s.dispose();
      }
      c.dispose();
    });

    test('dependencies that return same value do not trigger recompute', () {
      final s = Signal(10);
      var computeCount = 0;

      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 10);
      expect(computeCount, 1);

      s.value = 10; // Same value
      expect(c.value, 10);
      expect(computeCount, 1); // No recompute

      s.dispose();
      c.dispose();
    });

    test('computed with side effects (counting)', () {
      final s = Signal(0);
      var sideEffectCount = 0;

      final c = Computed(() {
        sideEffectCount++;
        return s.value * 2;
      });

      expect(c.value, 0);
      expect(sideEffectCount, 1);

      s.value = 1;
      s.value = 2;
      s.value = 3;
      // Multiple changes but not accessed yet

      expect(c.value, 6);
      expect(sideEffectCount, 2); // Only one additional compute

      s.dispose();
      c.dispose();
    });

    test('wide dependency tree', () {
      final signals = List.generate(10, Signal.new);
      final layer1 = List.generate(
        5,
        (i) => Computed(() => signals[i * 2].value + signals[i * 2 + 1].value),
      );
      final layer2 = [
        Computed(() => layer1[0].value + layer1[1].value),
        Computed(() => layer1[2].value + layer1[3].value + layer1[4].value),
      ];
      final root = Computed(() => layer2[0].value + layer2[1].value);

      // 0+1+2+3+4+5+6+7+8+9 = 45
      expect(root.value, 45);

      signals[0].value = 100;
      expect(root.value, 145);

      for (final s in signals) {
        s.dispose();
      }
      for (final c in layer1) {
        c.dispose();
      }
      for (final c in layer2) {
        c.dispose();
      }
      root.dispose();
    });

    test('computed returns different types', () {
      final s = Signal(5);

      final intC = Computed<int>(() => s.value);
      final doubleC = Computed<double>(() => s.value.toDouble());
      final stringC = Computed<String>(() => s.value.toString());
      final boolC = Computed<bool>(() => s.value > 3);

      expect(intC.value, 5);
      expect(doubleC.value, 5.0);
      expect(stringC.value, '5');
      expect(boolC.value, true);

      s.value = 2;

      expect(intC.value, 2);
      expect(doubleC.value, 2.0);
      expect(stringC.value, '2');
      expect(boolC.value, false);

      s.dispose();
      intC.dispose();
      doubleC.dispose();
      stringC.dispose();
      boolC.dispose();
    });

    test('computed with nullable return', () {
      final s = Signal<int?>(null);
      final c = Computed<int?>(() => s.value);

      expect(c.value, isNull);

      s.value = 42;
      expect(c.value, 42);

      s.value = null;
      expect(c.value, isNull);

      s.dispose();
      c.dispose();
    });

    test('computed accessing multiple properties of same signal', () {
      final s = Signal<(int, String)>((1, 'hello'));
      final c = Computed(() => '${s.value.$1}: ${s.value.$2}');

      expect(c.value, '1: hello');

      s.value = (42, 'world');
      expect(c.value, '42: world');

      s.dispose();
      c.dispose();
    });

    test('computed with list manipulation', () {
      final s = Signal<List<int>>([1, 2, 3]);
      final sum = Computed(() => s.value.fold<int>(0, (a, b) => a + b));
      final length = Computed(() => s.value.length);

      expect(sum.value, 6);
      expect(length.value, 3);

      s.value = [1, 2, 3, 4, 5];
      expect(sum.value, 15);
      expect(length.value, 5);

      s.dispose();
      sum.dispose();
      length.dispose();
    });

    test('computed with map operations', () {
      final s = Signal<Map<String, int>>({'a': 1, 'b': 2});
      final keys = Computed(() => s.value.keys.toList()..sort());
      final values =
          Computed(() => s.value.values.fold<int>(0, (a, b) => a + b));

      expect(keys.value, ['a', 'b']);
      expect(values.value, 3);

      s.value = {'x': 10, 'y': 20, 'z': 30};
      expect(keys.value, ['x', 'y', 'z']);
      expect(values.value, 60);

      s.dispose();
      keys.dispose();
      values.dispose();
    });
  });

  // ============================================================================
  // Edge Cases
  // ============================================================================

  group('Computed - Edge Cases', () {
    test('computed that throws on first access', () {
      final c = Computed<int>(() => throw Exception('test error'));

      expect(() => c.value, throwsException);

      c.dispose();
    });

    test('computed that throws conditionally', () {
      final s = Signal(false);
      final c = Computed<int>(() {
        if (s.value) throw Exception('error');
        return 42;
      });

      expect(c.value, 42);

      s.value = true;
      expect(() => c.value, throwsException);

      s.value = false;
      expect(c.value, 42);

      s.dispose();
      c.dispose();
    });

    test('computed with very long computation', () {
      final s = Signal(1000000);
      final c = Computed(() {
        var sum = 0;
        for (var i = 0; i < s.value; i++) {
          sum += i;
        }
        return sum;
      });

      expect(c.value, 499999500000);

      c.dispose();
      s.dispose();
    });

    test('accessing computed during its own recomputation through dependency',
        () {
      final s = Signal(1);
      late Computed<int> c;
      c = Computed(() {
        if (s.value > 5) {
          // This would cause a cycle if we accessed c.value here
          // But we're just accessing s.value
          return s.value * 2;
        }
        return s.value;
      });

      expect(c.value, 1);
      s.value = 10;
      expect(c.value, 20);

      s.dispose();
      c.dispose();
    });

    test('computed with closure capturing external state', () {
      var external = 10;
      final s = Signal(5);
      final c = Computed(() => s.value + external);

      expect(c.value, 15);

      external = 20;
      // External change doesn't trigger recompute
      expect(c.value, 15);

      s.value = 6; // Signal change triggers recompute
      expect(c.value, 26);

      s.dispose();
      c.dispose();
    });

    test('rapidly creating and disposing computeds', () {
      final s = Signal(1);

      for (var i = 0; i < 100; i++) {
        final c = Computed(() => s.value * i);
        expect(c.value, i);
        c.dispose();
      }

      s.dispose();
    });

    test('computed with boolean logic', () {
      final a = Signal(true);
      final b = Signal(false);
      final andResult = Computed(() => a.value && b.value);
      final orResult = Computed(() => a.value || b.value);

      expect(andResult.value, false);
      expect(orResult.value, true);

      b.value = true;
      expect(andResult.value, true);
      expect(orResult.value, true);

      a.dispose();
      b.dispose();
      andResult.dispose();
      orResult.dispose();
    });

    test('computed with string concatenation', () {
      final firstName = Signal('John');
      final lastName = Signal('Doe');
      final fullName = Computed(() => '${firstName.value} ${lastName.value}');

      expect(fullName.value, 'John Doe');

      firstName.value = 'Jane';
      expect(fullName.value, 'Jane Doe');

      lastName.value = 'Smith';
      expect(fullName.value, 'Jane Smith');

      firstName.dispose();
      lastName.dispose();
      fullName.dispose();
    });
    test('computed stream', () async {
      const target = 42;
      final source = Signal(0);
      final c = Computed(() => source.value);
      final values = <int>[];
      final sub = c.listen(values.add);
      expect(values, isEmpty);
      source.value = target;
      expect(values, [target]);
      await sub.cancel();
    });
    test('computed filtering list', () {
      final numbers = Signal([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final evens = Computed(
        () => numbers.value.where((n) => n.isEven).toList(),
      );

      expect(evens.value, [2, 4, 6, 8, 10]);

      numbers.value = [1, 3, 5, 7, 9];
      expect(evens.value, isEmpty);

      numbers.dispose();
      evens.dispose();
    });

    test('computed with date operations', () {
      final date = Signal(DateTime(2023, 1, 15));
      final isWeekend = Computed(
        () =>
            date.value.weekday == DateTime.saturday ||
            date.value.weekday == DateTime.sunday,
      );

      expect(isWeekend.value, true); // Jan 15, 2023 is Sunday

      date.value = DateTime(2023, 1, 16); // Monday
      expect(isWeekend.value, false);

      date.dispose();
      isWeekend.dispose();
    });

    test('computed chain performance', () {
      final source = Signal(0);
      final computeds = <Computed<int>>[];

      // Create a chain of 50 computeds
      var current = Computed(() => source.value);
      computeds.add(current);

      for (var i = 1; i < 50; i++) {
        final prev = current;
        current = Computed(() => prev.value + 1);
        computeds.add(current);
      }

      expect(current.value, 49);

      source.value = 100;
      expect(current.value, 149);

      source.dispose();
      for (final c in computeds) {
        c.dispose();
      }
    });

    test('computed with enum values', () {
      final status = Signal(_Status.pending);
      final isComplete = Computed(() => status.value == _Status.completed);
      final statusText = Computed(() {
        switch (status.value) {
          case _Status.pending:
            return 'Pending';
          case _Status.running:
            return 'Running';
          case _Status.completed:
            return 'Completed';
        }
      });

      expect(isComplete.value, false);
      expect(statusText.value, 'Pending');

      status.value = _Status.completed;
      expect(isComplete.value, true);
      expect(statusText.value, 'Completed');

      status.dispose();
      isComplete.dispose();
      statusText.dispose();
    });
  });
}

enum _Status { pending, running, completed }
