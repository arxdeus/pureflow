import 'dart:async';

import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

void main() {
  group('Pipeline transformer helpers', () {
    test('sequential completes delayed tasks in input order', () async {
      final pipeline = Pipeline(transformer: sequential());
      final firstMayComplete = Completer<void>();
      final events = <String>[];

      final first = pipeline.run((context) async {
        events.add('first-start');
        await firstMayComplete.future;
        events.add('first-end');
        return 1;
      });
      final second = pipeline.run((context) async {
        events.add('second-start');
        events.add('second-end');
        return 2;
      });

      await Future<void>.delayed(Duration.zero);
      expect(events, ['first-start']);

      firstMayComplete.complete();

      expect(await first, 1);
      expect(await second, 2);
      expect(events, [
        'first-start',
        'first-end',
        'second-start',
        'second-end',
      ]);
      await pipeline.dispose(force: true);
    });

    test('concurrent starts delayed tasks before either completes', () async {
      final pipeline = Pipeline(transformer: concurrent());
      final firstMayComplete = Completer<void>();
      final secondMayComplete = Completer<void>();
      final events = <String>[];

      final first = pipeline.run((context) async {
        events.add('first-start');
        await firstMayComplete.future;
        events.add('first-end');
        return 1;
      });
      final second = pipeline.run((context) async {
        events.add('second-start');
        await secondMayComplete.future;
        events.add('second-end');
        return 2;
      });

      await Future<void>.delayed(Duration.zero);
      expect(events, ['first-start', 'second-start']);

      secondMayComplete.complete();
      firstMayComplete.complete();

      expect(await first, 1);
      expect(await second, 2);
      await pipeline.dispose(force: true);
    });

    test('droppable cancels new runs while one is active', () async {
      final pipeline = Pipeline(transformer: droppable());
      final firstMayComplete = Completer<void>();
      final sideEffects = <String>[];

      final first = pipeline.run((context) async {
        await firstMayComplete.future;
        if (context.isActive) sideEffects.add('first');
        return 'first';
      });
      final second = pipeline.run((context) async {
        await Future<void>.delayed(Duration.zero);
        if (context.isActive) sideEffects.add('second');
        return 'second';
      });

      await Future<void>.delayed(Duration.zero);
      firstMayComplete.complete();

      expect(await first, 'first');
      expect(await second, 'second');
      expect(sideEffects, ['first']);
      await pipeline.dispose(force: true);
    });

    test('restartable cancels active run when a newer run starts', () async {
      final pipeline = Pipeline(transformer: restartable());
      final firstMayContinue = Completer<void>();
      final secondMayContinue = Completer<void>();
      final sideEffects = <String>[];
      var firstWasActiveAfterDelay = true;

      final first = pipeline.run((context) async {
        await firstMayContinue.future;
        firstWasActiveAfterDelay = context.isActive;
        if (context.isActive) sideEffects.add('first');
        return 'first';
      });
      final second = pipeline.run((context) async {
        await secondMayContinue.future;
        if (context.isActive) sideEffects.add('second');
        return 'second';
      });

      await Future<void>.delayed(Duration.zero);
      firstMayContinue.complete();
      secondMayContinue.complete();

      expect(await first, 'first');
      expect(await second, 'second');
      expect(firstWasActiveAfterDelay, isFalse);
      expect(sideEffects, ['second']);
      await pipeline.dispose(force: true);
    });

    test('helpers are exported from pureflow barrel', () async {
      final pipeline = Pipeline(transformer: sequential());

      await pipeline.dispose(force: true);
    });
  });
}
