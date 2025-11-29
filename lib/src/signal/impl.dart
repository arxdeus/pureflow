import 'dart:async';

import 'package:pureflow/src/common/bit_flags.dart';
import 'package:pureflow/src/signal/computed.dart';
import 'package:pureflow/src/signal/signal.dart';
import 'package:synchronous_stream/synchronous_stream.dart';

// ============================================================================
// Bit Flags
// ============================================================================

/// Bit flags for SignalImpl status.
const int _signalDisposedBit = 1 << 0;
const int _signalInBatchBit = 1 << 1;

/// Bit flags for _ComputedImpl status.
const int _computedDirtyBit = 1 << 0;
const int _computedDisposedBit = 1 << 1;
const int _computedRunningBit = 1 << 2;

// ============================================================================
// Global State
// ============================================================================

_ComputedImpl<Object?>? _currentComputed;
int _batchDepth = 0;
List<SignalImpl<Object?>>? _batchSignals;

// ============================================================================
// Dependency Node (Linked List)
// ============================================================================

/// A linked list node for tracking dependencies between signals and computeds.
class _Node<T> {
  /// The source (Signal or Computed) that the target depends on.
  ReactiveSource<T> source;

  /// The target (Computed) that depends on the source.
  _ComputedImpl<Object?> target;

  /// Whether this node is actively tracking a dependency.
  /// false means the node is recyclable.
  bool isActive = true;

  /// Links for the source's list of dependents (targets).
  _Node<Object?>? previousTarget;
  _Node<Object?>? nextTarget;

  /// Links for the target's list of dependencies (sources).
  _Node<Object?>? previousSource;
  _Node<Object?>? nextSource;

  /// Rollback node for context switching during evaluation.
  _Node<Object?>? rollbackNode;

  _Node({required this.source, required this.target});
}

// ============================================================================
// Reactive Source Base Class
// ============================================================================

/// Abstract base class for reactive sources (Signal and Computed).
/// Contains shared dependency tracking logic.
abstract class ReactiveSource<T> with Stream<T> {
  StreamController<T>? _$controller;
  StreamController<T> get _controller =>
      _$controller ??= SynchronousDispatchStreamController<T>.broadcast();

  /// Head of linked list of dependent computeds.
  _Node<Object?>? _targets;

  /// Current node being used during dependency tracking.
  _Node<Object?>? _node;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _controller.stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  /// Subscribes a node to this source's target list.
  void _subscribeNode(_Node<Object?> node) {
    if (_targets != node && node.previousTarget == null) {
      node.nextTarget = _targets;
      if (_targets != null) {
        _targets!.previousTarget = node;
      }
      _targets = node;
    }
  }

  /// Unsubscribes a node from this source's target list.
  void _unsubscribeNode(_Node<Object?> node) {
    if (_targets == null) return;

    final previousNode = node.previousTarget;
    final nextNode = node.nextTarget;

    if (previousNode != null) {
      previousNode.nextTarget = nextNode;
      node.previousTarget = null;
    }
    if (nextNode != null) {
      nextNode.previousTarget = previousNode;
      node.nextTarget = null;
    }
    if (node == _targets) {
      _targets = nextNode;
    }
  }

  /// Adds this source as a dependency of the given computed.
  void _addDependency(_ComputedImpl<Object?> targetComputed) {
    var node = _node;

    if (node == null || node.target != targetComputed) {
      // New dependency - create node and add to target's source list
      node = _Node(source: this, target: targetComputed)
        ..previousSource = targetComputed._sources
        ..rollbackNode = _node;

      if (targetComputed._sources != null) {
        targetComputed._sources!.nextSource = node;
      }
      targetComputed._sources = node;
      _node = node;

      // Subscribe to this source
      _subscribeNode(node);
    } else if (!node.isActive) {
      // Reuse existing node
      node.isActive = true;

      // Move to end of source list if not already there
      if (node.nextSource != null) {
        node.nextSource!.previousSource = node.previousSource;
        if (node.previousSource != null) {
          node.previousSource!.nextSource = node.nextSource;
        }
        node.previousSource = targetComputed._sources;
        node.nextSource = null;
        targetComputed._sources!.nextSource = node;
        targetComputed._sources = node;
      }
    }
    // If already active - nothing to do
  }
}

// ============================================================================
// Signal Implementation
// ============================================================================

class SignalImpl<T> extends ReactiveSource<T>
    with Stream<T>
    implements Signal<T> {
  T _value;

  /// Status flags: bit 0 = disposed, bit 1 = inBatch
  int _statusCode = 0;

  SignalImpl(this._value);

  /// Runs a function within a batch context.
  static R batch<R>(R Function() action) {
    _batchDepth++;
    try {
      return action();
    } finally {
      if (--_batchDepth == 0) _flushBatch();
    }
  }

  static void _flushBatch() {
    final signals = _batchSignals;
    if (signals == null || signals.isEmpty) return;
    final length = signals.length;

    for (var index = 0; index < length; index++) {
      final signal = signals[index];
      signal._statusCode = signal._statusCode.clearFlag(_signalInBatchBit);
      if (!signal._statusCode.hasFlag(_signalDisposedBit)) {
        for (var node = signal._targets; node != null; node = node.nextTarget) {
          node.target._markDirty();
        }
      }
    }
    for (var index = 0; index < length; index++) {
      final signal = signals[index];
      signal._statusCode = signal._statusCode.clearFlag(_signalInBatchBit);
      if (!signal._statusCode.hasFlag(_signalDisposedBit)) {
        for (var node = signal._targets; node != null; node = node.nextTarget) {
          node.target._markDirty();
        }
      }
    }
    signals.clear();
  }

  @override
  T get value {
    final targetComputed = _currentComputed;
    if (targetComputed != null) {
      _addDependency(targetComputed);
    }
    return _value;
  }

  @override
  set value(T newValue) {
    if (_statusCode.hasFlag(_signalDisposedBit) ||
        identical(_value, newValue) ||
        _value == newValue) {
      return;
    }
    _value = newValue;
    _$controller?.add(newValue);
    if (_batchDepth > 0) {
      if (!_statusCode.hasFlag(_signalInBatchBit)) {
        _statusCode = _statusCode.setFlag(_signalInBatchBit);
        (_batchSignals ??= []).add(this);
      }
      return;
    }

    _notifyDependents();
  }

  void _notifyDependents() {
    for (var node = _targets; node != null; node = node.nextTarget) {
      node.target._markDirty();
    }
  }

  @override
  void update(T Function(T) updater) => value = updater(_value);

  @override
  void dispose() {
    if (_statusCode.hasFlag(_signalDisposedBit)) return;
    _statusCode = _statusCode.setFlag(_signalDisposedBit);
    _targets = null;
    _node = null;
  }
}

// ============================================================================
// Computed Implementation
// ============================================================================

class _ComputedImpl<T> extends ReactiveSource<T> implements Computed<T> {
  final T Function() _compute;
  late T _value;

  /// Status flags: bit 0 = dirty, bit 1 = disposed, bit 2 = running
  int _statusCode = _computedDirtyBit; // Start dirty

  /// Tail of linked list of dependencies (sources).
  _Node<Object?>? _sources;

  _ComputedImpl(this._compute);

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final stream = _controller.stream;
    // Trigger initial computation to establish dependencies
    if (_statusCode.hasFlag(_computedDirtyBit)) {
      _recompute();
    }
    return stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  T get value {
    final status = _statusCode;

    // Check for cycle
    if (status.hasFlag(_computedRunningBit)) {
      throw StateError('Cycle detected in computed');
    }

    // Recompute if dirty
    if (status.hasFlag(_computedDirtyBit)) {
      _recompute();
    }

    // Track self as dependency (inline for performance)
    // Skip if disposed
    if (!status.hasFlag(_computedDisposedBit)) {
      final targetComputed = _currentComputed;
      if (targetComputed != null && !identical(targetComputed, this)) {
        _addDependency(targetComputed);
      }
    }

    return _value;
  }

  @override
  void dispose() {
    if (_statusCode.hasFlag(_computedDisposedBit)) return;
    _statusCode = _statusCode.setFlag(_computedDisposedBit);
    _cleanupSources(disposeAll: true);
    _sources = null;
    _targets = null;
    _node = null;
  }

  void _markDirty() {
    // Already dirty or disposed
    if (_statusCode.hasFlag(_computedDirtyBit | _computedDisposedBit)) return;
    _statusCode = _statusCode.setFlag(_computedDirtyBit);

    // Propagate dirty flag to dependents
    for (var node = _targets; node != null; node = node.nextTarget) {
      node.target._markDirty();
    }
  }

  void _recompute() {
    // Check if disposed
    if (_statusCode.hasFlag(_computedDisposedBit)) {
      // Just compute without tracking
      final previousComputed = _currentComputed;
      try {
        _value = _compute();
        _$controller?.add(_value);
      } finally {
        _currentComputed = previousComputed;
      }
      _statusCode = _statusCode.clearFlag(_computedDirtyBit);
      return;
    }

    // Mark as running to detect cycles
    _statusCode = _statusCode.setFlag(_computedRunningBit);

    // Prepare sources for reuse
    _prepareSources();

    final previousComputed = _currentComputed;
    _currentComputed = this;

    try {
      _value = _compute();
      _$controller?.add(_value);
    } finally {
      _currentComputed = previousComputed;
      _statusCode = _statusCode.clearFlag(_computedRunningBit);
    }

    // Cleanup unused sources
    _cleanupSources();

    _statusCode = _statusCode.clearFlag(_computedDirtyBit);
  }

  /// Mark all source nodes as recyclable.
  void _prepareSources() {
    for (var node = _sources; node != null; node = node.nextSource) {
      final source = node.source;
      node.rollbackNode = source._node;
      source._node = node;
      node.isActive = false;

      // Move tail pointer
      if (node.nextSource == null) {
        _sources = node;
      }
    }
  }

  /// Remove unused sources (those still inactive).
  void _cleanupSources({bool disposeAll = false}) {
    var node = _sources;
    _Node<Object?>? headNode;

    while (node != null) {
      final previousNode = node.previousSource;

      if (disposeAll || !node.isActive) {
        // Unsubscribe from source
        node.source._unsubscribeNode(node);

        // Remove from list
        if (previousNode != null) {
          previousNode.nextSource = node.nextSource;
        }
        if (node.nextSource != null) {
          node.nextSource!.previousSource = previousNode;
        }
      } else {
        headNode = node;
      }

      // Restore rollback node
      final source = node.source;
      source._node = node.rollbackNode;
      node.rollbackNode = null;

      node = previousNode;
    }

    _sources = headNode;
  }
}

class ComputedImpl<T> extends _ComputedImpl<T> {
  ComputedImpl(super.compute);
}
