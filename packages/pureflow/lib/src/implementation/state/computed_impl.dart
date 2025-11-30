import 'dart:async';

import 'package:pureflow/src/common/bit_flags.dart';
import 'package:pureflow/src/computed.dart';
import 'package:pureflow/src/internal/state/reactive_source.dart';

// ============================================================================
// ComputedImpl - Optimized Implementation with bit flags
// ============================================================================

/// Implementation of [Computed].
class ComputedImpl<T> extends ReactiveSource<T> implements Computed<T> {
  ComputedImpl(this._compute);

  final T Function() _compute;
  late T _value;

  /// Status flags: bit 0 = dirty, bit 1 = running, bit 2 = disposed
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

    try {
      _value = _compute();
    } finally {
      currentView = previousView;
      // Always cleanup dependencies and clear flags, even on error
      _cleanupDependencies();
      _viewStatus = _viewStatus.clearFlag(dirtyBit | runningBit);
    }
  }

  /// Mark all dependency nodes as recyclable.
  @pragma('vm:prefer-inline')
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

        // Return node to pool for reuse
        releaseNode(node);
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
    final viewStatus = _viewStatus;
    // Inline bit checks
    if (viewStatus.hasFlag(viewDisposedBit)) {
      return 'Computed<$T>(disposed)';
    }
    if (viewStatus.hasFlag(dirtyBit)) {
      return 'Computed<$T>(dirty)';
    }
    return 'Computed<$T>($_value)';
  }
}
