import 'dart:convert';
import 'dart:io';

void main() {
  try {
    checkReleaseConfig(Platform.environment['DART_DEFINES'] ?? '');
  } on FormatException catch (error) {
    stderr.writeln('Configuración de publicación de ToroGo\n${error.message}');
    exitCode = 1;
  }
}

void checkReleaseConfig(String encodedDefines) {
  final defines = <String, String>{};
  if (encodedDefines.isNotEmpty) {
    try {
      for (final encoded in encodedDefines.split(',')) {
        final entry = utf8.decode(base64Decode(encoded));
        final separator = entry.indexOf('=');
        if (separator <= 0) throw const FormatException();
        defines[entry.substring(0, separator)] = entry.substring(separator + 1);
      }
    } on FormatException {
      throw const FormatException(
        'Flutter recibió opciones --dart-define inválidas.',
      );
    }
  }

  final api = _remoteEndpoint(defines['API_BASE_URL'], 'https');
  final reverb = _remoteEndpoint(defines['REVERB_WS_URL'], 'wss');
  final reverbKey = defines['REVERB_APP_KEY'];
  final errors = [
    if (api == null || !api.path.endsWith('/api'))
      'API_BASE_URL debe indicar la URL HTTPS de producción, terminada en /api.',
    if (reverb == null || (reverb.path.isNotEmpty && reverb.path != '/'))
      'REVERB_WS_URL debe indicar el origen WSS de producción, sin ruta.',
    if (reverbKey == null ||
        reverbKey.isEmpty ||
        reverbKey.contains(RegExp(r'\s')))
      'REVERB_APP_KEY debe contener la clave pública de Reverb de producción.',
  ];
  if (errors.isNotEmpty) throw FormatException(errors.join('\n'));
}

Uri? _remoteEndpoint(String? value, String scheme) {
  if (value == null || value.contains(RegExp(r'\s'))) return null;

  final separator = value.indexOf('://');
  if (separator < 0 || value.substring(0, separator).toLowerCase() != scheme) {
    return null;
  }

  // HTTPS y WSS usan 443. Así Uri conserva un puerto cero explícito como inválido.
  final uri = Uri.tryParse('https${value.substring(separator)}');
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.port <= 0 ||
      uri.port > 65535) {
    return null;
  }

  final host = uri.host.replaceFirst(RegExp(r'\.$'), '');
  final address = InternetAddress.tryParse(host);
  if (host.isEmpty ||
      host == 'localhost' ||
      host.endsWith('.localhost') ||
      host == '10.0.2.2' ||
      host == '0.0.0.0' ||
      host == '::' ||
      address?.isLoopback == true) {
    return null;
  }
  return uri;
}
