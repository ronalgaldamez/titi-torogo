import '../../../core/api_client.dart';
import '../../../models/order.dart';

/// Lo que devuelve la lista de pedidos del restaurante.
///
/// Trae los pedidos Y de que restaurante son. El id no es un adorno: es lo que
/// la app necesita para suscribirse al canal de tiempo real de su cocina
/// (`private-restaurants.{id}`).
///
/// Va en ESTA respuesta y no en /me por un caso concreto: un restaurante que
/// todavia no tiene ni un pedido tambien necesita el id, y es justamente el que
/// mas necesita que le avisen cuando entre el primero.
class RestaurantOrders {
  const RestaurantOrders({
    required this.restaurantId,
    required this.restaurantName,
    required this.orders,
  });

  final int restaurantId;
  final String restaurantName;

  final List<Order> orders;
}

/// La capa de datos de los pedidos, vista por el RESTAURANTE.
///
/// El backend saca el restaurante de la sesion, asi que aca nunca se manda un
/// restaurant_id: cada restaurante ve solo los suyos, y el pedido de otro le
/// responde 404.
class RestaurantOrderRepository {
  RestaurantOrderRepository(this._api);

  final ApiClient _api;

  /// GET /api/restaurant/orders
  ///
  /// Sin [status] devuelve los que estan EN CURSO, del mas nuevo al mas viejo:
  /// el ultimo es el que acaba de sonar.
  ///
  /// Con `status: 'delivered'` se pide el historial.
  Future<RestaurantOrders> load({String? status}) async {
    final Map<String, dynamic> json = await _api.get(
      '/restaurant/orders',
      query: status == null ? null : <String, dynamic>{'status': status},
    );

    final List<dynamic> raw = (json['orders'] as List<dynamic>?) ?? <dynamic>[];
    final Map<String, dynamic> restaurant =
        (json['restaurant'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return RestaurantOrders(
      restaurantId: restaurant['id'] as int? ?? 0,
      restaurantName: restaurant['name'] as String? ?? '',
      orders: raw.cast<Map<String, dynamic>>().map(Order.fromJson).toList(),
    );
  }

  /// PATCH /api/restaurant/orders/{id}
  ///
  /// Mueve el pedido: aceptar, rechazar, preparando, listo para recoger.
  ///
  /// Devuelve el pedido COMO QUEDO en el backend, no como creiamos que iba a
  /// quedar. Y si la transicion no era legal, el backend contesta 422 y el
  /// ApiClient lo convierte en un mensaje que la pantalla muestra tal cual.
  Future<Order> setStatus(int orderId, String status) async {
    final Map<String, dynamic> json = await _api.patch(
      '/restaurant/orders/$orderId',
      body: <String, dynamic>{'status': status},
    );

    return Order.fromJson(json['order'] as Map<String, dynamic>);
  }
}
