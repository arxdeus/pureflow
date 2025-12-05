import 'package:flutter/foundation.dart';
import 'package:pureflow/pureflow.dart' as pureflow;

/// A zero-allocation adapter that exposes a Pureflow `ValueObservable` as a Flutter
/// [ValueListenable].
///
/// This adapter enables seamless integration between Pureflow's reactive system
/// and Flutter's widget layer. It implements [ValueListenable] by delegating
/// all operations to the underlying Pureflow source, with no additional memory
/// overhead.
///
/// ## Features
///
/// - **Zero allocation**: Uses [Expando] to cache instances, no new objects created
///   for repeated access to the same source
/// - **Read-only**: Provides only read access to the value; mutations must go
///   through the original `Store`
/// - **Transparent delegation**: All listener management is handled by the
///   underlying Pureflow source
///
/// ## Usage with ValueListenableBuilder
///
/// ```dart
/// final counter = Store<int>(0);
///
/// Widget build(BuildContext context) {
///   return ValueListenableBuilder<int>(
///     valueListenable: ValueObservableAdapter(counter),
///     builder: (context, value, child) {
///       return Text('Count: $value');
///     },
///   );
/// }
/// ```
///
/// ## Using the Extension
///
/// For cleaner syntax, use the [ValueObservableFlutterX.asListenable] extension:
///
/// ```dart
/// ValueListenableBuilder<int>(
///   valueListenable: counter.asListenable,
///   builder: (context, value, child) => Text('Count: $value'),
/// );
/// ```
///
/// ## Caching Behavior
///
/// The factory constructor ensures only one [ValueObservableAdapter] instance exists
/// per source. This means:
///
/// ```dart
/// final counter = Store<int>(0);
/// final a = ValueObservableAdapter(counter);
/// final b = ValueObservableAdapter(counter);
/// print(identical(a, b)); // true
/// ```
///
/// ## Type Parameters
///
/// - [T]: The type of value held by the source and exposed by this listenable.
class ValueObservableAdapter<T> implements ValueListenable<T> {
  /// Creates or retrieves a cached [ValueObservableAdapter] for the given source.
  ///
  /// This factory constructor uses an [Expando] to cache instances, ensuring
  /// that only one adapter exists per source. This prevents memory leaks and
  /// ensures consistent behavior across the application.
  ///
  /// ## Parameters
  /// - [source]: A Pureflow `ValueObservable` (typically a `Store` or `Computed`)
  ///   to adapt to Flutter's `ValueListenable` interface.
  ///
  /// ## Returns
  /// A [ValueObservableAdapter] that wraps the source. If an adapter for this
  /// source already exists, returns the cached instance.
  ///
  /// ## Example
  /// ```dart
  /// final store = Store<String>('Hello');
  /// final listenable = ValueObservableAdapter(store);
  /// ```
  @pragma('vm:prefer-inline')
  factory ValueObservableAdapter(pureflow.ValueObservable<T> source) =>
      (_listenables[source] ??= ValueObservableAdapter<T>._(source))
          as ValueObservableAdapter<T>;

  const ValueObservableAdapter._(this._source);

  static final _listenables = Expando<ValueObservableAdapter<Object?>>();

  final pureflow.ValueObservable<T> _source;

  /// The current value of the underlying source.
  ///
  /// This getter directly delegates to the source's [value] property,
  /// providing zero-overhead access to the current value.
  ///
  /// ## Returns
  /// The current value of type [T] from the underlying `ValueObservable`.
  ///
  /// ## Example
  /// ```dart
  /// final counter = Store<int>(42);
  /// final listenable = ValueObservableAdapter(counter);
  /// print(listenable.value); // 42
  /// ```
  @override
  @pragma('vm:prefer-inline')
  T get value => _source.value;

  /// Registers a listener to be called when the value changes.
  ///
  /// This method delegates directly to the underlying source's [addListener],
  /// so the listener will be called according to Pureflow's notification
  /// semantics.
  ///
  /// ## Parameters
  /// - [listener]: A callback function that takes no arguments. It will be
  ///   called synchronously whenever the source's value changes.
  ///
  /// ## Example
  /// ```dart
  /// final counter = Store<int>(0);
  /// final listenable = ValueObservableAdapter(counter);
  ///
  /// listenable.addListener(() {
  ///   print('Value changed to: ${listenable.value}');
  /// });
  ///
  /// counter.value = 1; // Prints: Value changed to: 1
  /// ```
  ///
  /// ## Note
  ///
  /// Remember to call [removeListener] when the listener is no longer needed
  /// to prevent memory leaks.
  @override
  @pragma('vm:prefer-inline')
  void addListener(VoidCallback listener) => _source.addListener(listener);

  /// Removes a previously registered listener.
  ///
  /// This method delegates directly to the underlying source's [removeListener].
  /// If the listener was not previously registered, this method does nothing.
  ///
  /// ## Parameters
  /// - [listener]: The exact callback function reference that was previously
  ///   passed to [addListener].
  ///
  /// ## Example
  /// ```dart
  /// void onValueChanged() => print('Changed!');
  ///
  /// listenable.addListener(onValueChanged);
  /// // ... later ...
  /// listenable.removeListener(onValueChanged);
  /// ```
  @override
  @pragma('vm:prefer-inline')
  void removeListener(VoidCallback listener) =>
      _source.removeListener(listener);
}

extension ValueObservableAdapterExtension<T> on pureflow.ValueObservable<T> {
  /// Creates a lightweight read-only view as a Flutter [ValueListenable].
  ///
  /// This getter provides zero-overhead access to a [ValueListenable] wrapper
  /// around this `ValueObservable`. The returned adapter simply delegates all
  /// operations to this source.
  ///
  /// ## Returns
  /// A `ValueListenable` that wraps this `ValueObservable` and provides read-only
  /// access to its value.
  ///
  /// ## Example
  /// ```dart
  /// final counter = Store<int>(0);
  ///
  /// // Use with ValueListenableBuilder
  /// ValueListenableBuilder<int>(
  ///   valueListenable: counter.asListenable,
  ///   builder: (context, value, child) => Text('$value'),
  /// );
  ///
  /// // Use with AnimatedBuilder
  /// AnimatedBuilder(
  ///   animation: counter.asListenable,
  ///   builder: (context, child) => Text('${counter.value}'),
  /// );
  /// ```
  ///
  /// ## Caching
  ///
  /// Repeated calls to [asListenable] on the same source return the same
  /// `ValueListenable` instance, ensuring efficient memory usage:
  ///
  /// ```dart
  /// final store = Store<int>(0);
  /// print(identical(store.asListenable, store.asListenable)); // true
  /// ```
  @pragma('vm:prefer-inline')
  ValueListenable<T> get asListenable => ValueObservableAdapter<T>(this);
}
