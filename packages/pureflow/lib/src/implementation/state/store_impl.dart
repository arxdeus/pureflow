import 'package:meta/meta.dart';
import 'package:pureflow/src/batch.dart';
import 'package:pureflow/src/common/bit_flags.dart';
import 'package:pureflow/src/internal/state/reactive_source.dart';
import 'package:pureflow/src/observer.dart';
import 'package:pureflow/src/store.dart';

// ============================================================================
// StoreImpl (Store) - Optimized Implementation
// ============================================================================

/// Implementation of [Store].
@internal
class StoreImpl<T> extends ReactiveSource<T> implements Store<T> {
  StoreImpl(this._value, {bool Function(T, T)? equality, this.debugLabel})
      : _equals = equality {
    final observer = Pureflow.observer;
    observer?.onCreated?.call(debugLabel, FlowKind.store);
  }

  @override
  final String? debugLabel;
  T _value;

  /// Custom equality, or `null` for the default (`identical` || `==`).
  ///
  /// Kept nullable on purpose: storing a generic `defaultEquals` tear-off
  /// would allocate an instantiated closure per Store and force an indirect
  /// call on every write. The null branch inlines the default comparison.
  final bool Function(T, T)? _equals;

  @override
  @pragma('vm:prefer-inline')
  T get value {
    // Fast path: no tracking needed (common case)
    final targetView = currentView;
    if (targetView != null) {
      trackDependency(targetView);
    }
    return _value;
  }

  @override
  @pragma('vm:prefer-inline')
  set value(T newValue) {
    // Disposed check first (cheap bit operation)
    if (status.hasFlag(disposedBit)) return;

    // Default equality inlined; custom equality via indirect call.
    final eq = _equals;
    if (eq == null
        ? identical(_value, newValue) || _value == newValue
        : eq(_value, newValue)) {
      return;
    }

    final oldValue = _value;
    _value = newValue;

    // Observer plumbing kept out-of-line to keep the common path lean.
    if (Pureflow.observer != null) {
      _notifyObserverChanged(oldValue, newValue);
    }

    // Handle batching - defer notification
    if (batchDepth > 0) {
      if (!status.hasFlag(inBatchBit)) {
        status = status.setFlag(inBatchBit);
        // Use pre-allocated buffer, grow if needed
        if (batchCount >= batchBuffer.length) {
          batchBuffer.length *= 2;
        }
        batchBuffer[batchCount++] = this;
      }
      return;
    }

    // Fast path: skip notification if no listeners or dependencies
    if (!hasListeners) {
      return;
    }
    // Notify all subscribers (listeners + dependencies)
    notifySubscribers();
  }

  @pragma('vm:never-inline')
  void _notifyObserverChanged(Object? oldValue, T newValue) {
    Pureflow.observer?.onObservableChanged?.call(
      debugLabel,
      FlowKind.store,
      oldValue,
      newValue,
    );
  }

  @override
  @pragma('vm:prefer-inline')
  void update(T Function(T) updater) => value = updater(_value);

  @override
  String toString() {
    final sb = StringBuffer('Store<$T>');
    if (debugLabel != null) {
      sb.write('[$debugLabel]');
    }
    sb.write('($_value)');
    return sb.toString();
  }
}
