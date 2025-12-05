import 'package:pureflow/src/common/bit_flags.dart';
import 'package:pureflow/src/implementation/state/store_impl.dart';
import 'package:pureflow/src/internal/state/globals.dart';

/// Current batch depth for batched updates.
int batchDepth = 0;

/// Pre-allocated batch buffer for better performance.
final List<StoreImpl<Object?>?> batchBuffer =
    List.filled(64, null, growable: true);
int batchCount = 0;

/// Runs a function within a batch context, deferring all notifications.
///
/// When multiple stores are updated within a batch, listeners and
/// dependent computed values are only notified once after the batch
/// completes. This improves performance and prevents intermediate
/// inconsistent states from being observed.
///
/// ## Parameters
/// - [action]: A function that performs multiple store updates.
///
/// ## Returns
/// The value returned by [action].
///
/// ## Example
/// ```dart
/// final firstName = Store<String>('');
/// final lastName = Store<String>('');
/// final updateCount = Store<int>(0);
///
/// // Without batching: 2 notifications
/// firstName.value = 'John';
/// lastName.value = 'Doe';
///
/// // With batching: 1 notification after both updates
/// batch(() {
///   firstName.value = 'Jane';
///   lastName.value = 'Smith';
/// });
/// ```
///
/// ## Nested Batches
///
/// Batches can be nested. Notifications are only sent when the outermost
/// batch completes:
///
/// ```dart
/// batch(() {
///   counter.value = 1;
///   batch(() {
///     counter.value = 2;
///   }); // No notification yet
///   counter.value = 3;
/// }); // Single notification with value 3
/// ```
///
/// ## Error Handling
///
/// If [action] throws an exception, the batch is still completed and
/// pending notifications are sent before the exception propagates.
@pragma('vm:prefer-inline')
R batch<R>(R Function() action) {
  batchDepth++;
  try {
    return action();
  } finally {
    if (--batchDepth == 0) _flushBatch();
  }
}

@pragma('vm:prefer-inline')
void _flushBatch() {
  final count = batchCount;
  if (count == 0) return;

  for (var i = 0; i < count; i++) {
    final store = batchBuffer[i]!;
    store.inBatch = false;
    if (!store.status.hasFlag(disposedBit)) {
      store.notifySubscribers();
    }
    batchBuffer[i] = null; // Avoid memory leak
  }
  batchCount = 0;
}
