import 'package:shared_preferences/shared_preferences.dart';

/// Guarda el token de sesion en el telefono, para no pedir la contrasena
/// cada vez que el usuario abre la app.
///
/// NOTA DE SEGURIDAD IMPORTANTE
/// ----------------------------
/// `shared_preferences` guarda en TEXTO PLANO. Para el MVP alcanza, pero
/// ANTES de publicar en las tiendas hay que pasar a `flutter_secure_storage`,
/// que en Android usa el Keystore del sistema y en iOS el Keychain.
///
/// Esta clase existe justamente para eso: el dia del cambio se toca UN
/// archivo y ninguna pantalla se entera.
class AuthStorage {
  static const String _tokenKey = 'torogo_token';

  Future<void> saveToken(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> readToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Cierra la sesion en este dispositivo.
  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
