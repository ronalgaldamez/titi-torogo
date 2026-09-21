import 'api_client.dart';
import 'auth_storage.dart';

/// Fabrica de clientes autenticados.
///
/// Cada pantalla que habla con la API necesita lo mismo: leer el token,
/// revisar que exista y armar el `ApiClient`. Repetir esos tres pasos en
/// cada pantalla es la clase de detalle que se olvida en una y ahi esa
/// pantalla deja de funcionar sin que nadie sepa por que.
///
/// Ademas hay UN solo lugar donde se decide si el token vence: aca.
class Session {
  Session(this._storage);

  final AuthStorage _storage;

  /// Devuelve un `ApiClient` con el token de la sesion ya puesto.
  ///
  /// Si no hay token guardado, lanza [ApiException] con un mensaje que la
  /// pantalla puede mostrar tal cual, sin traducir nada.
  Future<ApiClient> client() async {
    final String? token = await _storage.readToken();

    if (token == null || token.isEmpty) {
      throw ApiException('Tu sesión venció. Volvé a entrar.');
    }

    return ApiClient(authToken: token);
  }
}
