import 'dart:async';

import 'package:meta/meta.dart';
import 'package:pureflow/src/batch.dart';
import 'package:pureflow/src/common/bit_flags.dart';
import 'package:pureflow/src/computed.dart';
import 'package:pureflow/src/internal/state/reactive_source.dart';
import 'package:pureflow/src/observer.dart';

// ============================================================================
// Equality Check Helpers (Inline for Performance)
// ============================================================================

// ============================================================================
// ComputedImpl - Optimized Implementation with bit flags
// ============================================================================

/// Implementation of [Computed].
@internal
class ComputedImpl<T> extends ReactiveSource<T> implements Computed<T> {
  ComputedImpl(this._compute, {bool Function(T, T)? equality, this.debugLabel})
      : _equals = equality {
    final observer = Pureflow.observer;
    observer?.onCreated?.call(debugLabel, FlowKind.computed);
  }

  @override
  final String? debugLabel;
  final T Function() _compute;

  /// Custom equality, or `null` for the default (`identical` || `==`).
  ///
  /// Kept nullable on purpose: storing a generic `defaultEquals` tear-off
  /// would allocate an instantiated closure per Computed and force an
  /// indirect call on every recompute. The null branch inlines the default.
  final bool Function(T, T)? _equals;
  late T _value;

  /// Status flags: bit 0 = dirty, bit 1 = running, bit 2 = disposed, bit 3 = hasValue
  int _viewStatus = dirtyBit; // Start dirty

  @override
  @pragma('vm:prefer-inline')
  T get value {
    final viewStatus = _viewStatus;

    // Check for cycle (running bit set) - inline
    if (viewStatus.hasFlag(runningBit)) {
      throw StateError('Cycle detected in Computed computation');
    }

    // Recompute if dirty - inline
    if (viewStatus.hasFlag(dirtyBit)) {
      _recompute();
    }

    // Track self as dependency if inside another Computed and not disposed
    if (!viewStatus.hasFlag(viewDisposedBit)) {
      final targetView = currentView;
      if (targetView != null && !identical(targetView, this)) {
        trackDependency(targetView);
      }
    }

    return _value;
  }

  /// Marks this Computed as needing recomputation.
  @override
  @pragma('vm:prefer-inline')
  void markDirty() {
    final viewStatus = _viewStatus;
    // Already dirty or disposed - skip (inline combined check)
    if (viewStatus.hasFlag(dirtyBit | viewDisposedBit)) return;
    _viewStatus = viewStatus.setFlag(dirtyBit);

    // During a batch (including the flush phase), defer notification so
    // listeners fire once per batch instead of once per flushed dependency.
    if (batchDepth > 0) {
      _deferToBatch();
      return;
    }

    // Leaf short-circuit: no listeners and no dependent Computed values
    // means notifySubscribers would only toggle status bits and walk two
    // empty lists. Skipping it matters in wide fanouts (1000 leaf
    // computeds per source write in benchmarks).
    if (!hasListeners) return;

    // Notify all subscribers (listeners + dependent Computed values)
    notifySubscribers();
  }

  /// Enqueues this Computed in the batch buffer (at most once per flush).
  ///
  /// Mirrors the deferral in `StoreImpl.value=`: the flush loop in
  /// `_flushBatch` picks up entries appended during the flush, so this
  /// Computed notifies after all stores of the current batch have settled.
  @pragma('vm:prefer-inline')
  void _deferToBatch() {
    // Already enqueued, or currently delivering notifications (the in-flight
    // notifySubscribers covers this change — mirrors its re-entrancy guard).
    if (status.hasFlag(inBatchBit | notifyingBit)) return;
    status = status.setFlag(inBatchBit);
    if (batchCount >= batchBuffer.length) {
      batchBuffer.length *= 2;
    }
    batchBuffer[batchCount++] = this;
  }

  void _recompute() {
    final viewStatus = _viewStatus;

    // If disposed, just compute without tracking - inline
    if (viewStatus.hasFlag(viewDisposedBit)) {
      _value = _compute();
      _viewStatus = viewStatus.clearFlag(dirtyBit);
      return;
    }

    // Mark as running - inline
    _viewStatus = viewStatus.setFlag(runningBit);

    // Prepare existing dependencies for reuse
    _prepareDependencies();

    final previousView = currentView;
    currentView = this;

    var succeeded = false;
    late final T newValue;
    try {
      newValue = _compute();
      succeeded = true;
    } finally {
      currentView = previousView;
      // Always cleanup dependencies and clear runningBit, even on error.
      _cleanupDependencies();
      // Keep dirtyBit set when _compute throws so the next access re-runs
      // the computation (documented behavior). Clearing it on error would
      // make the next read skip recompute and hit the uninitialized
      // `late _value` (LateInitializationError) on first evaluation.
      _viewStatus = succeeded
          ? _viewStatus.clearFlag(dirtyBit | runningBit)
          : _viewStatus.clearFlag(runningBit);
    }

    final isFirstValue = !_viewStatus.hasFlag(hasValueBit);
    final eq = _equals;
    final shouldNotify = isFirstValue ||
        !(eq == null
            ? identical(_value, newValue) || _value == newValue
            : eq(_value, newValue));

    // Only notify if value actually changed
    if (shouldNotify) {
      final observer = Pureflow.observer;
      final oldValue = isFirstValue ? null : _value as Object?;

      _viewStatus = _viewStatus.setFlag(hasValueBit);
      _value = newValue;

      observer?.onObservableChanged?.call(
        debugLabel,
        FlowKind.computed,
        oldValue,
        newValue,
      );

      // A recompute can happen mid-batch (e.g. the batch action reads this
      // value, or a listener of an earlier flushed source does). Defer the
      // notification instead of firing it mid-batch.
      //
      // During the flush phase itself the dirty cycle has already enqueued
      // (or delivered) this Computed's notification, so scheduling another
      // one would double-fire listeners. The only exception is the very
      // first materialization of a value: initial dirtyBit is set by the
      // constructor, not by markDirty, so no announcement exists yet.
      if (batchDepth > 0) {
        if (!batchFlushing || isFirstValue) {
          _deferToBatch();
        }
      } else {
        notifySubscribers();
      }
    }
  }

  /// Mark all dependency nodes as recyclable.
  void _prepareDependencies() {
    for (var node = sourceDeps; node != null; node = node.nextSource) {
      final source = node.source;
      node.rollback = source.trackingNode;
      source.trackingNode = node;
      node.isActive = false;

      // Move tail pointer
      if (node.nextSource == null) {
        sourceDeps = node;
      }
    }
  }

  /// Remove unused dependencies (those still inactive).
  void _cleanupDependencies({bool disposeAll = false}) {
    var node = sourceDeps;
    DependencyNode? headNode;

    while (node != null) {
      final prevNode = node.prevSource;
      final shouldRemove = disposeAll || !node.isActive;

      // Restore rollback node before potentially releasing
      final source = node.source;
      source.trackingNode = node.rollback;
      node.rollback = null;

      if (shouldRemove) {
        // Unsubscribe from source
        source.removeDependencyNode(node);

        // Remove from list
        if (prevNode != null) {
          prevNode.nextSource = node.nextSource;
        }
        if (node.nextSource != null) {
          node.nextSource!.prevSource = prevNode;
        }
      } else {
        headNode = node;
      }

      node = prevNode;
    }

    sourceDeps = headNode;
  }

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // Trigger initial computation to establish dependencies - inline
    if (_viewStatus.hasFlag(dirtyBit)) {
      _recompute();
    }
    return ReactiveSubscription<T>(this, onData, onDone);
  }

  @override
  void dispose() {
    // Inline bit check
    if (_viewStatus.hasFlag(viewDisposedBit)) return;
    _viewStatus = _viewStatus.setFlag(viewDisposedBit);
    _cleanupDependencies(disposeAll: true);
    sourceDeps = null;
    super.dispose();
  }

  @override
  String toString() {
    final sb = StringBuffer('Computed<$T>');
    if (debugLabel != null) {
      sb.write('[$debugLabel]');
    }
    final state = switch (_viewStatus) {
      _ when _viewStatus.hasFlag(viewDisposedBit) => 'disposed',
      _ when _viewStatus.hasFlag(dirtyBit) => 'dirty',
      _ => '$_value',
    };
    sb.write('($state)');
    return sb.toString();
  }
}
