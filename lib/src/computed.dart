import 'package:pureflow/src/implementation/state/computed_impl.dart';
import 'package:pureflow/src/interfaces.dart';

// ============================================================================
// Computed - Public Interface
// ============================================================================

/// A computed value that automatically tracks its dependencies.
///
/// Computed lazily recomputes its value when dependencies change.
abstract class Computed<T> implements ReactiveValueHolder<T> {
  /// Creates a new [Computed] with the given computation function.
  factory Computed(T Function() compute) = ComputedImpl<T>;

  /// The current computed value.
  ///
  /// Accessing this will trigger recomputation if the value is dirty.
  @override
  T get value;

  /// Disposes this computed and releases all resources.
  void dispose();
}
