import 'package:pureflow/pureflow.dart';

void main() {
  final cart = CartController();

  void printTotalChange() =>
      print('total changed: \$${cart.total.value.toStringAsFixed(2)}');
  cart.total.addListener(printTotalChange);

  cart.addItem(const CartItem(name: 'Coffee', price: 12.50, quantity: 1));
  cart.addItem(const CartItem(name: 'Tea', price: 6.00, quantity: 2));
  cart.printReceipt('after adding items');

  cart.setDiscountRate(0.20);
  cart.printReceipt('after 20% discount');

  cart.removeItem('Tea');
  cart.printReceipt('after removing tea');

  cart.total.removeListener(printTotalChange);
  cart.dispose();
}

class CartController {
  final Store<List<CartItem>> _items = Store<List<CartItem>>(<CartItem>[]);
  final Store<double> _discountRate = Store<double>(0);

  late final Computed<double> _subtotal = Computed<double>(() {
    return _items.value.fold<double>(
      0,
      (sum, item) => sum + item.price * item.quantity,
    );
  });

  late final Computed<double> _discount = Computed<double>(
    () => _subtotal.value * _discountRate.value,
  );

  late final Computed<double> _total = Computed<double>(
    () => _subtotal.value - _discount.value,
  );

  ValueObservable<List<CartItem>> get items => _items;
  ValueObservable<double> get discountRate => _discountRate;
  ValueObservable<double> get subtotal => _subtotal;
  ValueObservable<double> get discount => _discount;
  ValueObservable<double> get total => _total;

  void addItem(CartItem item) {
    _items.update((items) {
      final index = items.indexWhere((current) => current.name == item.name);
      if (index == -1) return <CartItem>[...items, item];

      final updated = [...items];
      final current = updated[index];
      updated[index] = current.copyWith(
        quantity: current.quantity + item.quantity,
      );
      return updated;
    });
  }

  void removeItem(String name) {
    _items.update(
      (items) => items.where((item) => item.name != name).toList(),
    );
  }

  void setDiscountRate(double rate) {
    if (rate < 0 || rate > 1) {
      throw ArgumentError.value(rate, 'rate', 'Must be between 0 and 1');
    }
    _discountRate.value = rate;
  }

  void printReceipt(String label) {
    print('\n$label');
    for (final item in items.value) {
      print(
          '${item.quantity}x ${item.name}: \$${item.lineTotal.toStringAsFixed(2)}');
    }
    print('subtotal: \$${subtotal.value.toStringAsFixed(2)}');
    print('discount: \$${discount.value.toStringAsFixed(2)}');
    print('total: \$${total.value.toStringAsFixed(2)}');
  }

  void dispose() {
    _total.dispose();
    _discount.dispose();
    _subtotal.dispose();
    _discountRate.dispose();
    _items.dispose();
  }
}

class CartItem {
  final String name;
  final double price;
  final int quantity;

  const CartItem({
    required this.name,
    required this.price,
    required this.quantity,
  });

  double get lineTotal => price * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
    );
  }
}
