// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:meta/meta.dart';

/// A [Future] whose [then] implementation calls the callback immediately.
///
/// This is similar to [Future.value], except that the value is available in
/// the same event-loop iteration.
///
/// ⚠ This class is useful in cases where you want to expose a single API, where
/// you normally want to have everything execute synchronously, but where on
/// rare occasions you want the ability to switch to an asynchronous model. **In
/// general use of this class should be avoided as it is very difficult to debug
/// such bimodal behavior.**
///
/// A [SynchronousFuture] will never complete with an error.
@internal
final class SynchronousFuture<T> implements Future<T> {
  const SynchronousFuture(this._value);
  final T _value;

  @override
  Stream<T> asStream() => Stream<T>.value(_value);

  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) => this;

  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) =>
      switch (onValue(_value)) {
        final Future<R> r => r,
        final r => SynchronousFuture<R>(r),
      };

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      Future<T>.value(_value).timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) {
    try {
      final r = action();
      return r is Future ? r.then((_) => _value) : this;
    } catch (e, s) {
      return Future<T>.error(e, s);
    }
  }
}
