/// Signature of callbacks that have no arguments and return no data.
///
/// This is a standard callback type used throughout the reactive system
/// for listener notifications. It mirrors Flutter's `VoidCallback` type
/// for consistency and interoperability.
typedef VoidCallback = void Function();

/// An object that maintains a list of listeners and notifies them when changes occur.
///
/// This is the base interface for the observer pattern implementation in Pureflow.
/// Any object that needs to notify external code about state changes should
/// implement this interface.
///
/// ## Usage
///
/// ```dart
/// void callback() => print('State changed!');
///
/// final store = Store<int>(0);
/// store.addListener(callback);
/// store.value = 1; // Prints: State changed!
/// store.removeListener(callback);
/// ```
///
/// ## Thread Safety
///
/// Listeners are notified synchronously in the order they were added.
/// Adding or removing listeners during notification is safe but the changes
/// will only take effect in the next notification cycle.
abstract class Observable {
  /// Registers a callback to be invoked whenever this object notifies its listeners.
  ///
  /// The [listener] callback will be called synchronously each time the
  /// observable's state changes. The same listener can be added multiple times,
  /// and will be called once for each registration.
  ///
  /// ## Parameters
  /// - [listener]: A callback function that takes no arguments and returns nothing.
  ///
  /// ## Example
  /// ```dart
  /// final store = Store<int>(0);
  /// store.addListener(() {
  ///   print('Current value: ${store.value}');
  /// });
  /// ```
  ///
  /// ## Performance
  /// This operation is O(1) as it uses a linked list internally.
  void addListener(VoidCallback listener);

  /// Removes a previously registered listener callback.
  ///
  /// If the [listener] was registered multiple times, only the first
  /// occurrence will be removed. If the listener was not registered,
  /// this method does nothing.
  ///
  /// ## Parameters
  /// - [listener]: The exact callback function reference that was previously
  ///   passed to [addListener].
  ///
  /// ## Example
  /// ```dart
  /// void onUpdate() => print('Updated');
  ///
  /// store.addListener(onUpdate);
  /// // ... later ...
  /// store.removeListener(onUpdate);
  /// ```
  ///
  /// ## Performance
  /// This operation is O(n) where n is the number of registered listeners,
  /// as it needs to search for the matching callback.
  void removeListener(VoidCallback listener);
}

/// An [Observable] that holds a readable value of type [T].
///
/// This interface combines the observer pattern with value storage,
/// allowing consumers to both read the current value and subscribe
/// to changes.
///
/// ## Type Parameters
/// - [T]: The type of value held by this observable.
///
/// ## Usage
///
/// ```dart
/// ValueHolder<int> counter = Store<int>(0);
/// print(counter.value); // 0
///
/// counter.addListener(() {
///   print('Counter changed to: ${counter.value}');
/// });
/// ```
abstract class ValueHolder<T> implements Observable {
  /// The current value held by this object.
  ///
  /// Reading this property always returns the most up-to-date value.
  /// For `Computed` values, accessing this may trigger lazy recomputation
  /// if the value is marked as dirty.
  ///
  /// ## Dependency Tracking
  ///
  /// When accessed inside a `Computed` computation, this automatically
  /// registers the source as a dependency. This enables automatic
  /// recomputation when dependencies change.
  ///
  /// ## Example
  /// ```dart
  /// final name = Store<String>('Alice');
  /// final greeting = Computed(() => 'Hello, ${name.value}!');
  /// print(greeting.value); // Hello, Alice!
  /// ```
  T get value;
}

/// A [ValueHolder] that also implements [Stream] for reactive data binding.
///
/// This interface extends [ValueHolder] with [Stream] capabilities,
/// enabling use with `StreamBuilder` and other stream-based consumers.
/// It provides a bridge between the synchronous listener pattern and
/// Dart's asynchronous stream pattern.
///
/// ## Type Parameters
/// - [T]: The type of value emitted by this reactive holder.
///
/// ## Stream Behavior
///
/// The stream is a broadcast stream that emits the current value
/// immediately upon subscription and then emits new values whenever
/// the underlying value changes.
///
/// ## Usage
///
/// ```dart
/// final counter = Store<int>(0);
///
/// // As a Stream
/// counter.listen((value) {
///   print('Stream received: $value');
/// });
///
/// // With StreamBuilder in Flutter
/// StreamBuilder<int>(
///   stream: counter,
///   builder: (context, snapshot) => Text('Count: ${snapshot.data}'),
/// );
/// ```
abstract class ReactiveValueHolder<T>
    with Stream<T>
    implements ValueHolder<T> {}
