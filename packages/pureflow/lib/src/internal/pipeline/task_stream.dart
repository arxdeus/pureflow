import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';
import 'single_event_stream.dart';
import 'source_stream.dart';
import '../../pipeline.dart';

/// Internal stream wrapper for processing pipeline tasks.
@internal
class TaskStream {
  final EventTransformer<dynamic, dynamic> transformer;
  // Use ListQueue for better performance - more cache-friendly than Queue
  final Queue<PipelineEventContext> eventQueue = Queue<PipelineEventContext>();
  // Use Set for O(1) removal instead of List O(n)
  final Set<PipelineEventContext> _activeEvents = {};
  Completer<void>? waitingCompleter;
  bool isActive = true;
  bool _isDisposed = false;
  // ignore: cancel_subscriptions - cancelled in dispose()
  StreamSubscription<dynamic>? _subscription;

  TaskStream({required this.transformer}) {
    _initializeProcessing();
  }

  @pragma('vm:prefer-inline')
  void _initializeProcessing() {
    final sourceStream = SourceStream(this);
    final processedStream = transformer(sourceStream, _processEvent);
    _subscription = processedStream.listen(
      null, // Results are handled in SinglePipelineEventSubscription
      cancelOnError: false,
      onDone: _handleDone,
    );
  }

  @pragma('vm:prefer-inline')
  void _handleDone() {
    isActive = false;
    _cancelActiveEvents();
    _completeWaitingCompleter();
  }

  @pragma('vm:prefer-inline')
  void _completeWaitingCompleter() {
    final completer = waitingCompleter;
    if (completer != null && !completer.isCompleted) {
      waitingCompleter = null;
      completer.complete();
    }
  }

  @pragma('vm:prefer-inline')
  void _cancelActiveEvents() {
    final activeEvents = _activeEvents;
    if (activeEvents.isEmpty) return;
    // Iterate directly over Set without copying
    for (final event in activeEvents) {
      event.cancel();
    }
    activeEvents.clear();
  }

  @pragma('vm:prefer-inline')
  Stream<dynamic> _processEvent(dynamic event) {
    // Fast type check
    if (event is! PipelineEventContext) {
      return const Stream<dynamic>.empty();
    }
    _activeEvents.add(event);
    return SinglePipelineEventStream(event, _activeEvents.remove);
  }

  @pragma('vm:prefer-inline')
  void add(PipelineEventContext event) {
    // Optimize: check _isDisposed first (most common case)
    if (_isDisposed) return event.cancel();
    if (!isActive) return event.cancel();

    eventQueue.add(event);
    _completeWaitingCompleter();
  }

  /// Disposes the task stream.
  ///
  /// If [force] is `true`, all events become inactive immediately.
  /// If [force] is `false`, new events are prevented and the method waits
  /// for all active events to complete.
  Future<void> dispose({bool force = false}) async {
    if (_isDisposed) return;
    _isDisposed = true;

    final queue = eventQueue;
    final activeEvents = _activeEvents;

    if (force) {
      // Force mode: make all events inactive immediately
      isActive = false;

      // Cancel all queued events (they haven't started yet)
      final queueLength = queue.length;
      for (var index = 0; index < queueLength; index++) {
        queue.removeFirst().cancel();
      }

      _cancelActiveEvents();
      _completeWaitingCompleter();

      // Cancel the subscription
      final sub = _subscription;
      _subscription = null;
      await sub?.cancel();
      return;
    }

    // Non-force mode: prevent new events but keep existing ones active
    final queuedCount = queue.length;
    final activeCount = activeEvents.length;
    final totalCount = queuedCount + activeCount;

    if (totalCount == 0) {
      isActive = false;
      _completeWaitingCompleter();
      final sub = _subscription;
      _subscription = null;
      await sub?.cancel();
      return;
    }

    // Pre-allocate futures list with known size
    final futures = queue
        .map((e) => e.completer.future)
        .followedBy(activeEvents.map((e) => e.completer.future));

    // Wake up the stream processor to start processing queued events
    _completeWaitingCompleter();

    // Wait for all events to complete
    try {
      await Future.wait(futures);
    } catch (_) {}

    // After all events complete, mark as inactive
    isActive = false;
    _completeWaitingCompleter();

    // Cancel the subscription
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
  }
}
