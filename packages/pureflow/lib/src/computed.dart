import 'package:pureflow/src/implementation/state/computed_impl.dart';
import 'package:pureflow/src/interfaces.dart';

// ============================================================================
// Computed - Public Interface
// ============================================================================

/// A derived reactive value that automatically tracks its dependencies and
/// recomputes lazily when they change.
///
/// [Computed] is the core primitive for derived state in Pureflow. It wraps
/// a computation function and automatically:
/// - Tracks which `Store` and [Computed] values are accessed during computation
/// - Marks itself as "dirty" when any dependency changes
/// - Lazily recomputes the value only when accessed and dirty
/// - Caches the computed value for repeated access
///
/// ## Features
///
/// - **Automatic dependency tracking**: No manual subscription management
/// - **Lazy evaluation**: Computation runs only when the value is accessed
/// - **Memoization**: Repeated access returns cached value without recomputation
/// - **Glitch-free**: Intermediate states are never observed
/// - **Cycle detection**: Throws [StateError] if a computation cycle is detected
///
/// ## Basic Usage
///
/// ```dart
/// final firstName = Store<String>('John');
/// final lastName = Store<String>('Doe');
///
/// final fullName = Computed(() => '${firstName.value} ${lastName.value}');
///
/// print(fullName.value); // John Doe
///
/// firstName.value = 'Jane';
/// print(fullName.value); // Jane Doe (recomputed automatically)
/// ```
///
/// ## Chained Computeds
///
/// Computed values can depend on other computed values, creating a reactive
/// computation graph:
///
/// ```dart
/// final items = Store<List<int>>([1, 2, 3, 4, 5]);
/// final doubled = Computed(() => items.value.map((x) => x * 2).toList());
/// final sum = Computed(() => doubled.value.reduce((a, b) => a + b));
///
/// print(sum.value); // 30
///
/// items.value = [1, 2, 3];
/// print(sum.value); // 12 (both doubled and sum recomputed)
/// ```
///
/// ## With Conditional Dependencies
///
/// Dependencies are tracked per-computation, so conditional access works
/// correctly:
///
/// ```dart
/// final useMetric = Store<bool>(true);
/// final celsius = Store<double>(20.0);
/// final fahrenheit = Store<double>(68.0);
///
/// final temperature = Computed(() {
///   if (useMetric.value) {
///     return '${celsius.value}°C';  // Only celsius tracked
///   } else {
///     return '${fahrenheit.value}°F';  // Only fahrenheit tracked
///   }
/// });
/// ```
///
/// ## Type Parameters
///
/// - [T]: The type of the computed value.
///
/// ## Performance Notes
///
/// - Computation is O(dependencies) for dependency tracking
/// - Value access is O(1) when not dirty
/// - Memory usage is proportional to the number of dependencies
abstract class Computed<T> implements ReactiveValueObservable<T> {
  /// Creates a new [Computed] with the given computation function.
  ///
  /// The [compute] function defines how to derive the value from its
  /// dependencies. It will be called:
  /// - Lazily on first access to [value]
  /// - When [value] is accessed after any dependency has changed
  ///
  /// ## Parameters
  /// - [compute]: A function that computes and returns the derived value.
  ///   Any `Store` or [Computed] values accessed during this function's
  ///   execution are automatically tracked as dependencies.
  /// - [equality]: Optional custom equality function. If provided, this function
  ///   will be used to compare the newly computed value with the previous value.
  ///   If the values are equal, no notifications will be sent to listeners.
  ///   The function should return `true` if the two values are considered equal.
  ///
  /// ## Example
  /// ```dart
  /// final price = Store<double>(100.0);
  /// final taxRate = Store<double>(0.1);
  ///
  /// final totalPrice = Computed(() {
  ///   return price.value * (1 + taxRate.value);
  /// });
  ///
  /// // With custom equality for list comparison
  /// final filtered = Computed(
  ///   () => items.value.where((x) => x > 0).toList(),
  ///   equality: (a, b) => a.length == b.length &&
  ///                     a.every((e) => b.contains(e)),
  /// );
  /// ```
  ///
  /// ## Pure Functions
  ///
  /// The [compute] function should be pure (no side effects) for predictable
  /// behavior. Side effects may execute at unexpected times due to lazy
  /// evaluation.
  ///
  /// ## Errors
  ///
  /// If [compute] throws an exception, it will propagate to the caller of
  /// [value]. The computed remains in a dirty state and will re-execute
  /// on the next access.
  factory Computed(T Function() compute, {bool Function(T, T)? equality}) =>
      ComputedImpl<T>(compute, equality: equality);

  /// The current computed value.
  ///
  /// Accessing this property:
  /// 1. Returns the cached value immediately if not dirty
  /// 2. Recomputes the value if dirty (a dependency changed since last access)
  /// 3. Tracks this computed as a dependency if accessed inside another [Computed]
  ///
  /// ## Lazy Evaluation
  ///
  /// The computation function is not called until [value] is first accessed.
  /// This allows creating computed values before their dependencies exist:
  ///
  /// ```dart
  /// final computed = Computed(() => store.value * 2);
  /// // computation hasn't run yet
  ///
  /// print(computed.value); // Now computation runs
  /// print(computed.value); // Returns cached value, no recomputation
  /// ```
  ///
  /// ## Dependency Tracking
  ///
  /// When accessed inside another [Computed], this computed is automatically
  /// registered as a dependency:
  ///
  /// ```dart
  /// final a = Computed(() => store.value);
  /// final b = Computed(() => a.value * 2); // b depends on a
  /// ```
  ///
  /// ## Cycle Detection
  ///
  /// If a computed accesses its own [value] during computation (directly or
  /// indirectly through a chain of computeds), a [StateError] is thrown:
  ///
  /// ```dart
  /// late Computed<int> cyclic;
  /// cyclic = Computed(() => cyclic.value + 1); // Throws StateError
  /// ```
  ///
  /// ## Thread Safety
  ///
  /// Computation is synchronous and runs on the calling thread. Multiple
  /// concurrent accesses from different isolates are not supported.
  @override
  T get value;

  /// Disposes this computed and releases all resources.
  ///
  /// After disposal:
  /// - All listeners are removed
  /// - All dependency subscriptions are cancelled
  /// - Accessing [value] still works but dependencies are not tracked
  /// - The computed cannot track new dependencies
  ///
  /// ## Dependency Cleanup
  ///
  /// Disposal automatically unsubscribes from all dependencies. This prevents
  /// memory leaks where a computed keeps references to sources that are still
  /// active:
  ///
  /// ```dart
  /// final store = Store<int>(0);
  /// final computed = Computed(() => store.value * 2);
  ///
  /// computed.value; // Now subscribed to store
  /// computed.dispose(); // Unsubscribed from store
  /// ```
  ///
  /// ## When to Call
  ///
  /// Call [dispose] when the computed is no longer needed:
  /// - In a widget's `dispose()` method
  /// - When a controller is being destroyed
  /// - When leaving a scope that created the computed
  ///
  /// ## Example
  /// ```dart
  /// class CartController {
  ///   final items = Store<List<Item>>([]);
  ///   late final total = Computed(() =>
  ///     items.value.fold(0.0, (sum, item) => sum + item.price)
  ///   );
  ///
  ///   void dispose() {
  ///     total.dispose();
  ///     items.dispose();
  ///   }
  /// }
  /// ```
  ///
  /// ## Idempotent
  ///
  /// Calling [dispose] multiple times is safe; subsequent calls are no-ops.
  void dispose();
}
