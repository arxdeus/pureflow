import 'impl.dart';

/// A reactive signal that holds a value and notifies listeners when it changes.
abstract class Signal<T> {
  /// Creates a new Signal with an initial value.
  factory Signal(T value) => SignalImpl<T>(value);

  /// Runs a function within a batch context.
  ///
  /// All signal updates within the function will be batched,
  /// and dependents will only be notified once after completion.
  static R batch<R>(R Function() fn) => SignalImpl.batch(fn);

  /// Gets the current value of the signal.
  T get value;

  /// Sets the value of the signal and notifies all listeners.
  set value(T newValue);

  /// Updates the value using a function.
  void update(T Function(T) updater);

  /// Disposes the signal and releases all resources.
  void dispose();
}
