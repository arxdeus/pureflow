import 'package:pureflow/src/implementation/state/store_impl.dart';
import 'package:pureflow/src/interfaces.dart';

// ============================================================================
// Store (Signal) - Public Interface
// ============================================================================

/// A reactive signal that holds a single mutable value.
///
/// [Store] is the fundamental building block for reactive state management
/// in Pureflow. It wraps a value of type [T] and automatically notifies
/// all listeners and dependent `Computed` values when the value changes.
///
/// ## Features
///
/// - **Reactive updates**: Automatically notifies listeners when value changes
/// - **Dependency tracking**: `Computed` values that access this store
///   automatically become dependents
/// - **Batching support**: Multiple updates can be batched to prevent
///   intermediate notifications
/// - **Equality checking**: Uses both `identical()` and `==` to avoid
///   unnecessary notifications
///
/// ## Basic Usage
///
/// ```dart
/// // Create a store with initial value
/// final counter = Store<int>(0);
///
/// // Read the current value
/// print(counter.value); // 0
///
/// // Update the value
/// counter.value = 1;
///
/// // Update using a function
/// counter.update((current) => current + 1);
/// ```
///
/// ## Listening to Changes
///
/// ```dart
/// final name = Store<String>('Alice');
///
/// // Using callback listener
/// name.addListener(() {
///   print('Name changed to: ${name.value}');
/// });
///
/// // Using stream subscription
/// name.listen((value) {
///   print('Stream received: $value');
/// });
/// ```
///
/// ## With Computed Values
///
/// ```dart
/// final firstName = Store<String>('John');
/// final lastName = Store<String>('Doe');
///
/// final fullName = Computed(() => '${firstName.value} ${lastName.value}');
///
/// print(fullName.value); // John Doe
/// firstName.value = 'Jane';
/// print(fullName.value); // Jane Doe
/// ```
///
/// ## Type Parameters
///
/// - [T]: The type of value stored in this reactive signal.
abstract class Store<T> implements ReactiveValueHolder<T> {
  /// Creates a new [Store] with the given initial [value].
  ///
  /// The store is immediately ready for use after construction.
  /// The initial value will not trigger any notifications.
  ///
  /// ## Parameters
  /// - [value]: The initial value to store.
  /// - [equality]: Optional custom equality function. If provided, this function
  ///   will be used instead of the default equality check (`identical()` and `==`).
  ///   The function should return `true` if the two values are considered equal.
  ///
  /// ## Example
  /// ```dart
  /// final counter = Store<int>(0);
  /// final user = Store<User?>(null);
  /// final items = Store<List<String>>([]);
  ///
  /// // With custom equality for deep list comparison
  /// final listStore = Store<List<int>>([1, 2, 3],
  ///   equality: (a, b) => a.length == b.length && a.every((e) => b.contains(e)),
  /// );
  /// ```
  factory Store(T value, {bool Function(T, T)? equality}) =>
      StoreImpl<T>(value, equality: equality);

  /// The current value of this store.
  ///
  /// Reading this property returns the stored value immediately.
  /// When accessed inside a `Computed` computation, this store is
  /// automatically tracked as a dependency.
  ///
  /// ## Dependency Tracking
  ///
  /// ```dart
  /// final count = Store<int>(0);
  /// final doubled = Computed(() => count.value * 2); // count is now a dependency
  /// ```
  @override
  T get value;

  /// Sets the current value of this store.
  ///
  /// If the new value is different from the current value (checked using
  /// both `identical()` and `==`), all listeners and dependent computed
  /// values are notified of the change.
  ///
  /// ## Parameters
  /// - [newValue]: The new value to store.
  ///
  /// ## Equality Checking
  ///
  /// To avoid unnecessary notifications, the setter performs equality checks:
  /// - If a custom `equality` function was provided to the constructor, it is used
  /// - Otherwise, two checks are performed:
  ///   1. `identical(oldValue, newValue)` - fast reference equality
  ///   2. `oldValue == newValue` - value equality (for immutable objects)
  ///
  /// If the equality check returns true, no notification is sent.
  ///
  /// ## Example
  /// ```dart
  /// final counter = Store<int>(0);
  /// counter.value = 1; // Triggers notification
  /// counter.value = 1; // No notification (same value)
  /// ```
  ///
  /// ## Batching
  ///
  /// When called inside `batch`, the notification is deferred until
  /// the batch completes.
  set value(T newValue);

  /// Updates the value using a transformation function.
  ///
  /// This is a convenience method that reads the current value,
  /// applies the [updater] function, and sets the result as the new value.
  ///
  /// ## Parameters
  /// - [updater]: A function that receives the current value and returns
  ///   the new value.
  ///
  /// ## Example
  /// ```dart
  /// final counter = Store<int>(0);
  ///
  /// // Increment
  /// counter.update((n) => n + 1);
  ///
  /// // Toggle boolean
  /// final flag = Store<bool>(false);
  /// flag.update((b) => !b);
  ///
  /// // Update list (creates new list for immutability)
  /// final items = Store<List<String>>([]);
  /// items.update((list) => [...list, 'new item']);
  /// ```
  ///
  /// ## Equivalent To
  ///
  /// ```dart
  /// store.value = updater(store.value);
  /// ```
  void update(T Function(T) updater);

  /// Disposes this store and releases all resources.
  ///
  /// After disposal:
  /// - All listeners are removed
  /// - All dependency tracking is cleared
  /// - Setting the value has no effect
  /// - The store cannot be reused
  ///
  /// ## When to Call
  ///
  /// Call [dispose] when the store is no longer needed to prevent memory
  /// leaks, especially when:
  /// - The store is created in a widget that is being destroyed
  /// - The store is part of a controller being disposed
  /// - The store is used in a scope that is ending
  ///
  /// ## Example
  /// ```dart
  /// class MyController {
  ///   final counter = Store<int>(0);
  ///
  ///   void dispose() {
  ///     counter.dispose();
  ///   }
  /// }
  /// ```
  ///
  /// ## Idempotent
  ///
  /// Calling [dispose] multiple times is safe; subsequent calls are no-ops.
  void dispose();
}
