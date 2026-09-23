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
}
