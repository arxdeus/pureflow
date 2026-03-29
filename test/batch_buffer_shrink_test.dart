import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

void main() {
  group('Batch buffer', () {
    test('large batch works', () {
      final stores = List.generate(200, (i) => Store<int>(i));
      var n = 0;
      for (final s in stores) {
        s.addListener(() => n++);
      }
      batch(() {
        for (var i = 0; i < stores.length; i++) {
          stores[i].value = i + 1000;
        }
      });
      expect(n, 200);
      for (final s in stores) {
        s.dispose();
      }
    });

    test('small batch after large batch works', () {
      final large = List.generate(200, (i) => Store<int>(i));
      batch(() {
        for (final s in large) {
          s.value = 999;
        }
      });
      for (final s in large) {
        s.dispose();
      }

      final a = Store<int>(0), b = Store<int>(0);
      var c = 0;
      a.addListener(() => c++);
      b.addListener(() => c++);
      batch(() {
        a.value = 1;
        b.value = 2;
      });
      expect(c, 2);
      a.dispose();
      b.dispose();
    });

    test('re-entrant batch with single store', () {
      final a = Store<int>(0), b = Store<int>(0), c = Store<int>(0);
      a.addListener(() {
        batch(() {
          b.value = 100;
        });
      });
      var bN = false, cN = false;
      b.addListener(() => bN = true);
      c.addListener(() => cN = true);
      batch(() {
        a.value = 1;
        c.value = 2;
      });
      expect(b.value, 100);
      expect(bN, true);
      expect(cN, true);
      a.dispose();
      b.dispose();
      c.dispose();
    });

    test('re-entrant batch with multiple stores', () {
      final a = Store<int>(0),
          b = Store<int>(0),
          c = Store<int>(0);
      final x = Store<int>(0), y = Store<int>(0);
      x.addListener(() {});
      y.addListener(() {});
      a.addListener(() {
        batch(() {
          x.value = 1;
          y.value = 1;
        });
      });
      var bN = false;
      b.addListener(() => bN = true);
      c.addListener(() {});
      batch(() {
        a.value = 1;
        b.value = 1;
        c.value = 1;
      });
      expect(bN, true);
      expect(x.value, 1);
      expect(y.value, 1);
      a.dispose();
      b.dispose();
      c.dispose();
      x.dispose();
      y.dispose();
    });

    test('re-entrant batch after large batch', () {
      final stores = List.generate(300, (i) => Store<int>(i));
      final trigger = Store<int>(0);
      trigger.addListener(() {
        batch(() {
          stores[0].value = 9999;
        });
      });
      batch(() {
        trigger.value = 1;
        for (var i = 0; i < stores.length; i++) {
          stores[i].value = i + 1000;
        }
      });
      expect(stores[0].value, 9999);
      expect(stores[1].value, 1001);
      trigger.dispose();
      for (final s in stores) {
        s.dispose();
      }
    });
  });
}
