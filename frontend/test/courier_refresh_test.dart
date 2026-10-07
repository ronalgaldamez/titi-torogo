import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/features/motorizado/courier_screen.dart';

void main() {
  testWidgets('Una respuesta vieja no restaura un pedido ya reasignado', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'torogo_token': 'test-token'});
    // Mantiene pendiente el GPS inicial: la prueba usa el botón Actualizar,
    // sin depender de ubicación, mapas ni conexiones reales de Reverb.
    final gps = Completer<bool>();
    const channel = MethodChannel('flutter.baseflow.com/geolocator');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) => gps.future);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    final oldResponse = Completer<http.Response>();
    int loads = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/me')) {
        return http.Response('{"is_available":false}', 200);
      }
      if (request.url.path.endsWith('/courier/orders')) {
        loads++;
        return loads == 1 ? oldResponse.future : http.Response('{"orders":[]}', 200);
      }
      fail('Petición inesperada: ${request.url}');
    });
    addTearDown(client.close);

    Future<void> flush() async {
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
    }

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: CourierScreen(onLogout: null)));
      await tester.tap(find.byTooltip('Actualizar'));
      await flush();
      expect(loads, 1);
      await tester.tap(find.byTooltip('Actualizar'));
      await flush();
      expect(loads, 2);
      expect(find.text('MI PEDIDO'), findsNothing);

      oldResponse.complete(http.Response(jsonEncode(<String, dynamic>{
        'orders': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 16, 'status': 'picked_up', 'status_label': 'En camino', 'is_active': true,
            'restaurant': <String, dynamic>{
              'id': 7, 'name': 'Restaurante', 'address': 'Centro',
              'latitude': 14.1, 'longitude': -89.1,
            },
            'delivery': <String, dynamic>{'address': 'Casa', 'latitude': 14.2, 'longitude': -89.2},
            'items': <dynamic>[], 'subtotal': '4.00', 'delivery_fee': '2.00',
            'courier_fee': '1.50', 'platform_fee': '0.50', 'total': '6.00',
            'payment_method': 'cash',
          },
        ],
      }), 200));
      await flush();
      expect(find.text('#16'), findsNothing);
      expect(find.text('MI PEDIDO'), findsNothing);
      expect(find.text('Entregado'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
