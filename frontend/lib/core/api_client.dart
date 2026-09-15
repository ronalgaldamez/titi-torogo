import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente HTTP de ToroGo.
///
/// La direccion de la API NO esta escrita en el codigo: se pasa al compilar.
///
///   Edge (web)        flutter run -d edge
///                     -> usa http://localhost:8080/api por defecto
///
///   Emulador Android  flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
///                     -> 10.0.2.2 es como el emulador ve a tu PC
///
///   Celular fisico    flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080/api
///                     -> la IP de tu PC en la red wifi
///
/// Asi el mismo codigo sirve en los tres casos, sin comentar y descomentar.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  final http.Client _client;

  /// GET que devuelve el JSON ya decodificado.
  ///
  /// Si algo sale mal lanza [ApiException] con un mensaje que se le puede
  /// mostrar al usuario tal cual, para que la pantalla no tenga que adivinar
  /// que paso ni traducir codigos HTTP.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );

    final http.Response response = await _get(uri);

    // El cuerpo puede no ser JSON (un error del servidor, un proxy, etc.).
    // Se parsea con cuidado para no reventar con una excepcion rara.
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 400) {
      throw ApiException(
        _messageFrom(decoded) ?? 'Ocurrio un error (${response.statusCode}).',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException('La API devolvio un formato que no esperabamos.');
    }

    return decoded;
  }

  /// Hace la peticion y convierte cualquier fallo de red en un [ApiException]
  /// con un mensaje entendible.
  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client.get(
        uri,
        headers: const <String, String>{'Accept': 'application/json'},
      );
    } catch (_) {
      throw ApiException(
        'No pudimos conectarnos con ToroGo. Revisa tu conexion a internet.',
      );
    }
  }

  /// Saca el mensaje de error que manda Laravel.
  String? _messageFrom(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }

    // Errores de validacion: vienen dentro de "errors".
    final dynamic errors = decoded['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final dynamic first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        return '${first.first}';
      }
    }

    final dynamic message = decoded['message'];
    if (message is String) {
      return message;
    }

    return null;
  }
}

/// Error con el mensaje ya listo para mostrar en pantalla.
class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
