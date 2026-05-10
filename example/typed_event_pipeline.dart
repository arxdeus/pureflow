// Example: a dynamic, bloc-style event pipeline built on top of `Pipeline`.
//
// In `bloc`, you define an abstract event class and register handlers for
// concrete subtypes:
//
// ```dart
// abstract class CounterEvent {}
// class Incremented extends CounterEvent {}
// class Reset extends CounterEvent {}
//
// class CounterBloc extends Bloc<CounterEvent, int> {
//   CounterBloc() : super(0) {
//     on<Incremented>((event, emit) => emit(state + 1));
//     on<Reset>((event, emit) => emit(0));
//   }
// }
// ```
//
// Pureflow's `Pipeline` is lower level: it just runs `Future Function(ctx)`
// tasks under a chosen concurrency strategy. To get the bloc-like ergonomics
// (sealed event hierarchy, per-subtype handlers, automatic routing) we wrap
// `Pipeline` in a tiny `EventPipeline<E>` class that:
//
//   - keeps a list of (typeMatcher, handler) registrations,
//   - on `add(event)` finds the handler whose type token matches at runtime,
//   - feeds the wrapped task through the underlying `Pipeline`, so the chosen
//     `EventTransformer` (sequential / droppable / restartable / concurrent)
//     applies uniformly to every subtype.
//
// This file is self-contained and runnable: `dart run example/typed_event_pipeline.dart`.

import 'dart:async';

import 'package:pureflow/pureflow.dart';

// ---------------------------------------------------------------------------
// 1. The reusable abstraction.
// ---------------------------------------------------------------------------

/// Signature for a handler that processes a concrete event subtype [T].
///
/// The handler receives the typed [event] and the [PipelineEventContext]
/// from the underlying [Pipeline] so it can cooperatively cancel via
/// `context.isActive`.
typedef TypedEventHandler<T> = Future<void> Function(
  T event,
  PipelineEventContext context,
);

/// A handler registration: a runtime type-check predicate plus the
/// wrapped handler that has already had its argument type erased to [E].
class _Registration<E extends Object> {
  final Type type;
  final bool Function(E event) matches;
  final Future<void> Function(E event, PipelineEventContext ctx) invoke;

  _Registration({
    required this.type,
    required this.matches,
    required this.invoke,
  });
}

/// A bloc-like event router built on top of pureflow's [Pipeline].
///
/// Register handlers for concrete event subtypes with [on], then dispatch
/// events with [add]. Every dispatched event flows through the same
/// [Pipeline], so one [EventTransformer] governs concurrency for the whole
/// stream of events regardless of their concrete subtype.
class EventPipeline<E extends Object> {
  final Pipeline _pipeline;
  final List<_Registration<E>> _registrations = <_Registration<E>>[];
  bool _disposed = false;

  EventPipeline({
    required EventTransformer<dynamic, dynamic> transformer,
    String? debugLabel,
  }) : _pipeline = Pipeline(
          transformer: transformer,
          debugLabel: debugLabel,
        );

  /// Register a handler for events of subtype [T].
  ///
  /// Each subtype may be registered at most once, matching bloc's behaviour.
  void on<T extends E>(TypedEventHandler<T> handler) {
    if (_disposed) {
      throw StateError('EventPipeline has been disposed.');
    }
    final alreadyRegistered = _registrations.any((r) => r.type == T);
    if (alreadyRegistered) {
      throw StateError('Handler for $T is already registered.');
    }
    _registrations.add(
      _Registration<E>(
        type: T,
        matches: (E event) => event is T,
        invoke: (E event, PipelineEventContext ctx) => handler(event as T, ctx),
      ),
    );
  }

  /// Dispatch an event. The matching handler is queued through the
  /// underlying [Pipeline], honouring its concurrency [EventTransformer].
  ///
  /// Returns a [Future] that completes when the handler finishes (or
  /// completes with an error if no handler matches / the handler throws).
  Future<void> add(E event) {
    if (_disposed) {
      throw StateError('EventPipeline has been disposed.');
    }
    final registration = _registrations.firstWhere(
      (r) => r.matches(event),
      orElse: () => throw StateError(
        'No handler registered for event of type ${event.runtimeType}.',
      ),
    );
    return _pipeline.run<void>(
      (ctx) => registration.invoke(event, ctx),
      debugLabel: registration.type.toString(),
    );
  }

  Future<void> dispose({bool force = false}) async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pipeline.dispose(force: force);
    _registrations.clear();
  }
}

// ---------------------------------------------------------------------------
// 2. Demo: a counter feature with an abstract event hierarchy.
// ---------------------------------------------------------------------------

/// Sealed-style base class. (Use `sealed` keyword if your SDK >= 3.0.)
sealed class CounterEvent {
  const CounterEvent();
}

class Incremented extends CounterEvent {
  final int by;
  const Incremented(this.by);
}

class Decremented extends CounterEvent {
  final int by;
  const Decremented(this.by);
}

class Reset extends CounterEvent {
  const Reset();
}

/// Demonstrates that an async handler can cooperatively cancel by checking
/// `context.isActive` — useful with restartable / droppable transformers.
class LoadedFromServer extends CounterEvent {
  final Duration delay;
  final int value;
  const LoadedFromServer({required this.delay, required this.value});
}

Future<void> main() async {
  // The state lives in a Pureflow Store; handlers mutate it.
  final counter = Store<int>(0);

  // Sequential transformer: events are processed one-at-a-time, in order.
  // Swap this for `droppable` / `restartable` / `concurrent` (e.g. from
  // package:bloc_concurrency) without touching any handler.
  final events = EventPipeline<CounterEvent>(
    transformer: <E, R>(Stream<E> source, Stream<R> Function(E) process) =>
        source.asyncExpand(process),
    debugLabel: 'counter-events',
  );

  // Register handlers per subtype. Pattern matching on the abstract base
  // would also work here; we use named handlers for clarity.
  events.on<Incremented>((event, ctx) async {
    counter.update((v) => v + event.by);
  });

  events.on<Decremented>((event, ctx) async {
    counter.update((v) => v - event.by);
  });

  events.on<Reset>((event, ctx) async {
    counter.value = 0;
  });

  events.on<LoadedFromServer>((event, ctx) async {
    // Simulate a slow network call and respect cooperative cancellation.
    await Future<void>.delayed(event.delay);
    if (!ctx.isActive) {
      return;
    }
    counter.value = event.value;
  });

  // Observe state changes for the duration of the demo.
  final sub = counter.listen((v) => print('counter -> $v'));

  // Fire a mix of events. Because the transformer is sequential, output is
  // deterministic: each handler completes before the next begins.
  await events.add(const Incremented(1)); // counter -> 1
  await events.add(const Incremented(4)); // counter -> 5
  await events.add(const Decremented(2)); // counter -> 3
  await events.add(
    const LoadedFromServer(delay: Duration(milliseconds: 50), value: 42),
  ); // counter -> 42
  await events.add(const Reset()); // counter -> 0

  // Dispatching an unhandled subtype throws — uncomment to see it fail fast.
  // await events.add(_Unhandled());

  await sub.cancel();
  await events.dispose();
  counter.dispose();
}

// Example of a subtype with no registered handler — kept commented above.
// class _Unhandled extends CounterEvent { const _Unhandled(); }
