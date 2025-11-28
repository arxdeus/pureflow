import 'package:pureflow/src/impl.dart';

/// A computed value that automatically tracks its dependencies.
///
/// Computed values are derived from signals and other computed values.
/// They automatically track which signals they depend on by monitoring
/// signal access during computation.
abstract class Computed<T> {
  /// Creates a new computed value from a computation function.
  factory Computed(T Function() compute) => ComputedImpl<T>(compute);

  /// Gets the current value of the computed, recomputing if necessary.
  T get value;

  /// Disposes the computed and releases all resources.
  void dispose();
}
