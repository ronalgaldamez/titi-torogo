import '../../../core/api_client.dart';
import '../../../models/delivery_zone.dart';
import '../../../models/restaurant.dart';

/// Todo lo que necesita la pantalla del Home de una sola vez.
class HomeData {
  const HomeData({required this.zone, required this.restaurants});

  /// null = el cliente esta fuera de toda zona de reparto.
  final DeliveryZone? zone;

  final List<Restaurant> restaurants;

  bool get isOutsideCoverage => zone == null;
}

/// La capa de datos del Home.
///
/// La pantalla no sabe que existe HTTP: solo pide [load] y recibe objetos.
/// El dia que cambiemos de endpoint, o agreguemos cache, se toca solo aqui.
class HomeRepository {
  HomeRepository(this._api);

  final ApiClient _api;

  Future<HomeData> load({
    required double latitude,
    required double longitude,
  }) async {
    final Map<String, dynamic> json = await _api.get(
      '/restaurants',
      query: {'latitude': latitude, 'longitude': longitude},
    );

    final dynamic zoneJson = json['zone'];

    final List<dynamic> rawList =
        (json['restaurants'] as List<dynamic>?) ?? <dynamic>[];

    return HomeData(
      zone: zoneJson == null
          ? null
          : DeliveryZone.fromJson(zoneJson as Map<String, dynamic>),
      restaurants: rawList
          .cast<Map<String, dynamic>>()
          .map(Restaurant.fromJson)
          .toList(),
    );
  }
}
