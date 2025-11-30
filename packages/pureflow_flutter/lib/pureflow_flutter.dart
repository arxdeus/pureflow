/// ## Usage
///
/// ### With ValueListenableBuilder
///
/// The simplest way to use Pureflow with Flutter is through the `asListenable`
/// extension:
///
/// ```dart
/// import 'package:pureflow/pureflow.dart';
/// import 'package:pureflow_flutter/pureflow_flutter.dart';
///
/// class CounterPage extends StatelessWidget {
///   final counter = Store<int>(0);
///
///   @override
///   Widget build(BuildContext context) {
///     return ValueListenableBuilder<int>(
///       valueListenable: counter.asListenable,
///       builder: (context, value, child) {
///         return Text('Count: $value');
///       },
///     );
///   }
/// }
/// ```
///
/// ### With AnimatedBuilder
///
/// Since `ValueListenable` extends `Listenable`, you can use Pureflow stores
/// with any widget that accepts a `Listenable`:
///
/// ```dart
/// AnimatedBuilder(
///   animation: counter.asListenable,
///   builder: (context, child) => Text('${counter.value}'),
/// );
/// ```
///
/// ### With Computed Values
///
/// Computed values work the same way:
///
/// ```dart
/// final firstName = Store<String>('John');
/// final lastName = Store<String>('Doe');
/// final fullName = Computed(() => '${firstName.value} ${lastName.value}');
///
/// // In widget
/// ValueListenableBuilder<String>(
///   valueListenable: fullName.asListenable,
///   builder: (context, name, child) => Text('Hello, $name!'),
/// );
/// ```
///
/// ## Performance
///
/// The `ValueUnitListenable` adapter is designed for zero overhead:
/// - No additional memory allocation per access
/// - Instances are cached per source using `Expando`
/// - Direct delegation to Pureflow's listener system
library;

export 'package:pureflow/pureflow.dart';
export 'src/adapters.dart' show ValueUnitFlutterX, ValueUnitListenable;
