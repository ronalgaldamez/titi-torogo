import '../../../core/api_client.dart';
import '../../../models/menu_category.dart';
import '../../../models/restaurant.dart';

/// Lo que devuelve `GET /api/restaurants/{id}`.
class RestaurantDetail {
  const RestaurantDetail({required this.restaurant, required this.categories});

  final Restaurant restaurant;

  /// El menu del CLIENTE: solo los platos disponibles, y solo las categorias
  /// que tienen alguno.
  ///
  /// Ese filtro lo hace el backend (RestaurantController::show), no la
  /// pantalla: la app no tiene por que saber que existe lo agotado.
  final List<MenuCategory> categories;

  bool get hasMenu => categories.isNotEmpty;
}

/// La capa de datos de la carta de un restaurante.
class RestaurantDetailRepository {
  RestaurantDetailRepository(this._api);

  final ApiClient _api;

  /// GET /api/restaurants/{id}?latitude=..&longitude=..
  ///
  /// La ubicacion es OPCIONAL. Con ella, el backend resuelve la distancia y la
  /// tarifa de envio; sin ella, esos dos datos llegan en null.
  Future<RestaurantDetail> load(
    int restaurantId, {
    double? latitude,
    double? longitude,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{};

    if (latitude != null && longitude != null) {
      query['latitude'] = latitude;
      query['longitude'] = longitude;
    }

    final Map<String, dynamic> json = await _api.get(
      '/restaurants/$restaurantId',
      query: query.isEmpty ? null : query,
    );

    final List<dynamic> raw =
        (json['categories'] as List<dynamic>?) ?? <dynamic>[];

    return RestaurantDetail(
      restaurant:
          Restaurant.fromJson(json['restaurant'] as Map<String, dynamic>),
      categories:
          raw.cast<Map<String, dynamic>>().map(MenuCategory.fromJson).toList(),
    );
  }
}
