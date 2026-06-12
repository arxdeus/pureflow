import 'dart:async';

import 'package:meta/meta.dart';
import 'package:pureflow/src/common/bit_flags.dart';
import 'package:pureflow/src/common/synchronous_future.dart';
import 'package:pureflow/src/interfaces.dart';
import 'package:pureflow/src/internal/state/globals.dart';
import 'package:pureflow/src/internal/state/listener_node.dart';

/// Interface for reactive sources used by ReactiveSubscription.
@internal
abstract interface class ReactiveSourceLike<T> {
  T get value;
  int get status;
  ListenerNode addListener(VoidCallback listener);
  void addListenerNode(ListenerNode node);
  void removeListenerNode(ListenerNode node);
}

// ============================================================================
// Synchronous StreamSubscription for ReactiveSource
// ============================================================================

/// A lightweight [StreamSubscription] implementation that wraps a
/// reactive source listener without using [StreamController].
///
/// Extends [ListenerNode] so the subscription itself is the node in the
/// source's listener list: no extra node allocation per `listen()`, and
/// `ReactiveSource.dispose` can notify subscriptions with a plain type
/// check instead of carrying a dispose hook on every [ListenerNode].
@internal
class ReactiveSubscription<T> extends ListenerNode
    implements StreamSubscription<T> {
  ReactiveSubscription(
    this._source,
    void Function(T)? onData,
    void Function()? onDone,
  )   : _onData = onData,
        _onDone = onDone,
        super(_noop) {
    // Check if source is already disposed - inline
    if (_source.status.hasFlag(disposedBit)) {
      onSourceDisposed();
      return;
    }

    callback = _handleData;
    _source.addListenerNode(this);
  }

  static void _noop() {}

  final ReactiveSourceLike<T> _source;
  void Function(T)? _onData;
  void Function()? _onDone;

  bool _isCanceled = false;
  int _pauseCount = 0;

  void _handleData() {
    if (!_isCanceled && _onData != null && _pauseCount == 0) {
      _onData!(_source.value);
    }
  }

  /// Called by the source when it is disposed.
  void onSourceDisposed() {
    if (_isCanceled) return;
    _isCanceled = true;
    _onDone?.call();
    _onDone = null;
    _onData = null;
  }

  @override
  Future<void> cancel() {
    if (!_isCanceled) {
      _isCanceled = true;
      _source.removeListenerNode(this);
      _onDone?.call();
    }
    return const SynchronousFuture<void>(null);
  }

  @override
  void onData(void Function(T)? handleData) {
    _onData = handleData;
  }

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {
    _onDone = handleDone;
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    _pauseCount++;
    resumeSignal?.then((_) => resume());
  }

  @override
  void resume() {
    if (_pauseCount > 0) _pauseCount--;
  }

  @override
  bool get isPaused => _pauseCount > 0;

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    final completer = Completer<E>();
    final previousOnDone = _onDone;
    _onDone = () {
      previousOnDone?.call();
      if (!completer.isCompleted) {
        completer.complete(futureValue as E);
      }
    };
    return completer.future;
  }
}
