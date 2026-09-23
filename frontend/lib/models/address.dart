/// Una direccion guardada del cliente.
///
/// Espeja `backend/app/Http/Resources/AddressResource.php`. Si ese resource
/// cambia, este archivo cambia con el.
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.isDefault,
    this.reference,
  });

  final int id;

  /// "Casa", "Trabajo". Es para que el cliente la reconozca de un vistazo.
  final String label;

  final String address;

  /// "Frente a la farmacia". Opcional, pero es lo que hace que el motorizado
  /// llegue en Tejutla.
  final String? reference;

  final double latitude;
  final double longitude;

  /// La que el checkout elige sola.
  final bool isDefault;

  /// Como se muestra en una linea: "Casa · Mall del Sol...".
  String get summary => '$label · $address';

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as int,
      label: json['label'] as String,
      address: json['address'] as String,
      reference: json['reference'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      isDefault: json['is_default'] as bool,
    );
  }
}
