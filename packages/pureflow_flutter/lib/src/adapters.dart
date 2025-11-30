import 'package:flutter/foundation.dart';
import 'package:pureflow/src/listenable/listenable.dart' as pureflow;

/// Zero-allocation view adapter - просто делегирует вызовы.
/// Используйте когда нужен только ValueListenable без возможности
/// изменять значение через адаптер.
class ValueUnitView<T> implements ValueListenable<T> {
  const ValueUnitView._(this._source);

  @pragma('vm:prefer-inline')
  factory ValueUnitView(pureflow.ValueUnit<T> source) =>
      (_listenables[source] ??= ValueUnitView<T>._(source)) as ValueUnitView<T>;

  static final _listenables = Expando<ValueUnitView<Object?>>();

  final pureflow.ValueUnit<T> _source;

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

extension ValueUnitFlutterX<T> on pureflow.ValueUnit<T> {
  /// Создаёт легковесный read-only view как ValueListenable.
  /// Zero overhead - просто делегирует вызовы.
  @pragma('vm:prefer-inline')
  ValueListenable<T> get asListenable => ValueUnitView<T>(this);
}

extension CompositeViewFlutterX<T> on pureflow.CompositeUnit<T> {
  /// CompositeView как ValueListenable (read-only по определению).
  @pragma('vm:prefer-inline')
  ValueListenable<T> get asListenable => _CompositeViewListenable<T>(this);
}

/// Lightweight adapter для CompositeView
class _CompositeViewListenable<T> implements ValueListenable<T> {
  const _CompositeViewListenable(this._source);

  final pureflow.CompositeUnit<T> _source;

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
