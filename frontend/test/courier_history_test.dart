import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/motorizado/pedidos/courier_history_screen.dart';

void main() {
  testWidgets(
    'Historial muestra comisión, detalle, filtros y error recuperable',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'torogo_token': 'test',
      });
      bool fail = false;
      final client = MockClient((request) async {
        expect(request.url.path.endsWith('/courier/history'), isTrue);
        if (fail) {
          return http.Response('{"message":"Sin conexión"}', 503);
        }
        final String status = request.url.queryParameters['status']!;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'from': '2026-10-07',
            'to': '2026-10-07',
            'next_page': null,
            'summary': <String, dynamic>{'deliveries': 1, 'earnings': '2.50'},
            'orders': status == 'cancelled'
                ? <dynamic>[]
                : <dynamic>[
                    <String, dynamic>{
                      'id': 23,
                      'status': 'delivered',
                      'status_label': 'Entregado',
                      'is_active': false,
                      'restaurant': <String, dynamic>{
                        'id': 7,
                        'name': 'Restaurante',
                        'address': 'Centro',
                        'latitude': 14.1,
                        'longitude': -89.1,
                      },
                      'delivery': <String, dynamic>{
                        'address': 'Casa',
                        'latitude': 14.2,
                        'longitude': -89.2,
                      },
                      'items': <dynamic>[],
                      'subtotal': '4.00',
                      'delivery_fee': '2.00',
                      'courier_fee': '1.50',
                      'platform_fee': '0.50',
                      'total': '7.00',
                      'tip_amount': '1.00',
                      'payment_method': 'cash',
                      'created_at': '2026-10-07T11:00:00-06:00',
                      'delivered_at': '2026-10-07T12:00:00-06:00',
                    },
                  ],
          }),
          200,
        );
      });
      addTearDown(client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: const CourierHistoryScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(r'$2.50').first, findsOneWidget);
        await tester.tap(find.text('Restaurante'));
        await tester.pumpAndSettle();
        expect(find.text('Tu ganancia'), findsOneWidget);
        expect(find.text(r'Entrega: $1.50 · Propina: $1.00'), findsOneWidget);
        expect(find.text(r'$2.50'), findsOneWidget);
        expect(find.text(r'Total cobrado al cliente: $7.00'), findsOneWidget);
        await tester.ensureVisible(find.text('Recorrido del pedido'));
        await tester.pumpAndSettle();
        expect(find.text('Pedido creado'), findsOneWidget);
        expect(find.text('Aceptado por el restaurante'), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelados'));
        await tester.pumpAndSettle();
        expect(
          find.text('No tenés pedidos cancelados en este período.'),
          findsOneWidget,
        );
        expect(find.text(r'$2.50').first, findsOneWidget);
        fail = true;
        await tester.tap(find.text('Todos'));
        await tester.pumpAndSettle();
        expect(find.text('Sin conexión'), findsOneWidget);
        fail = false;
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(find.text('Restaurante'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );
}
