import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

void main() {
  group('Signal', () {
    test('basic read/write', () {
      final s = Signal(0);
      expect(s.value, 0);
      s.value = 42;
      expect(s.value, 42);
      s.dispose();
    });

    test('update function', () {
      final s = Signal(10);
      s.update((v) => v + 5);
      expect(s.value, 15);
      s.dispose();
    });
  });

  group('Computed', () {
    test('basic computed', () {
      final a = Signal(1);
      final b = Signal(2);
      final sum = Computed(() => a.value + b.value);

      expect(sum.value, 3);

      a.value = 10;
      expect(sum.value, 12);

      sum.dispose();
      b.dispose();
      a.dispose();
    });

    test('computed chain', () {
      final source = Signal(1);
      final c1 = Computed(() => source.value + 1);
      final c2 = Computed(() => c1.value * 2);

      expect(c2.value, 4); // (1+1)*2

      source.value = 5;
      expect(c2.value, 12); // (5+1)*2

      c2.dispose();
      c1.dispose();
      source.dispose();
    });

    test('diamond dependency', () {
      final source = Signal(1);
      final left = Computed(() => source.value + 1);
      final right = Computed(() => source.value + 2);
      final bottom = Computed(() => left.value + right.value);

      expect(bottom.value, 5); // (1+1) + (1+2)

      source.value = 10;
      expect(bottom.value, 23); // (10+1) + (10+2)

      bottom.dispose();
      right.dispose();
      left.dispose();
      source.dispose();
    });
  });

  group('Signal.batch', () {
    test('batches updates', () {
      final s = Signal(0);
      final c = Computed(() => s.value * 2);

      // Access to build dependency
      expect(c.value, 0);

      Signal.batch(() {
        s.value = 1;
        s.value = 2;
        s.value = 3;
      });

      expect(c.value, 6);

      c.dispose();
      s.dispose();
    });

    test('nested batches', () {
      final s = Signal(0);
      final c = Computed(() => s.value);

      expect(c.value, 0);

      Signal.batch(() {
        s.value = 1;
        Signal.batch(() {
          s.value = 2;
        });
        s.value = 3;
      });

      expect(c.value, 3);

      c.dispose();
      s.dispose();
    });
  });
}
