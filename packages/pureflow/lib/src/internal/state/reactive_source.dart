import 'dart:async';

import 'package:meta/meta.dart';
import 'package:pureflow/src/common/bit_flags.dart';
import 'package:pureflow/src/interfaces.dart';
import 'package:pureflow/src/internal/state/dependency_node.dart';
import 'package:pureflow/src/internal/state/globals.dart';
import 'package:pureflow/src/internal/state/listener_node.dart';
import 'package:pureflow/src/internal/state/reactive_subscription.dart';

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
    implements ValueObservable<T>, ReactiveSourceLike<T> {
  /// Head of linked list of callback listeners.
  ListenerNode? listeners;

  /// Head of linked list of dependency nodes.
  DependencyNode? dependencies;

  /// Current node during dependency tracking.
  DependencyNode? trackingNode;

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
  ListenerNode addListener(VoidCallback listener) {
    final node = ListenerNode(listener);
    addListenerNode(node);
    return node;
  }

  /// Links a pre-built [node] at the head of the listener list.
  ///
  /// Used by [ReactiveSubscription], which is itself a [ListenerNode].
  @override
  @pragma('vm:prefer-inline')
  void addListenerNode(ListenerNode node) {
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

  @override
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

  /// Registers this source as a dependency of the given target.
  ///
  /// Only reached while a Computed is recomputing (`currentView != null`),
  /// so this sits on the recompute critical path: prefer-inline lets the
  /// caller keep `targetView` in a register and collapse the fast path to
  /// two loads, a compare, and a store.
  @pragma('vm:prefer-inline')
  void trackDependency(DependentSource<Object?> targetView) {
    final node = trackingNode;

    // Fast path: existing node for this target — just (re)activate it.
    // The node keeps its position in the target's source list; cleanup
    // visits every node regardless of order, so no relinking is needed.
    if (node != null && identical(node.target, targetView)) {
      node.isActive = true;
      return;
    }

    // Slow path: create new dependency
    trackDependencySlow(targetView, node);
  }

  /// Slow path for creating new dependencies.
  @pragma('vm:never-inline')
  void trackDependencySlow(
    DependentSource<Object?> targetView,
    DependencyNode? oldNode,
  ) {
    // New dependency - acquire node from pool and link to target's source list
    final node = DependencyNode(source: this, target: targetView)
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
  // Notification (Optimized - separate loops)
  // --------------------------------------------------------------------------

  /// Notifies all subscribers (both listeners and dependencies).
  void notifySubscribers() {
    // Guard against recursive notification (inline bit check)
    final s = status;
    if (s.hasFlag(notifyingBit)) return;
    status = s.setFlag(notifyingBit);

    // try/finally is required: without it a throwing listener leaves
    // notifyingBit set forever and every future notification is silently
    // dropped. Mirrors the guard in the batch flush path.
    try {
      // Notify callback listeners
      for (var node = listeners; node != null; node = node.next) {
        node.callback();
      }
      // Mark dependent Computed values as dirty
      for (var node = dependencies; node != null; node = node.next) {
        node.target.markDirty();
      }
    } finally {
      // Reload status: listeners may have flipped other bits (e.g. a
      // dependent write marking this Computed dirty again).
      status = status.clearFlag(notifyingBit);
    }
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
    if (status.hasFlag(disposedBit)) return;
    // Set disposedBit BEFORE walking to guard against reentry.
    status = status.setFlag(disposedBit);

    // Notify stream subscriptions that the source is gone. Subscriptions
    // are the only ListenerNode subtype that needs a dispose signal.
    var node = listeners;
    while (node != null) {
      final next = node.next; // snapshot before callback — it may mutate list
      if (node is ReactiveSubscription) {
        node.onSourceDisposed();
      }
      node = next;
    }

    listeners = null;
    dependencies = null;
    trackingNode = null;
  }
}

// ============================================================================
// Dependent Source (base for Computed)
// ============================================================================

/// A [ReactiveSource] that itself depends on other sources (i.e. Computed).
///
/// Keeping [sourceDeps] and [markDirty] off the plain [ReactiveSource] makes
/// Store objects one field smaller and lets the dirty-propagation loop in
/// [ReactiveSource.notifySubscribers] dispatch [markDirty] against a class
/// with a single concrete implementation.
@internal
abstract class DependentSource<T> extends ReactiveSource<T> {
  /// List of dependencies (sources this reactive depends on).
  ///
  /// Between recomputes this points at the HEAD (oldest node); during a
  /// recompute it is advanced to the TAIL so new nodes append at the end.
  DependencyNode? sourceDeps;

  /// Marks this source as needing recomputation.
  void markDirty();
}
