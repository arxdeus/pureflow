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
  Object source;

  /// The target (Computed) that depends on the source.
  _ComputedImpl target;

  /// Version of the source when last seen by target.
  /// -1 means the node is recyclable.
  int version;

  /// Links for the source's list of dependents (targets).
  _Node? prevTarget;
  _Node? nextTarget;

  /// Links for the target's list of dependencies (sources).
  _Node? prevSource;
  _Node? nextSource;

  /// Rollback node for context switching during evaluation.
  _Node? rollbackNode;

  _Node({required this.source, required this.target, this.version = 0});
}

// ============================================================================
// Signal Implementation
// ============================================================================

class SignalImpl<T> implements Signal<T> {
  T _value;
  int _flags = 0; // bit 0: disposed, bit 1: in batch
  int _version = 0;

  /// Head of linked list of dependent computeds.
  _Node? _targets;

  /// Current node being used during dependency tracking.
  _Node? _node;

  SignalImpl(this._value);

  /// Runs a function within a batch context.
  static R batch<R>(R Function() fn) {
    _batchDepth++;
    try {
      return fn();
    } finally {
      if (--_batchDepth == 0) _flushBatch();
    }
  }

  static void _flushBatch() {
    final signals = _batchSignals;
    if (signals == null || signals.isEmpty) return;

    for (final s in signals) {
      s._flags &= ~2; // Clear batch flag
      if ((s._flags & 1) == 0) {
        // Not disposed
        for (var node = s._targets; node != null; node = node.nextTarget) {
          node.target._markDirty();
        }
      }
    }
    signals.clear();
  }

  @override
  T get value {
    final c = _currentComputed;
    if (c != null) {
      _addDependency(c);
    }
    return _value;
  }

  @override
  set value(T newValue) {
    if ((_flags & 1) != 0 ||
        identical(_value, newValue) ||
        _value == newValue) {
      return;
    }
    _value = newValue;
    _version++;

    if (_batchDepth > 0) {
      if ((_flags & 2) == 0) {
        _flags |= 2;
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
    if ((_flags & 1) != 0) return;
    _flags |= 1;
    _targets = null;
    _node = null;
  }

  /// Add this signal as a dependency of the given computed.
  void _addDependency(_ComputedImpl c) {
    var node = _node;

    if (node == null || node.target != c) {
      // New dependency - create node and add to target's source list
      node = _Node(source: this, target: c, version: _version)
        ..prevSource = c._sources
        ..rollbackNode = _node;

      if (c._sources != null) {
        c._sources!.nextSource = node;
      }
      c._sources = node;
      _node = node;

      // Subscribe to this signal
      _subscribeNode(node);
    } else if (node.version == -1) {
      // Reuse existing node
      node.version = _version;

      // Move to end of source list if not already there
      if (node.nextSource != null) {
        node.nextSource!.prevSource = node.prevSource;
        if (node.prevSource != null) {
          node.prevSource!.nextSource = node.nextSource;
        }
        node.prevSource = c._sources;
        node.nextSource = null;
        c._sources!.nextSource = node;
        c._sources = node;
      }
    } else {
      // Already tracking, update version
      node.version = _version;
    }
  }

  void _subscribeNode(_Node node) {
    if (_targets != node && node.prevTarget == null) {
      node.nextTarget = _targets;
      if (_targets != null) {
        _targets!.prevTarget = node;
      }
      _targets = node;
    }
  }

  void _unsubscribeNode(_Node node) {
    if (_targets == null) return;

    final prev = node.prevTarget;
    final next = node.nextTarget;

    if (prev != null) {
      prev.nextTarget = next;
      node.prevTarget = null;
    }
    if (next != null) {
      next.prevTarget = prev;
      node.nextTarget = null;
    }
    if (node == _targets) {
      _targets = next;
    }
  }
}

// ============================================================================
// Computed Implementation
// ============================================================================

class _ComputedImpl<T> implements Computed<T> {
  final T Function() _compute;
  T? _value;

  // Flags: bit 0 = dirty, bit 1 = disposed, bit 2 = running
  int _flags = 1;
  int _version = 0;

  /// Tail of linked list of dependencies (sources).
  _Node? _sources;

  /// Head of linked list of dependents (targets).
  _Node? _targets;

  /// Current node for dependency tracking.
  _Node? _node;

  _ComputedImpl(this._compute);

  @override
  T get value {
    // Check for cycle
    if ((_flags & 4) != 0) {
      throw StateError('Cycle detected in computed');
    }

    // Recompute if dirty
    if ((_flags & 1) != 0) {
      _recompute();
    }

    _trackSelfAsDependency();
    return _value as T;
  }

  void _trackSelfAsDependency() {
    if ((_flags & 2) != 0) return; // disposed

    final c = _currentComputed;
    if (c != null && !identical(c, this)) {
      _addDependency(c);
    }
  }

  @override
  void dispose() {
    if ((_flags & 2) != 0) return;
    _flags |= 2;
    _cleanupSources(disposeAll: true);
    _sources = null;
    _targets = null;
    _node = null;
  }

  void _markDirty() {
    if ((_flags & 3) != 0) return; // already dirty or disposed
    _flags |= 1;

    // Propagate dirty flag to dependents
    for (var node = _targets; node != null; node = node.nextTarget) {
      node.target._markDirty();
    }
  }

  void _recompute() {
    final disposed = (_flags & 2) != 0;
    if (disposed) {
      // Just compute without tracking
      final prev = _currentComputed;
      try {
        _value = _compute();
      } finally {
        _currentComputed = prev;
      }
      _flags &= ~1;
      return;
    }

    // Mark as running to detect cycles
    _flags |= 4;

    // Prepare sources for reuse
    _prepareSources();

    final prev = _currentComputed;
    _currentComputed = this;
    final oldValue = _value;

    try {
      _value = _compute();
    } finally {
      _currentComputed = prev;
      _flags &= ~4; // Clear running flag
    }

    // Cleanup unused sources
    _cleanupSources();

    _flags &= ~1; // Clear dirty flag

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
      if (source is SignalImpl) {
        node.rollbackNode = source._node;
        source._node = node;
      } else if (source is _ComputedImpl) {
        node.rollbackNode = source._node;
        source._node = node;
      }
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
    _Node? head;

    while (node != null) {
      final prev = node.prevSource;

      if (disposeAll || node.version == -1) {
        // Unsubscribe from source
        final source = node.source;
        if (source is SignalImpl) {
          source._unsubscribeNode(node);
        } else if (source is _ComputedImpl) {
          source._unsubscribeNode(node);
        }

        // Remove from list
        if (prev != null) {
          prev.nextSource = node.nextSource;
        }
        if (node.nextSource != null) {
          node.nextSource!.prevSource = prev;
        }
      } else {
        head = node;
      }

      // Restore rollback node
      final source = node.source;
      if (source is SignalImpl) {
        source._node = node.rollbackNode;
      } else if (source is _ComputedImpl) {
        source._node = node.rollbackNode;
      }
      node.rollbackNode = null;

      node = prev;
    }

    _sources = head;
  }

  /// Add this computed as a dependency of another computed.
  void _addDependency(_ComputedImpl c) {
    var node = _node;

    if (node == null || node.target != c) {
      // New dependency
      node = _Node(source: this, target: c, version: _version)
        ..prevSource = c._sources
        ..rollbackNode = _node;

      if (c._sources != null) {
        c._sources!.nextSource = node;
      }
      c._sources = node;
      _node = node;

      _subscribeNode(node);
    } else if (node.version == -1) {
      // Reuse existing node
      node.version = _version;

      if (node.nextSource != null) {
        node.nextSource!.prevSource = node.prevSource;
        if (node.prevSource != null) {
          node.prevSource!.nextSource = node.nextSource;
        }
        node.prevSource = c._sources;
        node.nextSource = null;
        c._sources!.nextSource = node;
        c._sources = node;
      }
    } else {
      node.version = _version;
    }
  }

  void _subscribeNode(_Node node) {
    if (_targets != node && node.prevTarget == null) {
      node.nextTarget = _targets;
      if (_targets != null) {
        _targets!.prevTarget = node;
      }
      _targets = node;
    }
  }

  void _unsubscribeNode(_Node node) {
    if (_targets == null) return;

    final prev = node.prevTarget;
    final next = node.nextTarget;

    if (prev != null) {
      prev.nextTarget = next;
      node.prevTarget = null;
    }
    if (next != null) {
      next.prevTarget = prev;
      node.nextTarget = null;
    }
    if (node == _targets) {
      _targets = next;
    }
  }
}

class ComputedImpl<T> extends _ComputedImpl<T> {
  ComputedImpl(super.compute);
}

// ============================================================================
// Batch Implementation
// ============================================================================
