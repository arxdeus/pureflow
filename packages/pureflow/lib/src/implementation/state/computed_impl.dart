import 'dart:async';

import 'package:meta/meta.dart';
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
      : _equals = equality ?? defaultEquals {
    final observer = Pureflow.observer;
    observer?.onCreated?.call(debugLabel, FlowKind.computed);
  }

  @override
  final String? debugLabel;
  final T Function() _compute;
  final bool Function(T, T) _equals;
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

    // Notify all subscribers (listeners + dependent Computed values)
    notifySubscribers();
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

    late final T newValue;
    try {
      newValue = _compute();
    } finally {
      currentView = previousView;
      // Always cleanup dependencies and clear flags, even on error
      _cleanupDependencies();
      _viewStatus = _viewStatus.clearFlag(dirtyBit | runningBit);
    }

    final shouldNotify =
        !_viewStatus.hasFlag(hasValueBit) || !_equals(_value, newValue);

    // Only notify if value actually changed
    if (shouldNotify) {
      final observer = Pureflow.observer;
      Object? oldValue;
      oldValue = _viewStatus.hasFlag(hasValueBit) ? _value : null;

      _viewStatus = _viewStatus.setFlag(hasValueBit);
      _value = newValue;

      observer?.onObservableChanged?.call(
        debugLabel,
        FlowKind.computed,
        oldValue,
        newValue,
      );

      notifySubscribers();
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
