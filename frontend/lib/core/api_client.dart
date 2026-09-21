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
  ApiClient({http.Client? client, this.authToken})
      : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  /// Token de Sanctum. Si viene, se manda en cada peticion en el header
  /// `Authorization`, con el formato `Bearer TU_TOKEN`. Es lo que identifica
  /// al usuario ante el backend.
  final String? authToken;

  final http.Client _client;

  /// GET que devuelve el JSON ya decodificado.
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, '$value')),
    );

    return _decode(await _send(
      () => _client.get(uri, headers: _jsonHeaders()),
    ));
  }

  /// POST con cuerpo JSON. Lo usa el login.
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _sendJson('POST', path, body);
  }

  /// PUT con cuerpo JSON. Reemplaza el recurso completo: editar un plato.
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _sendJson('PUT', path, body);
  }

  /// PATCH con cuerpo JSON. Cambia UN campo: el toggle de agotado.
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _sendJson('PATCH', path, body);
  }

  /// DELETE. El backend responde con un mensaje ("Plato eliminado del menu."),
  /// asi que igual devuelve un JSON y la pantalla puede mostrar ese texto.
  Future<Map<String, dynamic>> delete(String path) {
    return _sendJson('DELETE', path, null);
  }

  /// El cuerpo comun de las peticiones que MANDAN datos (POST, PUT, PATCH,
  /// DELETE).
  ///
  /// Existe para no repetir cuatro veces lo mismo: armar la URL, poner los
  /// headers y codificar el cuerpo. `http.Client` no tiene un metodo generico
  /// que acepte cualquier verbo, asi que se arma un `http.Request` a mano.
  Future<Map<String, dynamic>> _sendJson(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    final http.Request request =
        http.Request(method, Uri.parse('$baseUrl$path'))
          ..headers.addAll(_jsonHeaders(contentType: true))
          // Siempre "{}" y nunca vacio: mandar el Content-Type sin cuerpo hace
          // que algunos servidores y proxies se comporten raro.
          ..body = jsonEncode(body ?? <String, dynamic>{});

    return _decode(await _send(() async {
      final http.StreamedResponse streamed = await _client.send(request);
      return http.Response.fromStream(streamed);
    }));
  }

  Map<String, String> _jsonHeaders({bool contentType = false}) {
    return <String, String>{
      'Accept': 'application/json',
      if (contentType) 'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    };
  }

  /// Hace la peticion y convierte cualquier fallo de red en un [ApiException]
  /// con un mensaje entendible, para que la pantalla no tenga que adivinar
  /// que paso.
  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } catch (_) {
      throw ApiException(
        'No pudimos conectarnos con ToroGo. Revisa tu conexion a internet.',
      );
    }
  }

  /// Convierte la respuesta en JSON, o lanza [ApiException] con el mensaje
  /// que mando Laravel.
  Map<String, dynamic> _decode(http.Response response) {
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
