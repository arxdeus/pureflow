import 'package:flutter_test/flutter_test.dart';
import 'package:pureflow_flutter/pureflow_flutter.dart';

void main() {
  group('asListenable', () {
    test('returns the same adapter for repeated calls on one Store', () {
      final store = Store(0);

      expect(identical(store.asListenable, store.asListenable), isTrue);
    });

    test('value reflects the latest Store value', () {
      final store = Store(0);
      final listenable = store.asListenable;

      store.value = 1;

      expect(listenable.value, 1);
    });

    test('addListener and removeListener delegate to the Store', () {
      final store = Store(0);
      final listenable = store.asListenable;
      var calls = 0;
      void listener() => calls++;

      listenable.addListener(listener);
      store.value = 1;
      listenable.removeListener(listener);
      store.value = 2;

      expect(calls, 1);
    });

    test('works with Computed values', () {
      final count = Store(1);
      final doubled = Computed(() => count.value * 2);
      final listenable = doubled.asListenable;

      expect(listenable.value, 2);

      count.value = 3;

      expect(listenable.value, 6);
    });
  });
}
