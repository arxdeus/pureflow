import 'dart:async';

import 'package:meta/meta.dart';

/// Signature of callbacks that have no arguments and return no data.
typedef VoidCallback = void Function();

// ============================================================================
// Bit Flags for Status
// ============================================================================

/// Bit flags for _ReactiveSource status.
const int _disposedBit = 1 << 0;
const int _notifyingBit = 1 << 1;

/// Bit flags for ValueView status.
const int _dirtyBit = 1 << 0;
const int _runningBit = 1 << 1;
const int _viewDisposedBit = 1 << 2;

// ============================================================================
// Global State for Reactive System
// ============================================================================

/// Currently evaluating ValueView (for dependency tracking).
ValueView<Object?>? _currentView;

/// Current batch depth for batched updates.
int _batchDepth = 0;

/// Signals that changed during batch.
List<ValueNotifier<Object?>>? _batchedSignals;

// ============================================================================
// Dependency Node (Optimized for reactive tracking only)
// ============================================================================

/// Node for tracking dependencies between sources and ValueViews.
class _DependencyNode {
  /// The source this dependency is attached to.
  _ReactiveSource<Object?> source;

  /// Target ValueView that depends on the source.
  ValueView<Object?> target;

  /// Whether this dependency is still active (false = recyclable).
  bool isActive = true;

  /// Links for source's dependency list.
  _DependencyNode? prev;
  _DependencyNode? next;

  /// Links for target's dependency list (what this target depends on).
  _DependencyNode? prevSource;
  _DependencyNode? nextSource;

  /// Rollback pointer for context switching.
  _DependencyNode? rollback;

  _DependencyNode({required this.source, required this.target});
}

// ============================================================================
// Listenable Interface
// ============================================================================

/// An object that maintains a list of listeners.
abstract class Listenable {
  const Listenable();

  factory Listenable.merge(Iterable<Listenable?> listenables) =
      _MergingListenable;

  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}

class _MergingListenable extends Listenable {
  _MergingListenable(this._children);

  final Iterable<Listenable?> _children;

  @override
  void addListener(VoidCallback listener) {
    for (final child in _children) {
      child?.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    for (final child in _children) {
      child?.removeListener(listener);
    }
  }

  @override
  String toString() => 'Listenable.merge([${_children.join(", ")}])';
}

abstract class ValueListenable<T> extends Listenable {
  T get value;
}

// ============================================================================
// Listener Node (Simple, for callback listeners only)
// ============================================================================

/// Simple node for callback listeners.
class _ListenerNode {
  VoidCallback callback;
  _ListenerNode? prev;
  _ListenerNode? next;

  _ListenerNode(this.callback);
}

// ============================================================================
// Reactive Source Base Class (Optimized with separate lists)
// ============================================================================

/// Base class for reactive sources with optimized subscription system.
///
/// Uses separate linked lists for callback listeners and reactive dependencies.
abstract class _ReactiveSource<T> extends Stream<T>
    implements ValueListenable<T> {
  /// Head of linked list of callback listeners.
  _ListenerNode? _listeners;

  /// Head of linked list of dependency nodes.
  _DependencyNode? _dependencies;

  /// Current node during dependency tracking.
  _DependencyNode? _trackingNode;

  /// Status flags (bit 0 = disposed).
  int _status = 0;

  /// Whether any listeners are currently registered.
  @protected
  @pragma('vm:prefer-inline')
  bool get hasListeners => _listeners != null || _dependencies != null;

  // --------------------------------------------------------------------------
  // Listener Management (addListener/removeListener)
  // --------------------------------------------------------------------------

  @override
  @pragma('vm:prefer-inline')
  void addListener(VoidCallback listener) {
    final node = _ListenerNode(listener);
    node.next = _listeners;
    if (_listeners != null) {
      _listeners!.prev = node;
    }
    _listeners = node;
  }

  @override
  void removeListener(VoidCallback listener) {
    for (var node = _listeners; node != null; node = node.next) {
      if (node.callback == listener) {
        _removeListenerNode(node);
        break;
      }
    }
  }

  @pragma('vm:prefer-inline')
  void _removeListenerNode(_ListenerNode node) {
    final prev = node.prev;
    final next = node.next;

    if (prev != null) {
      prev.next = next;
    } else {
      _listeners = next;
    }
    if (next != null) {
      next.prev = prev;
    }
  }

  // --------------------------------------------------------------------------
  // Dependency Node Management
  // --------------------------------------------------------------------------

  @pragma('vm:prefer-inline')
  void _addDependencyNode(_DependencyNode node) {
    node.next = _dependencies;
    if (_dependencies != null) {
      _dependencies!.prev = node;
    }
    _dependencies = node;
  }

  @pragma('vm:prefer-inline')
  void _removeDependencyNode(_DependencyNode node) {
    final prev = node.prev;
    final next = node.next;

    if (prev != null) {
      prev.next = next;
    } else {
      _dependencies = next;
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

  /// Registers this source as a dependency of the given ValueView.
  @pragma('vm:prefer-inline')
  void _trackDependency(ValueView<Object?> targetView) {
    var node = _trackingNode;

    if (node == null || node.target != targetView) {
      // New dependency - create node and link to target's source list
      node = _DependencyNode(
        source: this,
        target: targetView,
      )
        ..prevSource = targetView._sourceDeps
        ..rollback = _trackingNode;

      if (targetView._sourceDeps != null) {
        targetView._sourceDeps!.nextSource = node;
      }
      targetView._sourceDeps = node;
      _trackingNode = node;

      // Subscribe to this source
      _addDependencyNode(node);
    } else if (!node.isActive) {
      // Reuse existing node
      node.isActive = true;

      // Move to end of source list if not already there
      if (node.nextSource != null) {
        node.nextSource!.prevSource = node.prevSource;
        if (node.prevSource != null) {
          node.prevSource!.nextSource = node.nextSource;
        }
        node.prevSource = targetView._sourceDeps;
        node.nextSource = null;
        targetView._sourceDeps!.nextSource = node;
        targetView._sourceDeps = node;
      }
    }
  }

  // --------------------------------------------------------------------------
  // Notification (Optimized - no try-catch, separate loops)
  // --------------------------------------------------------------------------

  /// Notifies all subscribers (both listeners and dependencies).
  @protected
  @pragma('vm:prefer-inline')
  void notifySubscribers() {
    // Guard against recursive notification
    if ((_status & _notifyingBit) != 0) return;
    _status |= _notifyingBit;

    try {
      // Notify callback listeners
      for (var node = _listeners; node != null; node = node.next) {
        node.callback();
      }
      // Mark dependent ValueViews as dirty
      for (var node = _dependencies; node != null; node = node.next) {
        node.target._markDirty();
      }
    } finally {
      _status &= ~_notifyingBit;
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
      _ReactiveSubscription<T>(this, onData, onDone);

  @override
  bool get isBroadcast => true;

  // --------------------------------------------------------------------------
  // Disposal
  // --------------------------------------------------------------------------

  @mustCallSuper
  void dispose() {
    if ((_status & _disposedBit) != 0) return;
    _status |= _disposedBit;
    _listeners = null;
    _dependencies = null;
    _trackingNode = null;
  }
}

// ============================================================================
// Synchronous StreamSubscription for _ReactiveSource
// ============================================================================

/// A lightweight [StreamSubscription] implementation that wraps a
/// [_ReactiveSource] listener without using [StreamController].
class _ReactiveSubscription<T> implements StreamSubscription<T> {
  _ReactiveSubscription(
    this._source,
    void Function(T)? onData,
    void Function()? onDone,
  )   : _onData = onData,
        _onDone = onDone {
    // Check if source is already disposed
    if ((_source._status & _disposedBit) != 0) {
      _onSourceDisposed();
      return;
    }

    _listener = () {
      if (!_isCanceled && _onData != null && !_isPaused) {
        _onData!(_source.value);
      }
    };
    _source.addListener(_listener);
  }

  final _ReactiveSource<T> _source;
  void Function(T)? _onData;
  void Function()? _onDone;

  late final VoidCallback _listener;
  bool _isCanceled = false;
  bool _isPaused = false;

  /// Called by the source when it is disposed.
  void _onSourceDisposed() {
    if (_isCanceled) return;
    _isCanceled = true;
    _onDone?.call();
    _onDone = null;
    _onData = null;
  }

  @override
  Future<void> cancel() {
    if (!_isCanceled) {
      _isCanceled = true;
      _source.removeListener(_listener);
      _onDone?.call();
    }
    return Future<void>.value();
  }

  @override
  void onData(void Function(T)? handleData) {
    _onData = handleData;
  }

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {
    _onDone = handleDone;
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    _isPaused = true;
    resumeSignal?.then((_) => resume());
  }

  @override
  void resume() => _isPaused = false;

  @override
  bool get isPaused => _isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    final completer = Completer<E>();
    final previousOnDone = _onDone;
    _onDone = () {
      previousOnDone?.call();
      if (!completer.isCompleted) {
        completer.complete(futureValue as E);
      }
    };
    return completer.future;
  }
}

// ============================================================================
// ValueNotifier (Signal) - Optimized
// ============================================================================

/// A reactive signal that holds a single value.
///
/// Uses optimized subscription system for both callback listeners
/// and reactive dependencies.
class ValueNotifier<T> extends _ReactiveSource<T> {
  ValueNotifier(this._value);

  T _value;
  bool _inBatch = false;

  /// Runs a function within a batch context.
  ///
  /// All signal updates within the function will be batched,
  /// and dependents will only be notified once after completion.
  static R batch<R>(R Function() action) {
    _batchDepth++;
    try {
      return action();
    } finally {
      if (--_batchDepth == 0) _flushBatch();
    }
  }

  @pragma('vm:prefer-inline')
  static void _flushBatch() {
    final signals = _batchedSignals;
    if (signals == null) return;
    final length = signals.length;
    if (length == 0) return;

    for (var i = 0; i < length; i++) {
      final signal = signals[i];
      signal._inBatch = false;
      if ((signal._status & _disposedBit) == 0) {
        signal.notifySubscribers();
      }
    }
    signals.clear();
  }

  @override
  @pragma('vm:prefer-inline')
  T get value {
    // Fast path: no tracking needed (common case)
    final targetView = _currentView;
    if (targetView != null) {
      _trackDependency(targetView);
    }
    return _value;
  }

  @pragma('vm:prefer-inline')
  set value(T newValue) {
    if ((_status & _disposedBit) != 0 ||
        identical(_value, newValue) ||
        _value == newValue) {
      return;
    }
    _value = newValue;

    // Handle batching - defer notification
    if (_batchDepth > 0) {
      if (!_inBatch) {
        _inBatch = true;
        (_batchedSignals ??= []).add(this);
      }
      return;
    }

    // Notify all subscribers (listeners + dependencies)
    notifySubscribers();
  }

  /// Updates the value using a function.
  @pragma('vm:prefer-inline')
  void update(T Function(T) updater) => value = updater(_value);

  @override
  String toString() => 'ValueNotifier<$T>($_value)';
}

// ============================================================================
// ValueView (Computed) - Optimized with bit flags
// ============================================================================

/// A computed value that automatically tracks its dependencies.
///
/// ValueView lazily recomputes its value when dependencies change.
/// Uses optimized subscription system with bit flags for status.
class ValueView<T> extends _ReactiveSource<T> {
  ValueView(this._compute);

  final T Function() _compute;
  late T _value;

  /// Status flags: bit 0 = dirty, bit 1 = running, bit 2 = disposed
  int _viewStatus = _dirtyBit; // Start dirty

  /// Tail of linked list of dependencies (sources this computed depends on).
  _DependencyNode? _sourceDeps;

  @override
  @pragma('vm:prefer-inline')
  T get value {
    final status = _viewStatus;

    // Check for cycle (running bit set)
    if ((status & _runningBit) != 0) {
      throw StateError('Cycle detected in ValueView computation');
    }

    // Recompute if dirty
    if ((status & _dirtyBit) != 0) {
      _recompute();
    }

    // Track self as dependency if inside another ValueView and not disposed
    if ((status & _viewDisposedBit) == 0) {
      final targetView = _currentView;
      if (targetView != null && !identical(targetView, this)) {
        _trackDependency(targetView);
      }
    }

    return _value;
  }

  /// Marks this ValueView as needing recomputation.
  @pragma('vm:prefer-inline')
  void _markDirty() {
    final status = _viewStatus;
    // Already dirty or disposed - skip
    if ((status & (_dirtyBit | _viewDisposedBit)) != 0) return;
    _viewStatus = status | _dirtyBit;

    // Notify all subscribers (listeners + dependent ValueViews)
    notifySubscribers();
  }

  void _recompute() {
    final status = _viewStatus;

    // If disposed, just compute without tracking
    if ((status & _viewDisposedBit) != 0) {
      _value = _compute();
      _viewStatus = status & ~_dirtyBit;
      return;
    }

    // Mark as running
    _viewStatus = status | _runningBit;

    // Prepare existing dependencies for reuse
    _prepareDependencies();

    final previousView = _currentView;
    _currentView = this as ValueView<Object?>;

    try {
      _value = _compute();
    } finally {
      _currentView = previousView;
      // Always cleanup dependencies and clear flags, even on error
      _cleanupDependencies();
      _viewStatus = _viewStatus & ~(_dirtyBit | _runningBit);
    }
  }

  /// Mark all dependency nodes as recyclable.
  @pragma('vm:prefer-inline')
  void _prepareDependencies() {
    for (var node = _sourceDeps; node != null; node = node.nextSource) {
      final source = node.source;
      node.rollback = source._trackingNode;
      source._trackingNode = node;
      node.isActive = false;

      // Move tail pointer
      if (node.nextSource == null) {
        _sourceDeps = node;
      }
    }
  }

  /// Remove unused dependencies (those still inactive).
  void _cleanupDependencies({bool disposeAll = false}) {
    var node = _sourceDeps;
    _DependencyNode? headNode;

    while (node != null) {
      final prevNode = node.prevSource;

      if (disposeAll || !node.isActive) {
        // Unsubscribe from source
        node.source._removeDependencyNode(node);

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

      // Restore rollback node
      final source = node.source;
      source._trackingNode = node.rollback;
      node.rollback = null;

      node = prevNode;
    }

    _sourceDeps = headNode;
  }

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // Trigger initial computation to establish dependencies
    if ((_viewStatus & _dirtyBit) != 0) {
      _recompute();
    }
    return _ReactiveSubscription<T>(this, onData, onDone);
  }

  @override
  void dispose() {
    if ((_viewStatus & _viewDisposedBit) != 0) return;
    _viewStatus |= _viewDisposedBit;
    _cleanupDependencies(disposeAll: true);
    _sourceDeps = null;
    super.dispose();
  }

  @override
  String toString() {
    final status = _viewStatus;
    if ((status & _viewDisposedBit) != 0) {
      return 'ValueView<$T>(disposed)';
    }
    if ((status & _dirtyBit) != 0) {
      return 'ValueView<$T>(dirty)';
    }
    return 'ValueView<$T>($_value)';
  }
}

// ============================================================================
// Example / Test
// ============================================================================

void main() {
  print('=== Basic Signal/Computed Test ===');
  final signal = ValueNotifier(0);
  final computed = ValueView(() => signal.value * 2);

  print('Initial: signal=${signal.value}, computed=${computed.value}');

  signal.value = 1;
  print('After signal=1: computed=${computed.value}');

  signal.value = 5;
  print('After signal=5: computed=${computed.value}');

  print('\n=== Chained Computed Test ===');
  final a = ValueNotifier(1);
  final b = ValueNotifier(2);
  final sum = ValueView(() => a.value + b.value);
  final doubled = ValueView(() => sum.value * 2);

  print(
      'a=${a.value}, b=${b.value}, sum=${sum.value}, doubled=${doubled.value}');

  a.value = 10;
  print('After a=10: sum=${sum.value}, doubled=${doubled.value}');

  print('\n=== Batch Test ===');
  var notifyCount = 0;
  final x = ValueNotifier(0);
  final y = ValueView(() {
    notifyCount++;
    return x.value * 10;
  });

  // Access to establish dependency
  y.value;
  notifyCount = 0;

  ValueNotifier.batch(() {
    x.value = 1;
    x.value = 2;
    x.value = 3;
  });

  print('After batch (x went 0->1->2->3): y=${y.value}');
  print('Recompute count during batch: $notifyCount (should be 1)');

  print('\n=== Listener Test ===');
  final count = ValueNotifier(0);
  count.addListener(() => print('  Listener called: ${count.value}'));
  count.value = 1;
  count.value = 2;

  print('\n=== Dynamic Dependency Test ===');
  final condition = ValueNotifier(true);
  final valA = ValueNotifier(10);
  final valB = ValueNotifier(20);
  var computeCount = 0;
  final dynamic_ = ValueView(() {
    computeCount++;
    return condition.value ? valA.value : valB.value;
  });

  print('Initial (condition=true): ${dynamic_.value}');
  computeCount = 0;

  valB.value = 25; // Should NOT trigger recompute (not a dependency yet)
  dynamic_.value; // Access to check if dirty
  print('After valB=25 (not used): recomputes=$computeCount (should be 0)');

  computeCount = 0;
  valA.value = 15; // Should trigger recompute (is a dependency)
  print(
      'After valA=15: ${dynamic_.value}, recomputes=$computeCount (should be 1)');

  condition.value = false; // Now switches to depend on valB
  computeCount = 0;
  print('After condition=false: ${dynamic_.value} (should be 25)');
  print('  recomputes=$computeCount (should be 1)');

  computeCount = 0;
  valA.value =
      100; // Should NOT trigger recompute anymore (no longer a dependency)
  dynamic_.value; // Access to check if dirty
  print(
      'After valA=100 (no longer used): recomputes=$computeCount (should be 0)');

  computeCount = 0;
  valB.value = 30; // Should trigger recompute (now a dependency)
  print(
      'After valB=30: ${dynamic_.value}, recomputes=$computeCount (should be 1)');

  print('\nAll tests passed!');
}
