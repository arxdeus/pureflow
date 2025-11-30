/// Signature of callbacks that have no arguments and return no data.
typedef VoidCallback = void Function();

/// An object that maintains a list of listeners.
abstract class Observable {
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
}

/// An Observable that holds a value.
abstract class ValueHolder<T> implements Observable {
  T get value;
}

abstract class ReactiveValueHolder<T>
    with Stream<T>
    implements ValueHolder<T> {}
