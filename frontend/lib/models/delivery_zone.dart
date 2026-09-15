/// La zona de reparto donde cae el cliente.
///
/// El backend la calcula con el poligono dibujado en Google My Maps: si el
/// cliente esta fuera de toda zona, el Home devuelve `zone: null`.
///
/// Los montos llegan como TEXTO desde la API ("1.50"), no como double. Es a
/// proposito: el dinero no se maneja con decimales binarios o aparecen
/// centavos fantasma al sumar el carrito. Aqui se guardan igual, como String.
class DeliveryZone {
  const DeliveryZone({
    required this.id,
    required this.name,
    required this.deliveryFee,
    required this.courierFee,
    required this.platformFee,
  });

  final int id;
  final String name;

  /// Lo que paga el cliente: courierFee + platformFee.
  final String deliveryFee;

  /// Va completo al motorizado.
  final String courierFee;

  /// Es el ingreso de ToroGo.
  final String platformFee;

  factory DeliveryZone.fromJson(Map<String, dynamic> json) {
    return DeliveryZone(
      id: json['id'] as int,
      name: json['name'] as String,
      deliveryFee: '${json['delivery_fee']}',
      courierFee: '${json['courier_fee']}',
      platformFee: '${json['platform_fee']}',
    );
  }
}
