import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

void main() {
  group('DependencyNode - No Pool', () {
    test('computed works after dispose and recreate', () {
      final store = Store<int>(0);
      final computeds = List.generate(100, (_) => Computed(() => store.value * 2));
      for (final c in computeds) { c.value; }
      for (final c in computeds) { c.dispose(); }

      final newComputeds = List.generate(100, (_) => Computed(() => store.value * 3));
      for (final c in newComputeds) { expect(c.value, 0); }
      store.value = 5;
      for (final c in newComputeds) { expect(c.value, 15); }

      for (final c in newComputeds) { c.dispose(); }
      store.dispose();
    });

    test('large dependency graph works', () {
      final stores = List.generate(200, (i) => Store<int>(i));
      final computed = Computed(() {
        var sum = 0;
        for (final s in stores) { sum += s.value; }
        return sum;
      });
      expect(computed.value, 19900);
      computed.dispose();

      final small = Computed(() => stores[0].value + stores[1].value);
      expect(small.value, 1);
      stores[0].value = 100;
      expect(small.value, 101);

      small.dispose();
      for (final s in stores) { s.dispose(); }
    });

    test('rapid create-dispose cycles', () {
      final store = Store<int>(42);
      for (var i = 0; i < 1000; i++) {
        final c = Computed(() => store.value * i);
        c.value;
        c.dispose();
      }
      final finalC = Computed(() => store.value + 1);
      expect(finalC.value, 43);
      store.value = 0;
      expect(finalC.value, 1);
      finalC.dispose();
      store.dispose();
    });
  });
}
