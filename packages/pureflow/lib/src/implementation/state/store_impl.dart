import 'package:meta/meta.dart';
import 'package:pureflow/src/common/bit_flags.dart';
import 'package:pureflow/src/common/equality.dart';
import 'package:pureflow/src/internal/state/reactive_source.dart';
import 'package:pureflow/src/store.dart';

// ============================================================================
// StoreImpl (Signal) - Optimized Implementation
// ============================================================================

/// Implementation of [Store].
class StoreImpl<T> extends ReactiveSource<T> implements Store<T> {
  StoreImpl(this._value, {bool Function(T, T)? equality})
      : _equality = equality;

  T _value;
  bool _inBatch = false;
  final bool Function(T, T)? _equality;

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

    // Optimized inline equality check
    if (checkEquality(_value, newValue, _equality)) return;

    _value = newValue;

    // Handle batching - defer notification
    if (batchDepth > 0) {
      if (!_inBatch) {
        _inBatch = true;
        // Use pre-allocated buffer, grow if needed
        if (batchCount >= batchBuffer.length) {
          batchBuffer.length *= 2;
        }
        batchBuffer[batchCount++] = this;
      }
      return;
    }

    // Notify all subscribers (listeners + dependencies)
    notifySubscribers();
  }

  @override
  @pragma('vm:prefer-inline')
  void update(T Function(T) updater) => value = updater(_value);

  @override
  String toString() => 'Store<$T>($_value)';
}

// ============================================================================
// Batch Implementation (accessible from Store)
// ============================================================================

/// Runs a function within a batch context.
@internal
@pragma('vm:prefer-inline')
R runBatch<R>(R Function() action) {
  batchDepth++;
  try {
    return action();
  } finally {
    if (--batchDepth == 0) flushBatch();
  }
}

@internal
@pragma('vm:prefer-inline')
void flushBatch() {
  final count = batchCount;
  if (count == 0) return;

  for (var i = 0; i < count; i++) {
    final signal = batchBuffer[i]! as StoreImpl<Object?>;
    signal._inBatch = false;
    if (!signal.status.hasFlag(disposedBit)) {
      signal.notifySubscribers();
    }
    batchBuffer[i] = null; // Avoid memory leak
  }
  batchCount = 0;
}
