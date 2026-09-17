import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../models/user.dart';

/// Lo que devuelve un login exitoso.
class AuthResult {
  const AuthResult({required this.user});

  final User user;
}

/// La capa de datos de la autenticacion.
class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final AuthStorage _storage;

  /// POST /api/login
  ///
  /// Si las credenciales estan mal, Laravel responde 422 y el ApiClient ya
  /// convierte eso en un ApiException con el mensaje en espanol que
  /// configuramos en el backend ("Las credenciales no coinciden.").
  /// La pantalla solo tiene que mostrar ese texto tal cual.
  Future<AuthResult> login({
    required String email,
    required String password,
    String deviceName = 'app-movil',
  }) async {
    final Map<String, dynamic> json = await _api.post(
      '/login',
      body: <String, dynamic>{
        'email': email,
        'password': password,
        'device_name': deviceName,
      },
    );

    // El token se guarda ANTES de devolver el resultado: si la app se cierra
    // justo despues del login, la sesion ya quedo guardada.
    await _storage.saveToken(json['token'] as String);

    return AuthResult(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  /// Cierra la sesion.
  ///
  /// Primero le pide al backend que REVOQUE el token — asi no queda vivo
  /// 7 dias en la base de datos — y despues borra la copia local.
  ///
  /// Si el backend no responde, igual se borra lo local: el usuario quiere
  /// salir, no quedarse esperando. El token vencido no le sirve a nadie
  /// que tenga el telefono en la mano, porque ya no esta guardado.
  Future<void> logout() async {
    final String? token = await _storage.readToken();

    if (token != null && token.isNotEmpty) {
      try {
        await ApiClient(authToken: token).post('/logout');
      } catch (_) {
        // Sin internet no pasa nada: igual cerramos la sesion local.
      }
    }

    await _storage.clear();
  }
}
