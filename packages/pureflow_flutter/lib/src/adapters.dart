import 'package:flutter/foundation.dart';
import 'package:pureflow/src/value_unit/value_unit.dart' as pureflow;

/// Zero-allocation view adapter - просто делегирует вызовы.
/// Используйте когда нужен только ValueListenable без возможности
/// изменять значение через адаптер.
class ValueUnitListenable<T> implements ValueListenable<T> {
  const ValueUnitListenable._(this._source);

  @pragma('vm:prefer-inline')
  factory ValueUnitListenable(pureflow.Store<T> source) =>
      (_listenables[source] ??= ValueUnitListenable<T>._(source))
          as ValueUnitListenable<T>;

  static final _listenables = Expando<ValueUnitListenable<Object?>>();

  final pureflow.Store<T> _source;

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

extension ValueUnitFlutterX<T> on pureflow.Store<T> {
  /// Создаёт легковесный read-only view как ValueListenable.
  /// Zero overhead - просто делегирует вызовы.
  @pragma('vm:prefer-inline')
  ValueListenable<T> get asListenable => ValueUnitListenable<T>(this);
}

extension CompositeViewFlutterX<T> on pureflow.Computed<T> {
  /// CompositeView как ValueListenable (read-only по определению).
  @pragma('vm:prefer-inline')
  ValueListenable<T> get asListenable => _CompositeViewListenable<T>(this);
}

/// Lightweight adapter для CompositeView
class _CompositeViewListenable<T> implements ValueListenable<T> {
  const _CompositeViewListenable(this._source);

  final pureflow.Computed<T> _source;

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
