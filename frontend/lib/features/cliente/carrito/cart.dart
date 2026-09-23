import '../../../core/money.dart';
import '../../../models/product.dart';

/// Una linea del carrito: un plato y cuantas unidades.
class CartItem {
  const CartItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  /// El precio del plato POR la cantidad, con Money y no con double.
  String get subtotal => Money.multiply(product.price, quantity);

  CartItem withQuantity(int quantity) {
    return CartItem(product: product, quantity: quantity);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'product': product.toJson(),
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: json['quantity'] as int,
    );
  }
}

/// El carrito de compras.
///
/// Es de UN SOLO restaurante, y eso no es una limitacion tecnica: un pedido
/// pertenece a un restaurante (mira la tabla `orders`), y quien cocina no
/// puede ser dos a la vez. Si el cliente agrega algo de otro restaurante, la
/// app le pregunta si quiere empezar de nuevo.
class Cart {
  const Cart({
    this.restaurantId,
    this.restaurantName,
    this.items = const <CartItem>[],
  });

  /// Null = carrito vacio.
  final int? restaurantId;
  final String? restaurantName;

  final List<CartItem> items;

  static const Cart empty = Cart();

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// Cuantas UNIDADES hay (no cuantas lineas): 2 pupusas + 1 horchata = 3.
  int get totalUnits =>
      items.fold(0, (int sum, CartItem item) => sum + item.quantity);

  /// El subtotal de los platos, SIN el envio.
  ///
  /// El envio no va aca a proposito: depende de a que direccion se entrega, y
  /// eso recien se sabe en el checkout. Poner un numero ahora seria mostrar
  /// uno que despues cambia.
  String get subtotal => Money.add(items.map((CartItem item) => item.subtotal));

  /// ¿El carrito es de este restaurante (o todavia esta vacio)?
  bool belongsTo(int otherRestaurantId) =>
      restaurantId == null || restaurantId == otherRestaurantId;

  /// Cuantas unidades de este plato hay.
  int quantityOf(int productId) {
    for (final CartItem item in items) {
      if (item.product.id == productId) {
        return item.quantity;
      }
    }

    return 0;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'items': items.map((CartItem item) => item.toJson()).toList(),
    };
  }

  factory Cart.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['items'] as List<dynamic>?) ?? <dynamic>[];

    return Cart(
      restaurantId: json['restaurant_id'] as int?,
      restaurantName: json['restaurant_name'] as String?,
      items: raw.cast<Map<String, dynamic>>().map(CartItem.fromJson).toList(),
    );
  }
}
