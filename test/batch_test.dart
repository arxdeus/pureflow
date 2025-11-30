import '../packages/pureflow/lib/pureflow.dart';
import 'package:test/test.dart';

void main() {
  // ============================================================================
  // Basic Operations
  // ============================================================================

  group('ValueUnit.batch - Basic Operations', () {
    test('single signal update in batch', () {
      final s = Store(0);
      final c = Computed(() => s.value);

      expect(c.value, 0);

      Store.batch(() {
        s.value = 42;
      });

      expect(c.value, 42);

      s.dispose();
      c.dispose();
    });

    test('multiple updates to same signal in batch', () {
      final s = Store(0);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 0);
      expect(computeCount, 1);

      Store.batch(() {
        s.value = 1;
        s.value = 2;
        s.value = 3;
        s.value = 4;
        s.value = 5;
      });

      expect(c.value, 5);
      expect(computeCount, 2); // Only one recompute after batch

      s.dispose();
      c.dispose();
    });

    test('batch returns value', () {
      final result = Store.batch(() => 42);
      expect(result, 42);
    });

    test('batch returns complex value', () {
      final result = Store.batch(() {
        return {'a': 1, 'b': 2};
      });
      expect(result, {'a': 1, 'b': 2});
    });

    test('batch with multiple signals', () {
      final a = Store(0);
      final b = Store(0);
      final c = Store(0);

      var computeCount = 0;
      final sum = Computed(() {
        computeCount++;
        return a.value + b.value + c.value;
      });

      expect(sum.value, 0);
      expect(computeCount, 1);

      Store.batch(() {
        a.value = 1;
        b.value = 2;
        c.value = 3;
      });

      expect(sum.value, 6);
      expect(computeCount, 2);

      a.dispose();
      b.dispose();
      c.dispose();
      sum.dispose();
    });

    test('batch with signal and computed access', () {
      final s = Store(10);
      final c = Computed(() => s.value * 2);

      expect(c.value, 20);

      final result = Store.batch(() {
        s.value = 5;
        // Inside batch, computed still sees old value because
        // signals haven't notified dependents yet
        return c.value;
      });

      // Inside batch, computed sees cached value (old)
      expect(result, 20);
      // After batch, computed sees new value
      expect(c.value, 10);

      s.dispose();
      c.dispose();
    });
  });

  // ============================================================================
  // Notification Behavior
  // ============================================================================

  group('ValueUnit.batch - Notification Behavior', () {
    test('only notifies once after batch', () {
      final s = Store(0);
      var notifyCount = 0;

      final c = Computed(() {
        notifyCount++;
        return s.value;
      });

      expect(c.value, 0);
      expect(notifyCount, 1);

      Store.batch(() {
        s.value = 1;
        s.value = 2;
        s.value = 3;
      });

      expect(c.value, 3);
      expect(notifyCount, 2);

      s.dispose();
      c.dispose();
    });

    test('no intermediate notifications during batch', () {
      final s = Store(0);
      final values = <int>[];

      final c = Computed(() {
        values.add(s.value);
        return s.value;
      });

      expect(c.value, 0);
      expect(values, [0]);

      Store.batch(() {
        s.value = 1;
        s.value = 2;
        s.value = 3;
      });

      expect(c.value, 3);
      expect(values, [0, 3]); // No 1, 2 intermediate values

      s.dispose();
      c.dispose();
    });

    test('computed sees final value after batch', () {
      final s = Store(0);
      final c = Computed(() => s.value * 10);

      expect(c.value, 0);

      Store.batch(() {
        s.value = 1; // Would be 10
        s.value = 2; // Would be 20
        s.value = 5; // Will be 50
      });

      expect(c.value, 50);

      s.dispose();
      c.dispose();
    });

    test('multiple computeds notified once each', () {
      final s = Store(0);
      var c1Count = 0;
      var c2Count = 0;
      var c3Count = 0;

      final c1 = Computed(() {
        c1Count++;
        return s.value + 1;
      });
      final c2 = Computed(() {
        c2Count++;
        return s.value + 2;
      });
      final c3 = Computed(() {
        c3Count++;
        return s.value + 3;
      });

      expect(c1.value, 1);
      expect(c2.value, 2);
      expect(c3.value, 3);
      expect(c1Count, 1);
      expect(c2Count, 1);
      expect(c3Count, 1);

      Store.batch(() {
        s.value = 10;
        s.value = 20;
      });

      expect(c1.value, 21);
      expect(c2.value, 22);
      expect(c3.value, 23);
      expect(c1Count, 2);
      expect(c2Count, 2);
      expect(c3Count, 2);

      s.dispose();
      c1.dispose();
      c2.dispose();
      c3.dispose();
    });

    test('diamond dependency notified once', () {
      final source = Store(1);
      var leftCount = 0;
      var rightCount = 0;
      var bottomCount = 0;

      final left = Computed(() {
        leftCount++;
        return source.value + 1;
      });
      final right = Computed(() {
        rightCount++;
        return source.value + 2;
      });
      final bottom = Computed(() {
        bottomCount++;
        return left.value + right.value;
      });

      expect(bottom.value, 5);
      expect(leftCount, 1);
      expect(rightCount, 1);
      expect(bottomCount, 1);

      Store.batch(() {
        source.value = 10;
        source.value = 20;
        source.value = 30;
      });

      expect(bottom.value, 63); // (30+1) + (30+2)
      expect(leftCount, 2);
      expect(rightCount, 2);
      expect(bottomCount, 2);

      source.dispose();
      left.dispose();
      right.dispose();
      bottom.dispose();
    });
  });

  // ============================================================================
  // Nesting
  // ============================================================================

  group('ValueUnit.batch - Nesting', () {
    test('nested batch two levels', () {
      final s = Store(0);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 0);
      expect(computeCount, 1);

      Store.batch(() {
        s.value = 1;
        Store.batch(() {
          s.value = 2;
        });
        s.value = 3;
      });

      expect(c.value, 3);
      expect(computeCount, 2);

      s.dispose();
      c.dispose();
    });

    test('deeply nested batch five levels', () {
      final s = Store(0);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 0);
      expect(computeCount, 1);

      Store.batch(() {
        s.value = 1;
        Store.batch(() {
          s.value = 2;
          Store.batch(() {
            s.value = 3;
            Store.batch(() {
              s.value = 4;
              Store.batch(() {
                s.value = 5;
              });
            });
          });
        });
      });

      expect(c.value, 5);
      expect(computeCount, 2);

      s.dispose();
      c.dispose();
    });

    test('nested batch with return values', () {
      final s = Store(0);

      final result = Store.batch(() {
        s.value = 1;
        final inner = Store.batch(() {
          s.value = 2;
          return 'inner';
        });
        s.value = 3;
        return 'outer: $inner';
      });

      expect(result, 'outer: inner');
      expect(s.value, 3);

      s.dispose();
    });

    test('nested batches with different signals', () {
      final a = Store(0);
      final b = Store(0);
      var aCount = 0;
      var bCount = 0;

      final ca = Computed(() {
        aCount++;
        return a.value;
      });
      final cb = Computed(() {
        bCount++;
        return b.value;
      });

      expect(ca.value, 0);
      expect(cb.value, 0);
      expect(aCount, 1);
      expect(bCount, 1);

      Store.batch(() {
        a.value = 1;
        Store.batch(() {
          b.value = 2;
        });
        a.value = 3;
      });

      expect(ca.value, 3);
      expect(cb.value, 2);
      expect(aCount, 2);
      expect(bCount, 2);

      a.dispose();
      b.dispose();
      ca.dispose();
      cb.dispose();
    });

    test('nested batch does not flush early', () {
      final s = Store(0);
      final values = <int>[];

      final c = Computed(() {
        values.add(s.value);
        return s.value;
      });

      expect(c.value, 0);

      Store.batch(() {
        s.value = 1;
        Store.batch(() {
          s.value = 2;
          // Inner batch ends but should not flush
        });
        // Outer batch continues
        s.value = 3;
      });

      expect(c.value, 3);
      expect(values, [0, 3]); // No intermediate values

      s.dispose();
      c.dispose();
    });
  });

  // ============================================================================
  // Error Handling
  // ============================================================================

  group('ValueUnit.batch - Error Handling', () {
    test('exception in batch still flushes', () {
      final s = Store(0);
      final c = Computed(() => s.value);

      expect(c.value, 0);

      expect(
        () => Store.batch(() {
          s.value = 42;
          throw Exception('test error');
        }),
        throwsException,
      );

      // Batch should still have flushed
      expect(c.value, 42);

      s.dispose();
      c.dispose();
    });

    test('exception in nested batch flushes correctly', () {
      final s = Store(0);
      final c = Computed(() => s.value);

      expect(c.value, 0);

      expect(
        () => Store.batch(() {
          s.value = 1;
          Store.batch(() {
            s.value = 2;
            throw Exception('inner error');
          });
        }),
        throwsException,
      );

      // After exception, batch should flush
      expect(c.value, 2);

      s.dispose();
      c.dispose();
    });

    test('batch after exception works normally', () {
      final s = Store(0);
      final c = Computed(() => s.value);

      expect(c.value, 0);

      try {
        Store.batch(() {
          s.value = 1;
          throw Exception('error');
        });
      } catch (_) {}

      expect(c.value, 1);

      // New batch should work fine
      Store.batch(() {
        s.value = 100;
      });

      expect(c.value, 100);

      s.dispose();
      c.dispose();
    });

    test('exception does not break subsequent nesting', () {
      final s = Store(0);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 0);
      expect(computeCount, 1);

      try {
        Store.batch(() {
          throw Exception('error');
        });
      } catch (_) {}

      // Nested batch should work
      Store.batch(() {
        s.value = 1;
        Store.batch(() {
          s.value = 2;
        });
        s.value = 3;
      });

      expect(c.value, 3);
      expect(computeCount, 2);

      s.dispose();
      c.dispose();
    });
  });

  // ============================================================================
  // Edge Cases
  // ============================================================================

  group('ValueUnit.batch - Edge Cases', () {
    test('empty batch', () {
      final result = Store.batch(() {});
      expect(result, isNull);
    });

    test('batch with no signal changes', () {
      final s = Store(42);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 42);
      expect(computeCount, 1);

      Store.batch(() {
        // No changes
        final _ = s.value; // Just read
      });

      expect(c.value, 42);
      expect(computeCount, 1);

      s.dispose();
      c.dispose();
    });

    test('batch after signal dispose', () {
      final s = Store(0);
      final c = Computed(() => s.value);

      expect(c.value, 0);

      s.dispose();

      Store.batch(() {
        s.value = 42; // Should be ignored
      });

      expect(c.value, 0);

      c.dispose();
    });

    test('batch with disposed signal among others', () {
      final a = Store(1);
      final b = Store(2);
      final sum = Computed(() => a.value + b.value);

      expect(sum.value, 3);

      a.dispose();

      Store.batch(() {
        a.value = 100; // Ignored
        b.value = 20;
      });

      expect(sum.value, 21); // 1 (disposed, unchanged) + 20

      b.dispose();
      sum.dispose();
    });

    test('interleaved batch and non-batch updates', () {
      final s = Store(0);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 0);
      expect(computeCount, 1);

      s.value = 1; // Non-batch
      expect(c.value, 1);
      expect(computeCount, 2);

      Store.batch(() {
        s.value = 2;
        s.value = 3;
      });
      expect(c.value, 3);
      expect(computeCount, 3);

      s.value = 4; // Non-batch again
      expect(c.value, 4);
      expect(computeCount, 4);

      s.dispose();
      c.dispose();
    });

    test('batch with same value updates', () {
      final s = Store(42);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 42);
      expect(computeCount, 1);

      Store.batch(() {
        s.value = 42; // Same value
        s.value = 42; // Same value
      });

      expect(c.value, 42);
      expect(computeCount, 1); // No recompute

      s.dispose();
      c.dispose();
    });

    test('batch setting then reverting value', () {
      final s = Store(0);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 0);
      expect(computeCount, 1);

      Store.batch(() {
        s.value = 1;
        s.value = 2;
        s.value = 0; // Back to original
      });

      // Value is same as original, but signal was modified during batch
      expect(c.value, 0);
      // The signal was in the batch list, so it notifies once
      expect(computeCount, 2);

      s.dispose();
      c.dispose();
    });
  });

  // ============================================================================
  // Performance
  // ============================================================================

  group('ValueUnit.batch - Performance', () {
    test('many signals in single batch', () {
      final signals = List.generate(100, (i) => Store(0));
      var computeCount = 0;
      final sum = Computed(() {
        computeCount++;
        return signals.fold<int>(0, (sum, s) => sum + s.value);
      });

      expect(sum.value, 0);
      expect(computeCount, 1);

      Store.batch(() {
        for (var i = 0; i < 100; i++) {
          signals[i].value = i + 1;
        }
      });

      expect(sum.value, 5050); // Sum of 1 to 100
      expect(computeCount, 2);

      for (final s in signals) {
        s.dispose();
      }
      sum.dispose();
    });

    test('many updates to single signal in batch', () {
      final s = Store(0);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 0);
      expect(computeCount, 1);

      Store.batch(() {
        for (var i = 0; i < 1000; i++) {
          s.value = i;
        }
      });

      expect(c.value, 999);
      expect(computeCount, 2);

      s.dispose();
      c.dispose();
    });

    test('batch with many computeds', () {
      final s = Store(0);
      var totalComputeCount = 0;

      final computeds = List.generate(50, (i) {
        return Computed(() {
          totalComputeCount++;
          return s.value + i;
        });
      });

      // Initial access
      for (var i = 0; i < 50; i++) {
        expect(computeds[i].value, i);
      }
      expect(totalComputeCount, 50);

      Store.batch(() {
        s.value = 100;
        s.value = 200;
      });

      for (var i = 0; i < 50; i++) {
        expect(computeds[i].value, 200 + i);
      }
      expect(totalComputeCount, 100);

      s.dispose();
      for (final c in computeds) {
        c.dispose();
      }
    });

    test('deeply nested batch performance', () {
      final s = Store(0);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 0);
      expect(computeCount, 1);

      void nestedBatch(int depth, int maxDepth) {
        if (depth >= maxDepth) {
          s.value = depth;
          return;
        }
        Store.batch(() {
          s.value = depth;
          nestedBatch(depth + 1, maxDepth);
        });
      }

      Store.batch(() {
        nestedBatch(1, 20);
      });

      expect(c.value, 20);
      expect(computeCount, 2);

      s.dispose();
      c.dispose();
    });
  });

  // ============================================================================
  // Complex Scenarios
  // ============================================================================

  group('ValueUnit.batch - Complex Scenarios', () {
    test('batch with computed chain', () {
      final s = Store(1);
      final c1 = Computed(() => s.value * 2);
      final c2 = Computed(() => c1.value * 2);
      final c3 = Computed(() => c2.value * 2);

      expect(c3.value, 8);

      Store.batch(() {
        s.value = 2;
        s.value = 3;
        s.value = 4;
        s.value = 5;
      });

      expect(c3.value, 40); // 5*2*2*2

      s.dispose();
      c1.dispose();
      c2.dispose();
      c3.dispose();
    });

    test('batch with diamond and chain', () {
      final source = Store(1);
      final left = Computed(() => source.value + 1);
      final right = Computed(() => source.value + 2);
      final middle = Computed(() => left.value + right.value);
      final end = Computed(() => middle.value * 2);

      expect(end.value, 10); // ((1+1)+(1+2))*2 = 10

      Store.batch(() {
        source.value = 10;
        source.value = 20;
      });

      expect(end.value, 86); // ((20+1)+(20+2))*2 = 86

      source.dispose();
      left.dispose();
      right.dispose();
      middle.dispose();
      end.dispose();
    });

    test('batch with conditional computed', () {
      final condition = Store(true);
      final a = Store(1);
      final b = Store(2);
      var computeCount = 0;

      final c = Computed(() {
        computeCount++;
        return condition.value ? a.value : b.value;
      });

      expect(c.value, 1);
      expect(computeCount, 1);

      Store.batch(() {
        a.value = 10;
        b.value = 20;
        condition.value = false;
      });

      expect(c.value, 20);
      expect(computeCount, 2);

      condition.dispose();
      a.dispose();
      b.dispose();
      c.dispose();
    });

    test('batch does not affect reading', () {
      final s = Store(0);

      final result = Store.batch(() {
        s.value = 1;
        final v1 = s.value;
        s.value = 2;
        final v2 = s.value;
        s.value = 3;
        final v3 = s.value;
        return [v1, v2, v3];
      });

      expect(result, [1, 2, 3]);
      expect(s.value, 3);

      s.dispose();
    });

    test('multiple batches in sequence', () {
      final s = Store(0);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return s.value;
      });

      expect(c.value, 0);
      expect(computeCount, 1);

      Store.batch(() {
        s.value = 1;
      });
      expect(c.value, 1);
      expect(computeCount, 2);

      Store.batch(() {
        s.value = 2;
      });
      expect(c.value, 2);
      expect(computeCount, 3);

      Store.batch(() {
        s.value = 3;
      });
      expect(c.value, 3);
      expect(computeCount, 4);

      s.dispose();
      c.dispose();
    });

    test('batch with async-like pattern (sync execution)', () {
      final s = Store(0);
      final c = Computed(() => s.value);

      expect(c.value, 0);

      final result = Store.batch(() {
        s.value = 1;
        // Simulate async-like step by step updates
        s.value = 2;
        s.value = 3;
        return 'done';
      });

      expect(result, 'done');
      expect(c.value, 3);

      s.dispose();
      c.dispose();
    });

    test('batch preserves update order', () {
      final a = Store(0);
      final b = Store(0);
      final history = <String>[];

      final c = Computed(() {
        history.add('a=${a.value}, b=${b.value}');
        return a.value + b.value;
      });

      expect(c.value, 0);
      expect(history, ['a=0, b=0']);

      Store.batch(() {
        a.value = 1;
        b.value = 2;
      });

      expect(c.value, 3);
      expect(history, ['a=0, b=0', 'a=1, b=2']);

      a.dispose();
      b.dispose();
      c.dispose();
    });

    test('batch with list signal updates', () {
      final list = Store<List<int>>([1, 2, 3]);
      final sum = Computed(() => list.value.fold<int>(0, (a, b) => a + b));

      expect(sum.value, 6);

      Store.batch(() {
        list.value = [4, 5, 6];
        list.value = [7, 8, 9];
      });

      expect(sum.value, 24);

      list.dispose();
      sum.dispose();
    });

    test('batch with boolean signal toggles', () {
      final toggle = Store(false);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return toggle.value;
      });

      expect(c.value, false);
      expect(computeCount, 1);

      Store.batch(() {
        toggle.value = true;
        toggle.value = false;
        toggle.value = true;
        toggle.value = false;
      });

      // Final value is same as original, but was modified
      expect(c.value, false);
      expect(computeCount, 2);

      toggle.dispose();
      c.dispose();
    });

    test('batch with string signal updates', () {
      final text = Store('hello');
      final length = Computed(() => text.value.length);

      expect(length.value, 5);

      Store.batch(() {
        text.value = 'world';
        text.value = 'hello world';
      });

      expect(length.value, 11);

      text.dispose();
      length.dispose();
    });

    test('batch with map signal', () {
      final map = Store<Map<String, int>>({'a': 1});
      final keys = Computed(() => map.value.keys.toList()..sort());

      expect(keys.value, ['a']);

      Store.batch(() {
        map.value = {'a': 1, 'b': 2};
        map.value = {'a': 1, 'b': 2, 'c': 3};
      });

      expect(keys.value, ['a', 'b', 'c']);

      map.dispose();
      keys.dispose();
    });

    test('batch does not affect unrelated signals', () {
      final s1 = Store(0);
      final s2 = Store(0);
      var c1Count = 0;
      var c2Count = 0;

      final c1 = Computed(() {
        c1Count++;
        return s1.value;
      });
      final c2 = Computed(() {
        c2Count++;
        return s2.value;
      });

      expect(c1.value, 0);
      expect(c2.value, 0);
      expect(c1Count, 1);
      expect(c2Count, 1);

      // Batch only updates s1
      Store.batch(() {
        s1.value = 1;
        s1.value = 2;
      });

      expect(c1.value, 2);
      expect(c2.value, 0);
      expect(c1Count, 2);
      expect(c2Count, 1); // c2 not recomputed

      s1.dispose();
      s2.dispose();
      c1.dispose();
      c2.dispose();
    });

    test('batch with counter pattern', () {
      final counter = Store(0);
      var computeCount = 0;
      final c = Computed(() {
        computeCount++;
        return counter.value;
      });

      expect(c.value, 0);
      expect(computeCount, 1);

      Store.batch(() {
        for (var i = 0; i < 100; i++) {
          counter.update((v) => v + 1);
        }
      });

      expect(c.value, 100);
      expect(computeCount, 2);

      counter.dispose();
      c.dispose();
    });

    test('batch return type preserved', () {
      final intResult = Store.batch(() => 42);
      expect(intResult, isA<int>());
      expect(intResult, 42);

      final stringResult = Store.batch(() => 'hello');
      expect(stringResult, isA<String>());
      expect(stringResult, 'hello');

      final listResult = Store.batch(() => [1, 2, 3]);
      expect(listResult, isA<List<int>>());
      expect(listResult, [1, 2, 3]);

      final mapResult = Store.batch(() => {'a': 1});
      expect(mapResult, isA<Map<String, int>>());
      expect(mapResult, {'a': 1});
    });

    test('batch with complex dependency graph', () {
      final a = Store(1);
      final b = Store(2);
      final c = Store(3);

      final ab = Computed(() => a.value + b.value);
      final bc = Computed(() => b.value + c.value);
      final abc = Computed(() => ab.value + bc.value - b.value);

      expect(abc.value, 6); // a + b + c = 1 + 2 + 3

      Store.batch(() {
        a.value = 10;
        b.value = 20;
        c.value = 30;
      });

      expect(abc.value, 60); // 10 + 20 + 30

      a.dispose();
      b.dispose();
      c.dispose();
      ab.dispose();
      bc.dispose();
      abc.dispose();
    });

    test('batch with mixed types', () {
      final num = Store(42);
      final text = Store('hello');
      final flag = Store(true);

      final result = Computed(() => '${num.value}-${text.value}-${flag.value}');

      expect(result.value, '42-hello-true');

      Store.batch(() {
        num.value = 100;
        text.value = 'world';
        flag.value = false;
      });

      expect(result.value, '100-world-false');

      num.dispose();
      text.dispose();
      flag.dispose();
      result.dispose();
    });
  });
}
