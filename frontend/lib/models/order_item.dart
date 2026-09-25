/// Una linea de un pedido.
///
/// El nombre y el precio son la COPIA que se guardo al comprar, no los del
/// plato de hoy: si el restaurante sube el precio manana, el pedido de ayer
/// sigue mostrando lo que se pago.
///
/// Espeja `backend/app/Http/Resources/OrderItemResource.php`.
class OrderItem {
  const OrderItem({
    required this.id,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.productId,
  });

  final int id;

  /// Puede ser null si el restaurante borro el plato despues. La linea igual
  /// muestra su nombre y su precio.
  final int? productId;

  final String name;

  /// Como String, por lo del dinero: nunca pasa por double.
  final String unitPrice;

  final int quantity;
  final String subtotal;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as int,
      productId: json['product_id'] as int?,
      name: json['name'] as String,
      unitPrice: '${json['unit_price']}',
      quantity: json['quantity'] as int,
      subtotal: '${json['subtotal']}',
    );
  }
}
