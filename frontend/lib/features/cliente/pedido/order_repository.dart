import 'dart:math';

import '../../../core/api_client.dart';
import '../carrito/cart.dart';

/// La capa de datos de los pedidos del cliente.
class OrderRepository {
  OrderRepository(this._api);

  final ApiClient _api;

  /// POST /api/orders
  ///
  /// Del carrito solo se manda QUE plato y CUANTAS unidades. Los precios y el
  /// total los calcula el backend leyendo su catalogo: si los mandaramos
  /// nosotros, cualquiera podria pedir una pupusa a un centavo.
  ///
  /// [idempotencyKey] es LA CLAVE CONTRA EL DOBLE COBRO. Se genera UNA vez,
  /// cuando el cliente entra al checkout, y se repite TAL CUAL si hay que
  /// reintentar: el backend reconoce la clave y devuelve el mismo pedido en
  /// vez de crear otro.
  ///
  /// Generar una clave nueva en un reintento es justo lo que crearia el
  /// segundo pedido.
  ///
  /// Devuelve el id del pedido, sea nuevo o repetido.
  Future<int> create({
    required String idempotencyKey,
    required Cart cart,
    required int addressId,
    String? notes,
  }) async {
    final Map<String, dynamic> json = await _api.post(
      '/orders',
      body: <String, dynamic>{
        'restaurant_id': cart.restaurantId,

        // A donde se entrega. El backend COPIA esta direccion dentro del
        // pedido: si el cliente la edita despues, el pedido no cambia.
        'address_id': addressId,

        'idempotency_key': idempotencyKey,
        'notes': notes,

        'items': cart.items
            .map((CartItem item) => <String, dynamic>{
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                })
            .toList(),
      },
    );

    return (json['order'] as Map<String, dynamic>)['id'] as int;
  }

  /// Una clave nueva, para un checkout nuevo.
  ///
  /// Junta la marca del tiempo en microsegundos con un numero al azar: dos
  /// toques en el mismo microsegundo no van a sacar el mismo azar.
  ///
  /// OJO CON EL NUMERO DE ARRIBA: `Random().nextInt(n)` no acepta cualquier n.
  ///
  /// Lo natural seria escribir `1 << 32` para pedir "un entero de 32 bits al
  /// azar", pero EN LA WEB ESO NO FUNCIONA: los enteros de Dart son numeros de
  /// JavaScript, y las operaciones de bits ahi son de 32 bits. `1 << 32` no da
  /// 4294967296, da 0 — y `nextInt(0)` lanza un RangeError que revienta la
  /// pantalla al abrir el checkout.
  ///
  /// En el celular (Android/iOS) no pasaba: ahi los enteros son de verdad.
  /// Un bug que solo aparece en una de las plataformas.
  ///
  /// Con mil millones al azar alcanza y sobra para que dos checkouts no
  /// choquen: la clave tambien lleva la marca del tiempo en microsegundos.
  static String newIdempotencyKey() {
    final int stamp = DateTime.now().microsecondsSinceEpoch;
    final int random = Random().nextInt(1000000000);

    return 'app-$stamp-$random';
  }
}
