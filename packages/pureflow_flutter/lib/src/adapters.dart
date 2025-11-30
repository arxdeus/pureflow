import 'package:flutter/foundation.dart';
import 'package:pureflow/pureflow.dart' as pureflow;

/// Zero-allocation view adapter - просто делегирует вызовы.
/// Используйте когда нужен только ValueListenable без возможности
/// изменять значение через адаптер.
class ValueUnitListenable<T> implements ValueListenable<T> {
  const ValueUnitListenable._(this._source);

  @pragma('vm:prefer-inline')
  factory ValueUnitListenable(pureflow.ValueHolder<T> source) =>
      (_listenables[source] ??= ValueUnitListenable<T>._(source))
          as ValueUnitListenable<T>;

  static final _listenables = Expando<ValueUnitListenable<Object?>>();

  final pureflow.ValueHolder<T> _source;

  @override
  @pragma('vm:prefer-inline')
  T get value => _source.value;

  @override
  @pragma('vm:prefer-inline')
  void addListener(VoidCallback listener) => _source.addListener(listener);

  @override
  @pragma('vm:prefer-inline')
  void removeListener(VoidCallback listener) =>
      _source.removeListener(listener);
}

// ============================================================================
// Extensions для удобного преобразования
// ============================================================================

extension ValueUnitFlutterX<T> on pureflow.ValueHolder<T> {
  /// Создаёт легковесный read-only view как ValueListenable.
  /// Zero overhead - просто делегирует вызовы.
  @pragma('vm:prefer-inline')
  ValueListenable<T> get asListenable => ValueUnitListenable<T>(this);
}
