import 'dart:async';

import 'package:pureflow/src/pipeline.dart';

EventTransformer<E, R> sequential<E, R>() =>
    (Stream<E> source, EventMapper<E, R> process) =>
        source.asyncExpand(process);

EventTransformer<E, R> concurrent<E, R>() =>
    (Stream<E> source, EventMapper<E, R> process) {
      late StreamSubscription<E> sourceSubscription;
      final innerSubscriptions = <StreamSubscription<R>>{};
      var sourceDone = false;

      late StreamController<R> controller;
      controller = StreamController<R>(
        onListen: () {
          void closeIfDone() {
            if (sourceDone && innerSubscriptions.isEmpty) {
              controller.close();
            }
          }

          sourceSubscription = source.listen(
            (event) {
              late StreamSubscription<R> innerSubscription;
              try {
                innerSubscription = process(event).listen(
                  controller.add,
                  onError: controller.addError,
                  onDone: () {
                    innerSubscriptions.remove(innerSubscription);
                    closeIfDone();
                  },
                );
              } catch (error, stackTrace) {
                controller.addError(error, stackTrace);
                return;
              }
              innerSubscriptions.add(innerSubscription);
            },
            onError: controller.addError,
            onDone: () {
              sourceDone = true;
              closeIfDone();
            },
          );
        },
        onPause: () {
          sourceSubscription.pause();
          for (final subscription in innerSubscriptions) {
            subscription.pause();
          }
        },
        onResume: () {
          sourceSubscription.resume();
          for (final subscription in innerSubscriptions) {
            subscription.resume();
          }
        },
        onCancel: () async {
          await sourceSubscription.cancel();
          await Future.wait(
            innerSubscriptions.map((subscription) => subscription.cancel()),
          );
        },
      );

      return controller.stream;
    };

EventTransformer<E, R> droppable<E, R>() =>
    (Stream<E> source, EventMapper<E, R> process) {
      late StreamSubscription<E> sourceSubscription;
      StreamSubscription<R>? innerSubscription;
      var sourceDone = false;

      late StreamController<R> controller;
      controller = StreamController<R>(
        onListen: () {
          void closeIfDone() {
            if (sourceDone && innerSubscription == null) {
              controller.close();
            }
          }

          sourceSubscription = source.listen(
            (event) {
              if (innerSubscription != null) {
                StreamSubscription<R>? droppedSubscription;
                try {
                  droppedSubscription = process(event).listen(null);
                } catch (error, stackTrace) {
                  controller.addError(error, stackTrace);
                  return;
                }
                droppedSubscription.cancel();
                return;
              }

              try {
                innerSubscription = process(event).listen(
                  controller.add,
                  onError: controller.addError,
                  onDone: () {
                    innerSubscription = null;
                    closeIfDone();
                  },
                );
              } catch (error, stackTrace) {
                controller.addError(error, stackTrace);
                return;
              }
            },
            onError: controller.addError,
            onDone: () {
              sourceDone = true;
              closeIfDone();
            },
          );
        },
        onPause: () {
          sourceSubscription.pause();
          innerSubscription?.pause();
        },
        onResume: () {
          sourceSubscription.resume();
          innerSubscription?.resume();
        },
        onCancel: () async {
          await sourceSubscription.cancel();
          await innerSubscription?.cancel();
        },
      );

      return controller.stream;
    };

EventTransformer<E, R> restartable<E, R>() =>
    (Stream<E> source, EventMapper<E, R> process) {
      late StreamSubscription<E> sourceSubscription;
      StreamSubscription<R>? innerSubscription;
      var sourceDone = false;

      late StreamController<R> controller;
      controller = StreamController<R>(
        onListen: () {
          void closeIfDone() {
            if (sourceDone && innerSubscription == null) {
              controller.close();
            }
          }

          sourceSubscription = source.listen(
            (event) {
              innerSubscription?.cancel();
              innerSubscription = null;

              late StreamSubscription<R> subscription;
              try {
                subscription = process(event).listen(
                  controller.add,
                  onError: controller.addError,
                  onDone: () {
                    if (identical(innerSubscription, subscription)) {
                      innerSubscription = null;
                      closeIfDone();
                    }
                  },
                );
              } catch (error, stackTrace) {
                controller.addError(error, stackTrace);
                return;
              }
              innerSubscription = subscription;
            },
            onError: controller.addError,
            onDone: () {
              sourceDone = true;
              closeIfDone();
            },
          );
        },
        onPause: () {
          sourceSubscription.pause();
          innerSubscription?.pause();
        },
        onResume: () {
          sourceSubscription.resume();
          innerSubscription?.resume();
        },
        onCancel: () async {
          await sourceSubscription.cancel();
          await innerSubscription?.cancel();
        },
      );

      return controller.stream;
    };
