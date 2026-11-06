import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/core/widgets/torogo_map.dart';
import 'package:torogo/features/cliente/pedido/order_tracking_screen.dart';
import 'package:torogo/features/cliente/pedido/order_tracking_content.dart';
import 'package:torogo/models/order.dart';

Map<String, dynamic> timedOrder(String status) => {
  'id': 50,
  'status': status,
  'status_label': {
    'pending': 'Pendiente',
    'accepted': 'Aceptado',
    'preparing': 'En preparación',
    'ready': 'Listo para recoger',
    'picked_up': 'En camino',
    'delivered': 'Entregado',
    'cancelled': 'Cancelado',
    'rejected': 'Rechazado',
  }[status],
  'is_active': !['delivered', 'cancelled', 'rejected'].contains(status),
  'restaurant': {
    'id': 1,
    'name': 'Baruk',
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
  'created_at': '2026-10-31T07:00:00',
  'accepted_at': '2026-10-31T07:05:00',
  'ready_at': '2026-10-31T07:20:00',
  'picked_up_at': '2026-10-31T07:30:00',
  'delivered_at': '2026-10-31T08:00:00',
  'cancelled_at': '2026-10-31T07:35:00',
};

Widget trackingContent(Map<String, dynamic> json) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(
    body: OrderTrackingContent(
      order: Order.fromJson(json),
      connected: false,
      cancelling: false,
      onCancel: () {},
      onRefresh: () {},
      map: const SizedBox(),
      location: null,
      gpsError: false,
    ),
  ),
);

Future<void> openSection(WidgetTester tester, String label) async {
  final control = find.text(label);
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  expect(control.hitTestable(), findsOneWidget);
  await tester.tap(control);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('El estado usa su propia hora y no inventa una fecha faltante', (
    tester,
  ) async {
    for (final entry in {
      'pending': '7:00 AM',
      'accepted': '7:05 AM',
      'preparing': null,
      'ready': '7:20 AM',
      'picked_up': '7:30 AM',
      'delivered': '8:00 AM',
      'cancelled': '7:35 AM',
      'rejected': '7:35 AM',
    }.entries) {
      final json = timedOrder(entry.key);
      await tester.pumpWidget(trackingContent(json));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('order-current-status')))
            .data,
        '${json['status_label']}${entry.value == null ? '' : ' · 31/10/2026 · ${entry.value}'}',
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(
      trackingContent({...timedOrder('picked_up'), 'picked_up_at': null}),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('order-current-status')))
          .data,
      'En camino',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancelar después de recoger conserva el recorrido realizado', (
    tester,
  ) async {
    await tester.pumpWidget(
      trackingContent({...timedOrder('cancelled'), 'delivered_at': null}),
    );
    await tester.pumpAndSettle();
    await openSection(tester, 'Recorrido del pedido');
    final labels = [
      'Pedido hecho',
      'El restaurante lo aceptó',
      'Listo para recoger',
      'En camino',
      'Cancelado',
    ];
    for (var i = 0; i < labels.length; i++) {
      expect(
        tester.widget<Text>(find.byKey(ValueKey('order-milestone-$i'))).data,
        labels[i],
      );
    }
    for (final hour in ['7:00', '7:05', '7:20', '7:30', '7:35']) {
      expect(find.text('31/10/2026 · $hour AM'), findsOneWidget);
    }
    expect(find.text('Entregado'), findsNothing);
    expect(find.textContaining('No tenés que pagar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Cliente muestra GPS privado, oculta posiciones antiguas y detiene consultas al finalizar',
    (tester) async {
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      var stale = false;
      var finished = false;
      var gpsRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/location')) {
          gpsRequests++;
          return http.Response(
            jsonEncode({
              'order_id': 40,
              'courier_id': finished ? null : 2,
              'status': finished ? 'delivered' : 'picked_up',
              'location': finished
                  ? null
                  : {
                      'latitude': 14.15,
                      'longitude': -89.15,
                      'accuracy': 12,
                      'captured_at': DateTime.now()
                          .subtract(Duration(minutes: stale ? 5 : 0))
                          .toUtc()
                          .toIso8601String(),
                    },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'order': {
              'id': 40,
              'status': finished ? 'delivered' : 'picked_up',
              'status_label': finished ? 'Entregado' : 'En camino',
              'is_active': !finished,
              'restaurant': {
                'id': 1,
                'name': 'Local',
                'address': 'Centro',
                'latitude': 14.1,
                'longitude': -89.1,
              },
              'delivery': {
                'address': 'Casa',
                'latitude': 14.2,
                'longitude': -89.2,
              },
              'courier': {'id': 2, 'name': 'Motorista'},
              'items': [],
              'subtotal': '1.00',
              'delivery_fee': '2.00',
              'courier_fee': '1.50',
              'platform_fee': '0.50',
              'total': '3.00',
              'payment_method': 'cash',
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      await http.runWithClient(() async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: const OrderTrackingScreen(orderId: 40),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TorogoMap), findsNothing);
        await openSection(tester, 'Dónde va tu pedido');
        expect(
          tester
              .widget<TorogoMap>(find.byType(TorogoMap))
              .points
              .any(
                (p) =>
                    p.icon == Icons.delivery_dining_rounded &&
                    p.latitude == 14.15,
              ),
          isTrue,
        );
        stale = true;
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TorogoMap>(find.byType(TorogoMap))
              .points
              .any((p) => p.icon == Icons.delivery_dining_rounded),
          isFalse,
        );
        finished = true;
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('order-current-status')))
              .data,
          startsWith('Entregado'),
        );
        final stoppedAt = gpsRequests;
        await tester.pump(const Duration(seconds: 20));
        await tester.pumpAndSettle();
        expect(gpsRequests, stoppedAt);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }, () => client);
    },
  );

  for (final status in ['cancelled', 'rejected']) {
    testWidgets('Pedido $status en efectivo no indica un pago pendiente', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'order': {
              'id': 35,
              'status': status,
              'status_label': status == 'cancelled' ? 'Cancelado' : 'Rechazado',
              'is_active': false,
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
              'cancellation_reason': status == 'cancelled'
                  ? 'El restaurante no respondió a tiempo.'
                  : null,
            },
          }),
          200,
        ),
      );
      addTearDown(client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: const OrderTrackingScreen(orderId: 35),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('No tenés que pagar'), findsOneWidget);
        expect(find.text('Pagás en efectivo al recibir'), findsNothing);
        expect(find.text(r'$3.00'), findsOneWidget);
        if (status == 'cancelled') {
          expect(
            find.text('El restaurante no respondió a tiempo.'),
            findsOneWidget,
          );
        }
        await openSection(tester, 'Recorrido del pedido');
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('order-milestone-1')))
              .data,
          status == 'cancelled' ? 'Cancelado' : 'Rechazado',
        );
        expect(find.text('El restaurante lo aceptó'), findsNothing);
        expect(find.text('Listo para recoger'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }, () => client);
    });
  }

  testWidgets(
    'Detalle conserva total, propina y mapa desplegable al finalizar',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'order': {
              'id': 28,
              'status': 'delivered',
              'status_label': 'Entregado',
              'is_active': false,
              'restaurant': {
                'id': 1,
                'name': 'Los Tres Cerditos con nombre largo',
                'address': 'Centro',
                'latitude': 14.1,
                'longitude': -89.1,
              },
              'delivery': {
                'address': 'Aguaje Escondido Cas Valle Nuevo',
                'reference': 'Portón azul',
                'latitude': 14.11,
                'longitude': -89.11,
              },
              'courier': {
                'id': 2,
                'name':
                    'Motorizado con nombre muy largo para comprobar el espacio',
              },
              'items': [
                {
                  'id': 1,
                  'name': 'Pupusa de queso',
                  'quantity': 3,
                  'unit_price': '1.00',
                  'subtotal': '3.00',
                },
              ],
              'subtotal': '3.00',
              'delivery_fee': '2.00',
              'courier_fee': '1.50',
              'platform_fee': '0.50',
              'tip_amount': '1.00',
              'total': '6.00',
              'payment_method': 'cash',
              'created_at': '2026-10-08T22:14:00',
              'delivered_at': '2026-10-08T22:15:00',
            },
          }),
          200,
        ),
      );
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
            home: const OrderTrackingScreen(orderId: 28),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(r'$6.00'), findsOneWidget);
        expect(find.text('Total del pedido'), findsOneWidget);
        expect(find.text('Pagás en efectivo al recibir'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Propina'), 200);
        expect(find.text(r'$1.00'), findsOneWidget);
        expect(find.text('Portón azul'), findsNothing);
        await openSection(tester, 'Entrega');
        expect(find.text('Portón azul'), findsOneWidget);
        expect(find.byType(TorogoMap), findsNothing);
        await openSection(tester, 'Ver ubicación en el mapa');
        expect(find.byType(TorogoMap), findsOneWidget);
        expect(
          find.text('flutter_map · © OpenStreetMap contributors'),
          findsOneWidget,
        );
        await openSection(tester, 'Recorrido del pedido');
        expect(find.text('Pedido hecho'), findsOneWidget);
        expect(find.text('El restaurante lo aceptó'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }, () => client);
    },
  );
}
