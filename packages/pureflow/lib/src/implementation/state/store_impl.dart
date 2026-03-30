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
      : _equals = equality ?? defaultEquals {
    final observer = Pureflow.observer;
    observer?.onCreated?.call(debugLabel, FlowKind.store);
  }

  @override
  final String? debugLabel;
  T _value;
  bool inBatch = false;
  final bool Function(T, T) _equals;

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

    if (_equals(_value, newValue)) return;

    final observer = Pureflow.observer;
    final hasObserver =
        observer != null && observer.onObservableChanged != null;

    late final Object? oldValue;
    if (hasObserver) {
      oldValue = _value;
    }

    _value = newValue;

    observer?.onObservableChanged?.call(
      debugLabel,
      FlowKind.store,
      oldValue,
      newValue,
    );

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
