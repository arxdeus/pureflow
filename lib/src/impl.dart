import 'signal.dart';
import 'computed.dart';

// ============================================================================
// Global State
// ============================================================================

_ComputedImpl? _currentComputed;
int _batchDepth = 0;
List<SignalImpl>? _batchSignals;

// ============================================================================
// Dependency Node (Linked List)
// ============================================================================

/// A linked list node for tracking dependencies between signals and computeds.
/// Uses version numbers instead of storing values to minimize memory usage.
class _Node {
  /// The source (Signal or Computed) that the target depends on.
  ReactiveSource source;

  /// The target (Computed) that depends on the source.
  _ComputedImpl target;

  /// Version of the source when last seen by target.
  /// -1 means the node is recyclable.
  int version;

  /// Links for the source's list of dependents (targets).
  _Node? previousTarget;
  _Node? nextTarget;

  /// Links for the target's list of dependencies (sources).
  _Node? previousSource;
  _Node? nextSource;

  /// Rollback node for context switching during evaluation.
  _Node? rollbackNode;

  _Node({required this.source, required this.target, this.version = 0});
}

// ============================================================================
// Reactive Source Base Class
// ============================================================================

/// Abstract base class for reactive sources (Signal and Computed).
/// Contains shared dependency tracking logic.
abstract class ReactiveSource {
  /// Head of linked list of dependent computeds.
  _Node? _targets;

  /// Current node being used during dependency tracking.
  _Node? _node;

  /// Version number, incremented on value changes.
  int _version = 0;

  /// Subscribes a node to this source's target list.
  void _subscribeNode(_Node node) {
    if (_targets != node && node.previousTarget == null) {
      node.nextTarget = _targets;
      if (_targets != null) {
        _targets!.previousTarget = node;
      }
      _targets = node;
    }
  }

  /// Unsubscribes a node from this source's target list.
  void _unsubscribeNode(_Node node) {
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
  void _addDependency(_ComputedImpl targetComputed) {
    var node = _node;

    if (node == null || node.target != targetComputed) {
      // New dependency - create node and add to target's source list
      node = _Node(source: this, target: targetComputed, version: _version)
        ..previousSource = targetComputed._sources
        ..rollbackNode = _node;

      if (targetComputed._sources != null) {
        targetComputed._sources!.nextSource = node;
      }
      targetComputed._sources = node;
      _node = node;

      // Subscribe to this source
      _subscribeNode(node);
    } else if (node.version == -1) {
      // Reuse existing node
      node.version = _version;

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
    } else {
      // Already tracking, update version
      node.version = _version;
    }
  }
}

// ============================================================================
// Signal Implementation
// ============================================================================

class SignalImpl<T> extends ReactiveSource implements Signal<T> {
  T _value;

  /// Raw status flags: bit 0 = disposed, bit 1 = inBatch
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

    for (final signal in signals) {
      signal._statusCode &= ~2; // Clear inBatch flag
      if ((signal._statusCode & 1) == 0) {
        // Not disposed
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
    // Check disposed (bit 0) or value unchanged
    if ((_statusCode & 1) != 0 ||
        identical(_value, newValue) ||
        _value == newValue) {
      return;
    }
    _value = newValue;
    _version++;

    if (_batchDepth > 0) {
      // Check inBatch (bit 1)
      if ((_statusCode & 2) == 0) {
        _statusCode |= 2; // Set inBatch flag
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
    if ((_statusCode & 1) != 0) return; // Already disposed
    _statusCode |= 1; // Set disposed flag
    _targets = null;
    _node = null;
  }
}

// ============================================================================
// Computed Implementation
// ============================================================================

class _ComputedImpl<T> extends ReactiveSource implements Computed<T> {
  final T Function() _compute;
  T? _value;

  /// Status flags: bit 0 = dirty, bit 1 = disposed, bit 2 = running
  int _statusCode = 1; // Start dirty

  /// Tail of linked list of dependencies (sources).
  _Node? _sources;

  _ComputedImpl(this._compute);

  @override
  T get value {
    final status = _statusCode;

    // Check for cycle (bit 2 = running)
    if ((status & 4) != 0) {
      throw StateError('Cycle detected in computed');
    }

    // Recompute if dirty (bit 0 = dirty)
    if ((status & 1) != 0) {
      _recompute();
    }

    // Track self as dependency (inline for performance)
    // Skip if disposed (bit 1)
    if ((status & 2) == 0) {
      final targetComputed = _currentComputed;
      if (targetComputed != null && !identical(targetComputed, this)) {
        _addDependency(targetComputed);
      }
    }

    return _value as T;
  }

  @override
  void dispose() {
    if ((_statusCode & 2) != 0) return; // Already disposed
    _statusCode |= 2; // Set disposed flag
    _cleanupSources(disposeAll: true);
    _sources = null;
    _targets = null;
    _node = null;
  }

  void _markDirty() {
    if ((_statusCode & 3) != 0) return; // Already dirty or disposed
    _statusCode |= 1; // Set dirty flag

    // Propagate dirty flag to dependents
    for (var node = _targets; node != null; node = node.nextTarget) {
      node.target._markDirty();
    }
  }

  void _recompute() {
    // Check if disposed (bit 1)
    if ((_statusCode & 2) != 0) {
      // Just compute without tracking
      final previousComputed = _currentComputed;
      try {
        _value = _compute();
      } finally {
        _currentComputed = previousComputed;
      }
      _statusCode &= ~1; // Clear dirty flag
      return;
    }

    // Mark as running to detect cycles (bit 2)
    _statusCode |= 4;

    // Prepare sources for reuse
    _prepareSources();

    final previousComputed = _currentComputed;
    _currentComputed = this;
    final oldValue = _value;

    try {
      _value = _compute();
    } finally {
      _currentComputed = previousComputed;
      _statusCode &= ~4; // Clear running flag
    }

    // Cleanup unused sources
    _cleanupSources();

    _statusCode &= ~1; // Clear dirty flag

    // Notify if value changed
    final newValue = _value;
    if (!identical(oldValue, newValue) && oldValue != newValue) {
      _version++;
    }
  }

  /// Mark all source nodes as reusable (version = -1).
  void _prepareSources() {
    for (var node = _sources; node != null; node = node.nextSource) {
      final source = node.source;
      node.rollbackNode = source._node;
      source._node = node;
      node.version = -1;

      // Move tail pointer
      if (node.nextSource == null) {
        _sources = node;
      }
    }
  }

  /// Remove unused sources (those still with version = -1).
  void _cleanupSources({bool disposeAll = false}) {
    var node = _sources;
    _Node? headNode;

    while (node != null) {
      final previousNode = node.previousSource;

      if (disposeAll || node.version == -1) {
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
