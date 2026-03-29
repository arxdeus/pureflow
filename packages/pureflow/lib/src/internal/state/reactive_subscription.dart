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
  void removeListenerNode(ListenerNode node);
}

// ============================================================================
// Synchronous StreamSubscription for ReactiveSource
// ============================================================================

/// A lightweight [StreamSubscription] implementation that wraps a
/// reactive source listener without using [StreamController].
@internal
class ReactiveSubscription<T> implements StreamSubscription<T> {
  ReactiveSubscription(
    this._source,
    void Function(T)? onData,
    void Function()? onDone,
  )   : _onData = onData,
        _onDone = onDone {
    // Check if source is already disposed - inline
    if (_source.status.hasFlag(disposedBit)) {
      _onSourceDisposed();
      return;
    }

    _listenerNode = _source.addListener(() {
      if (!_isCanceled && _onData != null && !_isPaused) {
        _onData!(_source.value);
      }
    });
  }

  final ReactiveSourceLike<T> _source;
  void Function(T)? _onData;
  void Function()? _onDone;

  late final ListenerNode _listenerNode;
  bool _isCanceled = false;
  bool _isPaused = false;

  /// Called by the source when it is disposed.
  void _onSourceDisposed() {
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
      _source.removeListenerNode(_listenerNode);
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
    _isPaused = true;
    resumeSignal?.then((_) => resume());
  }

  @override
  void resume() => _isPaused = false;

  @override
  bool get isPaused => _isPaused;

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
