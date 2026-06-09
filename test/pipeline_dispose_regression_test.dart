// ignore_for_file: unnecessary_async

import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

void main() {
  // ============================================================================
  // Dispose Regression - run() after dispose() must not hang
  // ============================================================================

  group('Pipeline - dispose regression (run after dispose)', () {
    test('run() after graceful dispose() completes (no hang) - sequential',
        () async {
      final pipeline = Pipeline(transformer: sequential());
      await pipeline.dispose();

      final result = await pipeline
          .run((ctx) async {
            if (!ctx.isActive) return -1;
            return 1;
          })
          .timeout(const Duration(seconds: 2));

      expect(result, -1);
    });

    test('run() after graceful dispose() completes (no hang) - restartable',
        () async {
      final pipeline = Pipeline(transformer: restartable());
      await pipeline.dispose();

      final result = await pipeline
          .run((ctx) async {
            if (!ctx.isActive) return -1;
            return 1;
          })
          .timeout(const Duration(seconds: 2));

      expect(result, -1);
    });

    test('run() after force dispose() completes (no hang) - sequential',
        () async {
      final pipeline = Pipeline(transformer: sequential());
      await pipeline.dispose(force: true);

      final result = await pipeline
          .run((ctx) async {
            if (!ctx.isActive) return -1;
            return 1;
          })
          .timeout(const Duration(seconds: 2));

      expect(result, -1);
    });

    test('run() after force dispose() completes (no hang) - restartable',
        () async {
      final pipeline = Pipeline(transformer: restartable());
      await pipeline.dispose(force: true);

      final result = await pipeline
          .run((ctx) async {
            if (!ctx.isActive) return -1;
            return 1;
          })
          .timeout(const Duration(seconds: 2));

      expect(result, -1);
    });

    test(
        'task submitted after dispose that does NOT check isActive still resolves',
        () async {
      final pipeline = Pipeline(transformer: sequential());
      await pipeline.dispose();

      // Task does not check isActive - future must still complete
      final future = pipeline.run((ctx) async => 42);

      await expectLater(
        future.timeout(const Duration(seconds: 2)),
        completes,
      );
    });

    test('task submitted after dispose observes context.isActive == false',
        () async {
      final pipeline = Pipeline(transformer: sequential());
      await pipeline.dispose();

      bool? activeInsideTask;
      await pipeline
          .run((ctx) async {
            activeInsideTask = ctx.isActive;
            return null;
          })
          .timeout(const Duration(seconds: 2));

      expect(activeInsideTask, false);
    });

    test(
        'run() future resolves within timeout after dispose - sequential and restartable',
        () async {
      for (final transformer in [sequential<Object?, Object?>(), restartable<Object?, Object?>()]) {
        final pipeline = Pipeline(transformer: transformer);
        await pipeline.dispose();

        await expectLater(
          pipeline
              .run((ctx) async => null)
              .timeout(const Duration(seconds: 2)),
          completes,
        );
      }
    });
  });
}
