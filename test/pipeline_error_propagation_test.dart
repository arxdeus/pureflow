import 'dart:async';

import 'package:pureflow/pureflow.dart';
import 'package:test/test.dart';

// Import transformers from pipeline_test.dart
Stream<R> _sequentialTransformer<E, R>(
  Stream<E> events,
  Stream<R> Function(E) mapper,
) {
  return events.asyncExpand(mapper);
}

Stream<R> _concurrentTransformer<E, R>(
  Stream<E> events,
  Stream<R> Function(E) mapper,
) {
  return events.flatMap(mapper);
}

extension _StreamExtensions<T> on Stream<T> {
  Stream<R> flatMap<R>(Stream<R> Function(T) mapper) {
    return transform(_FlatMapTransformer(mapper));
  }
}

class _FlatMapTransformer<T, R> extends StreamTransformerBase<T, R> {
  final Stream<R> Function(T) mapper;

  _FlatMapTransformer(this.mapper);

  @override
  Stream<R> bind(Stream<T> stream) {
    final controller = StreamController<R>();
    final subscriptions = <StreamSubscription<R>>[];

    stream.listen(
      (event) {
        final subscription = mapper(event).listen(
          controller.add,
          onError: controller.addError,
        );
        subscriptions.add(subscription);
      },
      onError: (Object error, StackTrace stackTrace) {
        controller.addError(error, stackTrace);
      },
      onDone: () async {
        await Future.wait(subscriptions.map((s) => s.asFuture<void>()));
        await controller.close();
      },
    );

    return controller.stream;
  }
}

void main() {
  // ============================================================================
  // Error Propagation Tests
  // ============================================================================
  // These tests verify that errors thrown in pipeline tasks propagate
  // to the caller through the Future. Note that Pipeline also propagates
  // errors through the zone's uncaught error handler, which may cause
  // test failures if not handled properly.

  group('Pipeline - Error Propagation', () {
    test('task throws error propagates to caller', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      await expectLater(pipeline.run<Never>((context) {
        throw Exception('test error');
      }), throwsException);

      await pipeline.dispose();
    });

    test('error does not affect subsequent tasks', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      await expectLater(
        pipeline.run<Never>((context) {
          print('test 1');
          throw Exception('error');
        }),
        throwsException,
      );

      final result = await pipeline.run((context) {
        print('test 2');
        return Future.value(42);
      });

      expect(result, 42);
      await pipeline.dispose();
    });

    test('multiple tasks with errors', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      var errorCount = 0;
      var successResult = 0;

      await Future.wait([
        pipeline.run<void>((context) {
          throw Exception('error 1');
        }).then((_) {}, onError: (Object _) {
          errorCount++;
        }),
        pipeline.run<void>((context) {
          throw Exception('error 2');
        }).then((_) {}, onError: (Object _) {
          errorCount++;
        }),
        pipeline.run((context) async {
          return 42;
        }).then((v) {
          successResult = v;
        }),
      ]);

      expect(errorCount, 2);
      expect(successResult, 42);
      await pipeline.dispose();
    });

    test('error with stack trace', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      StackTrace? caughtStackTrace;
      Object? caughtError;

      try {
        await pipeline.run<void>((context) {
          throw StateError('test state error');
        });
      } catch (e, st) {
        caughtError = e;
        caughtStackTrace = st;
      }

      expect(caughtError, isA<StateError>());
      expect(caughtStackTrace, isNotNull);
      await pipeline.dispose();
    });

    test('async error in task', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);

      await expectLater(
        pipeline.run((context) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          throw Exception('async error');
        }),
        throwsException,
      );

      await pipeline.dispose();
    });

    test('error type is preserved', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      Object? caughtError;

      try {
        await pipeline.run<void>((context) {
          throw ArgumentError('invalid argument');
        });
      } catch (e) {
        caughtError = e;
      }

      expect(caughtError, isA<ArgumentError>());
      await pipeline.dispose();
    });

    test('multiple sequential errors', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      var errorCount = 0;

      for (var i = 0; i < 3; i++) {
        try {
          await pipeline.run<void>((context) {
            throw Exception('error $i');
          });
        } catch (_) {
          errorCount++;
        }
      }

      expect(errorCount, 3);
      await pipeline.dispose();
    });

    test('error in concurrent tasks all propagate', () async {
      final pipeline = Pipeline(transformer: _concurrentTransformer);
      var errorCount = 0;

      await Future.wait([
        pipeline.run<void>((context) {
          throw Exception('error 1');
        }).then((_) {}, onError: (Object _) {
          errorCount++;
        }),
        pipeline.run<void>((context) {
          throw Exception('error 2');
        }).then((_) {}, onError: (Object _) {
          errorCount++;
        }),
        pipeline.run<void>((context) {
          throw Exception('error 3');
        }).then((_) {}, onError: (Object _) {
          errorCount++;
        }),
      ]);

      expect(errorCount, 3);
      await pipeline.dispose();
    });

    test('error message is preserved', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      String? errorMessage;

      try {
        await pipeline.run<void>((context) {
          throw Exception('specific error message');
        });
      } catch (e) {
        errorMessage = e.toString();
      }

      expect(errorMessage, contains('specific error message'));
      await pipeline.dispose();
    });

    test('error during long-running task propagates', () async {
      final pipeline = Pipeline(transformer: _sequentialTransformer);
      var errorCaught = false;

      try {
        await pipeline.run((context) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          throw Exception('delayed error');
        });
      } catch (_) {
        errorCaught = true;
      }

      expect(errorCaught, true);
      await pipeline.dispose();
    });
  });
}
