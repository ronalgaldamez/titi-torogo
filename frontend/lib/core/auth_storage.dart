import 'package:shared_preferences/shared_preferences.dart';

/// Guarda la sesion en el telefono, para no pedir la contrasena cada vez que
/// el usuario abre la app.
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
  static const String _roleKey = 'torogo_role';

  /// Guarda el token y el perfil JUNTOS.
  ///
  /// El perfil se guarda al lado del token porque al abrir la app hay que
  /// decidir a que pantalla entrar (el catalogo del cliente o el menu del
  /// restaurante) sin esperar a que conteste la API. Asi abrir la app con
  /// sesion guardada es instantaneo y no gasta datos.
  ///
  /// OJO: esto es COMODIDAD, no seguridad. Si el perfil guardado quedara
  /// viejo, el backend igual rechaza lo que no corresponda: cada endpoint
  /// del restaurante verifica el perfil contra la base, no contra lo que
  /// diga el telefono.
  Future<void> saveSession({
    required String token,
    required String role,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_roleKey, role);
  }

  Future<String?> readToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> readRole() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  /// Cierra la sesion en este dispositivo: borra las DOS claves.
  ///
  /// Si quedara el perfil sin el token, la proxima apertura entraria a una
  /// pantalla sin sesion y todo fallaria con 401.
  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
  }
}
