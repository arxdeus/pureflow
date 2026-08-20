import 'dart:async';

import 'package:meta/meta.dart';
import 'package:pureflow/src/batch.dart';
import 'package:pureflow/src/common/bit_flags.dart';
import 'package:pureflow/src/computed.dart';
import 'package:pureflow/src/internal/state/reactive_source.dart';
import 'package:pureflow/src/observer.dart';

// ============================================================================
// ComputedImpl - Optimized Implementation with bit flags
// ============================================================================

/// Implementation of [Computed].
///
/// All state bits (base `ReactiveSource` flags and the view flags
/// dirty/running/disposed/hasValue) share the single inherited [status]
/// field. The bit positions are disjoint (see `globals.dart`), which lets
/// the hot paths test several conditions with one field load and one mask.
@internal
class ComputedImpl<T> extends DependentSource<T> implements Computed<T> {
  ComputedImpl(this._compute, {bool Function(T, T)? equality, this.debugLabel})
      : _equals = equality {
    // Start dirty so the first read computes.
    status = dirtyBit;
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

  @override
  @pragma('vm:prefer-inline')
  T get value {
    final s = status;

    // Fast path: clean, not running, not disposed — one load, one mask.
    if ((s & (dirtyBit | runningBit | viewDisposedBit)) == 0) {
      final targetView = currentView;
      if (targetView != null) {
        // targetView can never be `this` here: while this Computed is
        // being computed its runningBit is set, which routes to the slow
        // path (and throws on the cycle).
        trackDependency(targetView);
      }
      return _value;
    }

    return _valueSlow(s);
  }

  @pragma('vm:never-inline')
  T _valueSlow(int s) {
    // Check for cycle (running bit set)
    if (s.hasFlag(runningBit)) {
      throw StateError('Cycle detected in Computed computation');
    }

    // Recompute if dirty
    if (s.hasFlag(dirtyBit)) {
      _recompute();
    }

    // Track self as dependency if inside another Computed and not disposed
    if (!s.hasFlag(viewDisposedBit)) {
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
    final s = status;
    // Already dirty or disposed - skip (inline combined check)
    if (s.hasFlag(dirtyBit | viewDisposedBit)) return;
    status = s.setFlag(dirtyBit);

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
    if (listeners == null && dependencies == null) return;

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
    final s = status;
    if (s.hasFlag(inBatchBit | notifyingBit)) return;
    status = s.setFlag(inBatchBit);
    if (batchCount >= batchBuffer.length) {
      batchBuffer.length *= 2;
    }
    batchBuffer[batchCount++] = this;
  }

  void _recompute() {
    final s = status;

    // If disposed, just compute without tracking - inline
    if (s.hasFlag(viewDisposedBit)) {
      _value = _compute();
      status = s.clearFlag(dirtyBit);
      return;
    }

    // Mark as running - inline
    status = s.setFlag(runningBit);

    // Prepare existing dependencies for reuse
    _prepareDependencies();

    final previousView = currentView;
    currentView = this;

    T newValue;
    try {
      newValue = _compute();
    } catch (_) {
      currentView = previousView;
      _cleanupDependencies();
      // Keep dirtyBit set when _compute throws so the next access re-runs
      // the computation (documented behavior). Clearing it on error would
      // make the next read skip recompute and hit the uninitialized
      // `late _value` (LateInitializationError) on first evaluation.
      status = status.clearFlag(runningBit);
      rethrow;
    }

    currentView = previousView;
    _cleanupDependencies();

    // Fresh status load: compute may have flipped bits (e.g. a side-effect
    // write re-dirtying this computed); only dirty/running are cleared here.
    final s2 = status.clearFlag(dirtyBit | runningBit);
    status = s2;

    final isFirstValue = !s2.hasFlag(hasValueBit);
    final eq = _equals;

    // Only notify if value actually changed
    if (!isFirstValue &&
        (eq == null
            ? identical(_value, newValue) || _value == newValue
            : eq(_value, newValue))) {
      return;
    }

    // Fresh load again: a side-effecting custom equality may have set
    // dirtyBit; setFlag on the current value preserves it.
    status = status.setFlag(hasValueBit);

    // Observer plumbing kept out-of-line to keep the common path lean.
    // `oldValue` must be captured before `_value` is overwritten.
    if (Pureflow.observer == null) {
      _value = newValue;
    } else {
      final oldValue = isFirstValue ? null : _value as Object?;
      _value = newValue;
      _notifyObserverChanged(oldValue, newValue);
    }

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
    } else if (listeners != null || dependencies != null) {
      notifySubscribers();
    }
  }

  @pragma('vm:never-inline')
  void _notifyObserverChanged(Object? oldValue, T newValue) {
    Pureflow.observer?.onObservableChanged?.call(
      debugLabel,
      FlowKind.computed,
      oldValue,
      newValue,
    );
  }

  /// Mark all dependency nodes as recyclable.
  void _prepareDependencies() {
    final head = sourceDeps;
    if (head == null) return;
    var node = head;
    while (true) {
      final source = node.source;
      node.rollback = source.trackingNode;
      source.trackingNode = node;
      node.isActive = false;

      final next = node.nextSource;
      if (next == null) break;
      node = next;
    }
    // Advance to tail so new nodes append at the end during compute.
    sourceDeps = node;
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
    if (status.hasFlag(dirtyBit)) {
      _recompute();
    }
    return ReactiveSubscription<T>(this, onData, onDone);
  }

  @override
  void dispose() {
    // Inline bit check
    if (status.hasFlag(viewDisposedBit)) return;
    status = status.setFlag(viewDisposedBit);
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
    final s = status;
    final state = switch (s) {
      _ when s.hasFlag(viewDisposedBit) => 'disposed',
      _ when s.hasFlag(dirtyBit) => 'dirty',
      _ => '$_value',
    };
    sb.write('($state)');
    return sb.toString();
  }
}
