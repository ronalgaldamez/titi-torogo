/// Un restaurante tal como lo devuelve `GET /api/restaurants`.
///
/// Se escriben los `fromJson` a mano en vez de usar generadores de codigo:
/// con 3 modelos no vale la pena meter `build_runner` y una compilacion
/// extra en cada cambio. Cuando los modelos sean 20, lo reevaluamos.
class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.isOpen,
    required this.isBusy,
    required this.estimatedDeliveryMinutes,
    required this.deliveryFee,
    this.description,
    this.phone,
    this.logoUrl,
    this.distanceKm,
  });

  final int id;
  final String name;
  final String? description;
  final String address;
  final String? phone;

  /// Logo en MinIO. Llega null mientras el restaurante no suba uno.
  final String? logoUrl;

  final double latitude;
  final double longitude;

  final bool isOpen;
  final bool isBusy;

  /// Tiempo estimado, ya con el modo "muy ocupado" aplicado por el backend.
  final int estimatedDeliveryMinutes;

  /// Tarifa final del envio, ya resuelta: la promocion del restaurante si
  /// tiene una, o la de la zona si no. Como String, por lo del dinero.
  final String deliveryFee;

  /// Distancia desde donde esta el cliente, en kilometros.
  final double? distanceKm;

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      address: json['address'] as String,
      phone: json['phone'] as String?,
      logoUrl: json['logo_url'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isOpen: json['is_open'] as bool,
      isBusy: json['is_busy'] as bool,
      estimatedDeliveryMinutes: json['estimated_delivery_minutes'] as int,
      deliveryFee: '${json['delivery_fee']}',
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}
