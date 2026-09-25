import '../../../core/api_client.dart';
import '../../../models/order.dart';

/// La capa de datos de los pedidos, vista por el MOTORIZADO.
///
/// El backend saca la cuenta de la sesion, asi que aca nunca se manda un
/// courier_id: cada motorizado ve los disponibles y los suyos, y el pedido de
/// otro le responde 404.
class CourierOrderRepository {
  CourierOrderRepository(this._api);

  final ApiClient _api;

  /// GET /me — para saber como quedo el interruptor.
  ///
  /// La disponibilidad es un dato del USUARIO, no de un pedido, y por eso vive
  /// en el resource del usuario. Se pregunta al abrir en vez de guardarla en el
  /// telefono: el estado que importa es el del servidor.
  /// OJO CON LA FORMA DE LA RESPUESTA: `/me` devuelve el usuario DIRECTO, sin
  /// envolverlo en "user". El login y el PATCH de disponibilidad SI lo
  /// envuelven. Leerlo mal da "type 'Null' is not a subtype of type
  /// Map", porque `json['user']` no existe.
  Future<bool> loadAvailability() async {
    final Map<String, dynamic> json = await _api.get('/me');

    return json['is_available'] as bool;
  }

  /// PATCH /api/courier/availability
  ///
  /// "Disponible / No disponible". Devuelve el valor que quedo guardado, no el
  /// que creiamos.
  Future<bool> setAvailability({required bool isAvailable}) async {
    final Map<String, dynamic> json = await _api.patch(
      '/courier/availability',
      body: <String, dynamic>{'is_available': isAvailable},
    );

    return (json['user'] as Map<String, dynamic>)['is_available'] as bool;
  }

  /// GET /api/courier/orders/available
  ///
  /// Los que estan LISTOS para recoger y sin repartidor, a menos de 5 km del
  /// motorizado, del mas cercano al mas lejano. La distancia viene en
  /// `distance_km`.
  Future<List<Order>> loadAvailable({
    required double latitude,
    required double longitude,
  }) async {
    final Map<String, dynamic> json = await _api.get(
      '/courier/orders/available',
      query: <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
      },
    );

    final List<dynamic> raw = (json['orders'] as List<dynamic>?) ?? <dynamic>[];

    return raw.cast<Map<String, dynamic>>().map(Order.fromJson).toList();
  }

  /// GET /api/courier/orders
  ///
  /// Los que YO lleve, en curso. Es la pantalla de tracking activo.
  Future<List<Order>> loadMine() async {
    final Map<String, dynamic> json = await _api.get('/courier/orders');

    final List<dynamic> raw = (json['orders'] as List<dynamic>?) ?? <dynamic>[];

    return raw.cast<Map<String, dynamic>>().map(Order.fromJson).toList();
  }

  /// POST /api/courier/orders/{id}/take
  ///
  /// Toma el pedido. Si otro motorizado llego primero, el backend contesta 422
  /// con "Ese pedido ya no está disponible." y el ApiClient lo convierte en un
  /// mensaje que la pantalla muestra tal cual.
  Future<Order> take(int orderId) async {
    final Map<String, dynamic> json =
        await _api.post('/courier/orders/$orderId/take');

    return Order.fromJson(json['order'] as Map<String, dynamic>);
  }

  /// PATCH /api/courier/orders/{id}
  ///
  /// picked_up o delivered. Cualquier otro estado lo rechaza el backend: los
  /// del restaurante no le corresponden al motorizado.
  Future<Order> setStatus(int orderId, String status) async {
    final Map<String, dynamic> json = await _api.patch(
      '/courier/orders/$orderId',
      body: <String, dynamic>{'status': status},
    );

    return Order.fromJson(json['order'] as Map<String, dynamic>);
  }
}
