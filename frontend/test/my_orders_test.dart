import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/cliente/pedido/my_orders_screen.dart';

Map<String, dynamic> order(int id, String status, String label) => {
  'id': id,
  'status': status,
  'status_label': label,
  'is_active': status == 'preparing',
  'restaurant': {
    'id': 1,
    'name': 'Los Tres Cerditos con nombre largo',
    'address': 'Centro',
    'latitude': 14.1,
    'longitude': -89.1,
  },
  'items': [
    {
      'id': 1,
      'name': 'Pupusa',
      'unit_price': '1.00',
      'quantity': 3,
      'subtotal': '3.00',
    },
  ],
  'subtotal': '3.00',
  'delivery_fee': '2.00',
  'courier_fee': '1.50',
  'platform_fee': '0.50',
  'total': '5.00',
  'payment_method': 'cash',
  'created_at': '2026-10-09T13:45:00',
};

void main() {
  testWidgets('Mis pedidos filtra sin recargar y conserva estados y montos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
    int requests = 0;
    bool fail = false;
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test');
      requests++;
      if (fail) {
        return http.Response('{"message":"Sin conexión"}', 503);
      }
      final history = request.url.queryParameters['scope'] == 'history';
      return http.Response(
        jsonEncode({
          'orders': history
              ? [
                  order(2, 'delivered', 'Entregado'),
                  order(3, 'cancelled', 'Cancelado'),
                  order(4, 'rejected', 'Rechazado'),
                ]
              : [order(1, 'preparing', 'En preparación')],
        }),
        200,
      );
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const MyOrdersScreen(),
        ),
      );
      await tester.pumpAndSettle();
      for (var index = 0; index < 4; index++) {
        final control = find.byKey(ValueKey('order-filter-$index'));
        expect(control.hitTestable(), findsOneWidget);
        expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
      }
      expect(find.text('En preparación'), findsOneWidget);
      expect(find.text(r'$5.00'), findsWidgets);
      expect(find.text('3 productos'), findsWidgets);
      Future<void> filter(String label) async {
        final index = [
          'Todos',
          'En curso',
          'Completados',
          'Cancelados',
        ].indexOf(label);
        final chip = find.byKey(ValueKey('order-filter-$index'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }

      await filter('Completados');
      expect(find.text('Entregado'), findsOneWidget);
      expect(find.text('En preparación'), findsNothing);
      expect(find.text('Cancelado'), findsNothing);
      expect(find.text('09/10/2026 · 1:45 PM'), findsOneWidget);
      await filter('Cancelados');
      expect(find.text('Cancelado'), findsOneWidget);
      expect(find.text('Rechazado'), findsOneWidget);
      expect(find.text('Entregado'), findsNothing);
      await filter('En curso');
      expect(find.text('Ver seguimiento'), findsOneWidget);
      expect(find.text('Ver detalles'), findsNothing);
      expect(requests, 2);
      expect(tester.takeException(), isNull);
      fail = true;
      await tester.tap(find.byTooltip('Actualizar'));
      await tester.pumpAndSettle();
      expect(find.text('Sin conexión'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('En preparación'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('Un filtro vacío permite volver a todos', (tester) async {
    SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'orders': request.url.queryParameters['scope'] == 'history'
              ? [order(2, 'delivered', 'Entregado')]
              : [],
        }),
        200,
      ),
    );
    addTearDown(client.close);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const MyOrdersScreen()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('order-filter-1')));
      await tester.pumpAndSettle();
      expect(find.text('No hay pedidos en este filtro'), findsOneWidget);
      await tester.tap(find.text('Ver todos'));
      await tester.pumpAndSettle();
      expect(find.text('Entregado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
