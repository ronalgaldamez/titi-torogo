import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/product.dart';
import 'cart.dart';
import 'cart_storage.dart';

/// El carrito de toda la app.
///
/// POR QUE RIVERPOD Y NO setState: el carrito se arma en la carta, se mira en
/// la hoja del carrito y se paga en el checkout. Son tres pantallas distintas
/// que tienen que ver EL MISMO dato, y con setState cada una tendria su propia
/// copia — que es exactamente como se llega a un carrito que dice una cosa en
/// una pantalla y otra en la siguiente.
///
/// Es un `Notifier` y no un `StateNotifier`: los dos funcionan, pero Notifier
/// es el que Riverpod recomienda hoy.
final NotifierProvider<CartNotifier, Cart> cartProvider =
    NotifierProvider<CartNotifier, Cart>(CartNotifier.new);

class CartNotifier extends Notifier<Cart> {
  final CartStorage _storage = CartStorage();

  @override
  Cart build() {
    // Arranca vacio y se llena en cuanto llega lo guardado.
    //
    // Leer del telefono es asincrono, pero el carrito es tan chico que se
    // resuelve en milisegundos: no vale la pena arrastrar un estado de carga
    // por todas las pantallas que lo usan.
    _restore();

    return Cart.empty;
  }

  /// Recupera el carrito guardado.
  Future<void> _restore() async {
    final Cart saved = await _storage.load();

    // Si mientras tanto el cliente ya agrego algo, NO se pisa: lo que acaba de
    // hacer vale mas que lo que habia guardado.
    if (saved.isEmpty || state.isNotEmpty) {
      return;
    }

    state = saved;
  }

  /// Agrega una unidad de un plato.
  ///
  /// Devuelve `false` si el carrito es de OTRO restaurante. En ese caso no
  /// toca nada: vaciar el carrito es una decision del cliente, y la pantalla
  /// es la que tiene que preguntarle.
  Future<bool> add(
    Product product, {
    required int restaurantId,
    required String restaurantName,
  }) async {
    if (!state.belongsTo(restaurantId)) {
      return false;
    }

    final List<CartItem> items = <CartItem>[...state.items];

    final int index = items.indexWhere(
      (CartItem item) => item.product.id == product.id,
    );

    if (index >= 0) {
      items[index] = items[index].withQuantity(items[index].quantity + 1);
    } else {
      items.add(CartItem(product: product, quantity: 1));
    }

    await _set(Cart(
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      items: items,
    ));

    return true;
  }

  /// Quita una unidad. Si era la ultima, saca la linea entera.
  Future<void> decrease(int productId) async {
    final List<CartItem> items = <CartItem>[];

    for (final CartItem item in state.items) {
      if (item.product.id != productId) {
        items.add(item);
        continue;
      }

      if (item.quantity > 1) {
        items.add(item.withQuantity(item.quantity - 1));
      }
    }

    await _set(_keepRestaurant(items));
  }

  /// Saca la linea entera, sin importar cuantas unidades tenga.
  Future<void> remove(int productId) async {
    final List<CartItem> items = state.items
        .where((CartItem item) => item.product.id != productId)
        .toList();

    await _set(_keepRestaurant(items));
  }

  /// Vacia el carrito. Se usa cuando el cliente agrega algo de otro
  /// restaurante y acepta empezar de nuevo.
  Future<void> clear() async {
    await _set(Cart.empty);
  }

  /// El carrito sin algunas lineas, pero conservando de que restaurante era.
  Cart _keepRestaurant(List<CartItem> items) {
    if (items.isEmpty) {
      return Cart.empty;
    }

    return Cart(
      restaurantId: state.restaurantId,
      restaurantName: state.restaurantName,
      items: items,
    );
  }

  /// Cambia el estado Y lo guarda.
  ///
  /// Todas las acciones pasan por aca para que no se pueda olvidar el guardado
  /// en una: si agregar guarda y quitar no, el carrito vuelve con lo que se
  /// habia sacado.
  Future<void> _set(Cart cart) async {
    state = cart;
    await _storage.save(cart);
  }
}
