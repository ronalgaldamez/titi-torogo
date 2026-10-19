import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/cliente/pedido/order_tracking_screen.dart';

Map<String, dynamic> order(String status) => {
  'id': 35,
  'status': status,
  'status_label': switch (status) {
    'cancelled' => 'Cancelado',
    'accepted' => 'Aceptado',
    _ => 'Pendiente',
  },
  'is_active': status != 'cancelled',
  'restaurant': {
    'id': 1,
    'name': 'Local',
    'address': 'Centro',
    'latitude': 14.1,
    'longitude': -89.1,
  },
  'items': [],
  'subtotal': '1.00',
  'delivery_fee': '2.00',
  'courier_fee': '1.50',
  'platform_fee': '0.50',
  'total': '3.00',
  'payment_method': 'cash',
  'accepted_at': status == 'accepted' ? '2026-10-18T12:00:00Z' : null,
  'cancellation_reason': status == 'cancelled'
      ? 'El cliente canceló el pedido.'
      : null,
};

void main() {
  for (final outcome in ['success', 'accepted', 'network', 'lost_response']) {
    testWidgets(
      'Cancelación confirmada maneja $outcome sin duplicar solicitudes',
      (tester) async {
        SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
        var status = 'pending';
        var requests = 0;
        final client = MockClient((request) async {
          if (request.method == 'POST') {
            expect(request.url.path, '/api/orders/35/cancel');
            requests++;
            if (outcome == 'network') {
              throw http.ClientException('Sin conexión');
            }
            if (outcome == 'lost_response') {
              status = 'cancelled';
              throw http.ClientException(
                'Respuesta perdida después de cancelar',
              );
            }
            status = outcome == 'accepted' ? 'accepted' : 'cancelled';
            if (outcome == 'accepted') {
              return http.Response(
                jsonEncode({
                  'message':
                      'Solo podés cancelar antes de que el restaurante acepte el pedido.',
                  'order': order(status),
                }),
                409,
              );
            }
          }
          return http.Response(jsonEncode({'order': order(status)}), 200);
        });
        addTearDown(client.close);
        await http.runWithClient(() async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light(),
              home: const OrderTrackingScreen(orderId: 35),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cancelar pedido'));
          await tester.pumpAndSettle();
          expect(requests, 0);
          expect(find.text('¿Cancelar el pedido #35?'), findsOneWidget);
          await tester.tap(find.text('Seguir esperando'));
          await tester.pumpAndSettle();
          expect(requests, 0);
          expect(find.text('Cancelar pedido'), findsOneWidget);
          await tester.tap(find.text('Cancelar pedido'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Sí, cancelar'));
          await tester.pumpAndSettle();
          expect(requests, 1);
          if (outcome == 'success' || outcome == 'lost_response') {
            expect(find.text('Cancelado'), findsOneWidget);
            expect(find.text('El cliente canceló el pedido.'), findsOneWidget);
            expect(find.textContaining('No tenés que pagar'), findsOneWidget);
            expect(find.text('Cancelar pedido'), findsNothing);
            expect(find.text(r'$3.00'), findsOneWidget);
          } else if (outcome == 'accepted') {
            expect(find.text('Aceptado'), findsOneWidget);
            expect(find.text('Cancelar pedido'), findsNothing);
            expect(
              find.textContaining('Ya no podés cancelarlo'),
              findsOneWidget,
            );
          } else {
            expect(find.text('Cancelar pedido'), findsOneWidget);
            expect(
              find.textContaining('No pudimos confirmar la cancelación.'),
              findsOneWidget,
            );
            expect(find.text('Cancelado'), findsNothing);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }, () => client);
      },
    );
  }
}
