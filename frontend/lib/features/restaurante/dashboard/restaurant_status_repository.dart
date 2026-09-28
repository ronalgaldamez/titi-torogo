import '../../../core/api_client.dart';
import '../../../models/restaurant.dart';

/// La capa de datos del estado del local, vista por el RESTAURANTE.
///
/// El backend saca el restaurante de la sesion (ver EnsureRestaurantAccount),
/// asi que aca nunca se manda un id: cada cuenta puede tocar UNICAMENTE su
/// propio local, y el de otro no existe para nosotros.
class RestaurantStatusRepository {
  RestaurantStatusRepository(this._api);

  final ApiClient _api;

  /// GET /api/restaurant/status
  ///
  /// El estado de AHORA, que es el del servidor: el mismo que ve el cliente.
  /// Por eso se pregunta al abrir en vez de guardarlo en el telefono.
  Future<Restaurant> load() async {
    final Map<String, dynamic> json = await _api.get('/restaurant/status');

    return Restaurant.fromJson(json['restaurant'] as Map<String, dynamic>);
  }

  /// PATCH /api/restaurant/status
  ///
  /// Los DOS valores van siempre, aunque solo se cambie uno: el backend los
  /// exige juntos justamente para que no se pueda cambiar uno creyendo que se
  /// cambio el otro.
  ///
  /// Devuelve el restaurante COMO QUEDO, no como creiamos que iba a quedar.
  Future<Restaurant> save({
    required bool isOpen,
    required bool isBusy,
  }) async {
    final Map<String, dynamic> json = await _api.patch(
      '/restaurant/status',
      body: <String, dynamic>{
        'is_open': isOpen,
        'is_busy': isBusy,
      },
    );

    return Restaurant.fromJson(json['restaurant'] as Map<String, dynamic>);
  }
}
