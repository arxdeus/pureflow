import 'dart:async';

import 'package:meta/meta.dart';
import 'package:pureflow/src/internal/state/dependency_node.dart';
import 'package:pureflow/src/internal/state/globals.dart';
import 'package:pureflow/src/internal/state/listener_node.dart';
import 'package:pureflow/src/internal/state/reactive_subscription.dart';
import 'package:pureflow/src/interface/state/interfaces.dart';

export 'dependency_node.dart';
export 'globals.dart';
export 'listener_node.dart';
export 'reactive_subscription.dart';

// ============================================================================
// Reactive Source Base Class (Optimized with separate lists)
// ============================================================================

/// Base class for reactive sources with optimized subscription system.
///
/// Uses separate linked lists for callback listeners and reactive dependencies.
@internal
abstract class ReactiveSource<T> extends Stream<T>
    implements ValueHolder<T>, ReactiveSourceLike<T> {
  /// Head of linked list of callback listeners.
  ListenerNode? listeners;

  /// Head of linked list of dependency nodes.
  DependencyNode? dependencies;

  /// Current node during dependency tracking.
  DependencyNode? trackingNode;

  /// Tail of linked list of dependencies (sources this reactive depends on).
  /// Used by Computed, null for Store.
  DependencyNode? sourceDeps;

  /// Status flags (bit 0 = disposed).
  @override
  int status = 0;

  /// Whether any listeners are currently registered.
  @protected
  @pragma('vm:prefer-inline')
  bool get hasListeners => listeners != null || dependencies != null;

  // --------------------------------------------------------------------------
  // Listener Management (addListener/removeListener)
  // --------------------------------------------------------------------------

  @override
  @pragma('vm:prefer-inline')
  void addListener(VoidCallback listener) {
    final node = ListenerNode(listener);
    node.next = listeners;
    if (listeners != null) {
      listeners!.prev = node;
    }
    listeners = node;
  }

  @override
  void removeListener(VoidCallback listener) {
    for (var node = listeners; node != null; node = node.next) {
      if (node.callback == listener) {
        removeListenerNode(node);
        break;
      }
    }
  }

  @pragma('vm:prefer-inline')
  void removeListenerNode(ListenerNode node) {
    final prev = node.prev;
    final next = node.next;

    if (prev != null) {
      prev.next = next;
    } else {
      listeners = next;
    }
    if (next != null) {
      next.prev = prev;
    }
  }

  // --------------------------------------------------------------------------
  // Dependency Node Management
  // --------------------------------------------------------------------------

  @pragma('vm:prefer-inline')
  void addDependencyNode(DependencyNode node) {
    node.next = dependencies;
    if (dependencies != null) {
      dependencies!.prev = node;
    }
    dependencies = node;
  }

  @pragma('vm:prefer-inline')
  void removeDependencyNode(DependencyNode node) {
    final prev = node.prev;
    final next = node.next;

    if (prev != null) {
      prev.next = next;
    } else {
      dependencies = next;
    }
    if (next != null) {
      next.prev = prev;
    }
    node.prev = null;
    node.next = null;
  }

  // --------------------------------------------------------------------------
  // Reactive Dependency Tracking
  // --------------------------------------------------------------------------

  /// Marks this reactive source as needing recomputation.
  /// Override in Computed to actually mark dirty.
  @pragma('vm:prefer-inline')
  void markDirty() {}

  /// Registers this source as a dependency of the given target.
  @pragma('vm:prefer-inline')
  void trackDependency(ReactiveSource<Object?> targetView) {
    final node = trackingNode;

    // Fast path: existing active node for this target
    if (node != null && identical(node.target, targetView)) {
      if (node.isActive) return;
      // Reuse existing node
      node.isActive = true;
      // Move to end of source list if not already there
      if (node.nextSource != null) {
        node.nextSource!.prevSource = node.prevSource;
        if (node.prevSource != null) {
          node.prevSource!.nextSource = node.nextSource;
        }
        node.prevSource = targetView.sourceDeps;
        node.nextSource = null;
        targetView.sourceDeps!.nextSource = node;
        targetView.sourceDeps = node;
      }
      return;
    }

    // Slow path: create new dependency
    trackDependencySlow(targetView, node);
  }

  /// Slow path for creating new dependencies.
  @pragma('vm:never-inline')
  void trackDependencySlow(
    ReactiveSource<Object?> targetView,
    DependencyNode? oldNode,
  ) {
    // New dependency - acquire node from pool and link to target's source list
    final node = acquireNode(this, targetView)
      ..prevSource = targetView.sourceDeps
      ..rollback = oldNode;

    if (targetView.sourceDeps != null) {
      targetView.sourceDeps!.nextSource = node;
    }
    targetView.sourceDeps = node;
    trackingNode = node;

    // Subscribe to this source
    addDependencyNode(node);
  }

  // --------------------------------------------------------------------------
  // Notification (Optimized - no try-catch, separate loops)
  // --------------------------------------------------------------------------

  /// Notifies all subscribers (both listeners and dependencies).
  @pragma('vm:prefer-inline')
  void notifySubscribers() {
    // Guard against recursive notification (inline bit check)
    if ((status & notifyingBit) != 0) return;
    status = status | notifyingBit;

    // Notify callback listeners
    for (var node = listeners; node != null; node = node.next) {
      node.callback();
    }
    // Mark dependent Computed values as dirty
    for (var node = dependencies; node != null; node = node.next) {
      node.target.markDirty();
    }

    status = status & ~notifyingBit;
  }

  // --------------------------------------------------------------------------
  // Stream Implementation
  // --------------------------------------------------------------------------

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      ReactiveSubscription<T>(this, onData, onDone);

  @override
  bool get isBroadcast => true;

  // --------------------------------------------------------------------------
  // Disposal
  // --------------------------------------------------------------------------

  @mustCallSuper
  void dispose() {
    // Inline bit check
    if ((status & disposedBit) != 0) return;
    status = status | disposedBit;
    listeners = null;
    dependencies = null;
    trackingNode = null;
  }
}
