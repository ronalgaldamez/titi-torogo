import '../../../core/api_client.dart';
import '../../../models/address.dart';

/// La capa de datos de las direcciones del cliente.
///
/// El backend saca el usuario de la sesion, asi que aca nunca se manda un
/// user_id: cada uno ve solo las suyas.
class AddressRepository {
  AddressRepository(this._api);

  final ApiClient _api;

  /// GET /api/addresses
  ///
  /// La predeterminada llega PRIMERO (lo ordena el backend), asi que la
  /// pantalla puede elegir la primera sin recorrer nada.
  Future<List<Address>> load() async {
    final Map<String, dynamic> json = await _api.get('/addresses');

    final List<dynamic> raw =
        (json['addresses'] as List<dynamic>?) ?? <dynamic>[];

    return raw.cast<Map<String, dynamic>>().map(Address.fromJson).toList();
  }

  /// POST /api/addresses
  ///
  /// El backend decide si es la predeterminada: la PRIMERA siempre lo es, aunque
  /// no se pida.
  Future<Address> create({
    required String label,
    required String address,
    required double latitude,
    required double longitude,
    String? reference,
    bool isDefault = false,
  }) async {
    final Map<String, dynamic> json = await _api.post(
      '/addresses',
      body: <String, dynamic>{
        'label': label,
        'address': address,
        'reference': reference,
        'latitude': latitude,
        'longitude': longitude,
        'is_default': isDefault,
      },
    );

    return Address.fromJson(json['address'] as Map<String, dynamic>);
  }

  /// PUT /api/addresses/{id}
  ///
  /// El backend espera la direccion COMPLETA (es un PUT).
  ///
  /// OJO con 'is_default': se manda SOLO cuando se quiere marcar. Si mandaramos
  /// `false` siempre, desmarcariamos la predeterminada al editar cualquier otra
  /// cosa, y el cliente quedaria sin ninguna marcada.
  Future<Address> update({
    required int id,
    required String label,
    required String address,
    required double latitude,
    required double longitude,
    String? reference,
    bool isDefault = false,
  }) async {
    final Map<String, dynamic> json = await _api.put(
      '/addresses/$id',
      body: <String, dynamic>{
        'label': label,
        'address': address,
        'reference': reference,
        'latitude': latitude,
        'longitude': longitude,
        if (isDefault) 'is_default': true,
      },
    );

    return Address.fromJson(json['address'] as Map<String, dynamic>);
  }

  /// DELETE /api/addresses/{id}
  ///
  /// Borrado suave. Si era la predeterminada, el backend promueve otra sola.
  /// Los pedidos viejos no se enteran: guardan su propia copia de la direccion.
  Future<void> delete(int id) async {
    await _api.delete('/addresses/$id');
  }
}
