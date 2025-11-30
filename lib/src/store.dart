import 'package:pureflow/src/implementation/state/store_impl.dart';
import 'package:pureflow/src/interfaces.dart';

// ============================================================================
// Store (Signal) - Public Interface
// ============================================================================

/// A reactive signal that holds a single value.
///
/// Uses optimized subscription system for both callback listeners
/// and reactive dependencies.
abstract class Store<T> implements ReactiveValueHolder<T> {
  /// Creates a new [Store] with the given initial value.
  factory Store(T value) = StoreImpl<T>;

  /// Runs a function within a batch context.
  ///
  /// All signal updates within the function will be batched,
  /// and dependents will only be notified once after completion.
  static R batch<R>(R Function() action) => runBatch(action);

  /// The current value of this store.
  @override
  T get value;

  /// Sets the current value of this store.
  set value(T newValue);

  /// Updates the value using a function.
  void update(T Function(T) updater);

  /// Disposes this store and releases all resources.
  void dispose();
}
