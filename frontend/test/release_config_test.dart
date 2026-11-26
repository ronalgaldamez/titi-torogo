import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../tool/check_release_config.dart';

String encodeDefines(Map<String, String> defines) => defines.entries
    .map((entry) => base64Encode(utf8.encode('${entry.key}=${entry.value}')))
    .join(',');

void main() {
  const production = {
    'API_BASE_URL': 'https://api.torogo.example/api',
    'REVERB_WS_URL': 'wss://ws.torogo.example',
    'REVERB_APP_KEY': 'public-key',
  };

  test('Acepta los valores de publicación codificados por Flutter', () {
    expect(
      () => checkReleaseConfig(encodeDefines(production)),
      returnsNormally,
    );
  });

  test('Indica los tres valores obligatorios cuando faltan', () {
    expect(
      () => checkReleaseConfig(''),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'mensaje',
          allOf(
            contains('API_BASE_URL'),
            contains('REVERB_WS_URL'),
            contains('REVERB_APP_KEY'),
          ),
        ),
      ),
    );
  });

  test('Rechaza URLs inseguras, locales y con rutas incompatibles', () {
    const invalid = [
      ('API_BASE_URL', 'http://api.torogo.example/api'),
      ('API_BASE_URL', 'https://localhost/api'),
      ('API_BASE_URL', 'https://127.0.0.2/api'),
      ('API_BASE_URL', 'https://api.torogo.example/api/'),
      ('REVERB_WS_URL', 'ws://ws.torogo.example'),
      ('REVERB_WS_URL', 'wss://[::1]'),
      ('REVERB_WS_URL', 'wss://ws.torogo.example/reverb'),
      ('REVERB_WS_URL', 'wss://ws.torogo.example:0'),
      ('REVERB_APP_KEY', '   '),
    ];
    for (final (key, value) in invalid) {
      expect(
        () => checkReleaseConfig(encodeDefines({...production, key: value})),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'mensaje',
            contains(key),
          ),
        ),
        reason: '$key=$value',
      );
    }
    expect(() => checkReleaseConfig('%'), throwsFormatException);
  });
}
