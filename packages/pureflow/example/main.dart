import 'dart:async';
import 'package:pureflow/pureflow.dart';

void main() async {
  // Store - Reactive State
  final cartItems = Store<List<CartItem>>([
    CartItem(name: 'Apple', price: 1.50, quantity: 3),
    CartItem(name: 'Banana', price: 0.75, quantity: 5),
    CartItem(name: 'Orange', price: 2.00, quantity: 2),
  ]);

  final discountRate = Store<double>(0.10);

  // Computed - Derived Reactive Values
  final subtotal = Computed(() {
    return cartItems.value.fold<double>(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
  });

  final discountAmount = Computed(() => subtotal.value * discountRate.value);
  final total = Computed(() => subtotal.value - discountAmount.value);

  print('Initial Total: \$${total.value.toStringAsFixed(2)}');

  // Update cart - computed values update automatically
  cartItems.update((items) => [
        ...items,
        CartItem(name: 'Grapes', price: 3.50, quantity: 1),
      ]);

  print('After adding Grapes: \$${total.value.toStringAsFixed(2)}');

  discountRate.value = 0.15;
  print('After 15% discount: \$${total.value.toStringAsFixed(2)}');

  // Pipeline - Async Task Processing
  final pipeline = Pipeline(
    transformer: (source, process) => source.asyncExpand(process),
  );

  final result = await pipeline.run((context) async {
    if (!context.isActive) return 'Cancelled';

    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!context.isActive) return 'Cancelled during operation';

    return 'Saved: ${cartItems.value.length} items';
  });

  print('Pipeline result: $result');

  // Listen to changes
  final subscription = total.listen((value) {
    print('Total changed: \$${value.toStringAsFixed(2)}');
  });

  cartItems.update((items) => items.take(items.length - 1).toList());
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await subscription.cancel();

  // Cleanup
  cartItems.dispose();
  discountRate.dispose();
  subtotal.dispose();
  discountAmount.dispose();
  total.dispose();
  await pipeline.dispose();
}

class CartItem {
  final String name;
  final double price;
  final int quantity;

  CartItem({
    required this.name,
    required this.price,
    required this.quantity,
  });
}
