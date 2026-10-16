import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/restaurante/pedidos/orders_screen.dart';

Map<String, dynamic> historyOrder(int id, String status) => {
  'id': id,
  'status': status,
  'status_label': {
    'delivered': 'Entregado',
    'rejected': 'Rechazado',
    'cancelled': 'Cancelado',
  }[status],
  'is_active': false,
  'restaurant': {
    'id': 1,
    'name': 'Local',
    'address': 'Centro',
    'latitude': 14.1,
    'longitude': -89.1,
  },
  'delivery': {
    'address': 'Casa',
    'reference': 'Portón azul',
    'latitude': 14.2,
    'longitude': -89.2,
  },
  'items': [
    {
      'id': 1,
      'name': 'Pupusa de queso con nombre largo',
      'quantity': 3,
      'unit_price': '1.00',
      'subtotal': '3.00',
    },
  ],
  'subtotal': '3.00',
  'delivery_fee': '2.00',
  'tip_amount': '1.00',
  'total': '6.00',
  'courier_fee': '1.50',
  'platform_fee': '0.50',
  'payment_method': 'cash',
  'created_at': '2026-10-01T10:00:00',
  'delivered_at': status == 'delivered' ? '2026-10-11T12:35:00' : null,
  'cancelled_at': status != 'delivered' ? '2026-10-11T11:42:00' : null,
};

void main() {
  testWidgets(
    'Historial abre desde Pedidos, filtra, pagina y conserva detalle y errores',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      var fail = false;
      var empty = false;
      final queries = <Map<String, String>>[];
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer test');
        final query = request.url.queryParameters;
        if (query['scope'] != 'history') {
          return http.Response('{"restaurant":{"id":0},"orders":[]}', 200);
        }
        queries.add(query);
        if (fail) {
          return http.Response('{"message":"Sin conexión"}', 503);
        }
        if (empty) {
          return http.Response(
            '{"orders":[],"pagination":{"current_page":1,"last_page":1,"total":0}}',
            200,
          );
        }
        final status = query['status'];
        final page = int.parse(query['page']!);
        final orders = status != null
            ? [historyOrder(3, status)]
            : page == 2
            ? [historyOrder(4, 'delivered')]
            : [
                historyOrder(1, 'delivered'),
                historyOrder(2, 'rejected'),
                historyOrder(3, 'cancelled'),
              ];
        return http.Response(
          jsonEncode({
            'orders': orders,
            'pagination': {
              'current_page': page,
              'last_page': status == null ? 2 : 1,
              'total': status == null ? 4 : 1,
            },
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
            home: const OrdersScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Historial de pedidos'));
        await tester.pumpAndSettle();
        expect(queries.last['period'], 'week');
        expect(find.text('Entregado'), findsOneWidget);
        expect(find.text('11/10/2026 · 12:35 PM'), findsOneWidget);
        expect(find.text('Pupusa de queso con nombre largo'), findsNothing);
        expect(find.text('Aceptar'), findsNothing);
        await tester.tap(find.text('Ver detalle del pedido').first);
        await tester.pumpAndSettle();
        final scrollable = find.byType(Scrollable).last;
        await tester.scrollUntilVisible(
          find.text('Propina al motorista'),
          150,
          scrollable: scrollable,
        );
        expect(find.text('Productos'), findsNWidgets(2));
        expect(find.text('Pupusa de queso con nombre largo'), findsOneWidget);
        expect(find.text('Casa'), findsOneWidget);
        expect(find.text('Referencia: Portón azul'), findsOneWidget);
        final firstOrder = find.byKey(const ValueKey('history-card-1'));
        expect(
          find.descendant(of: firstOrder, matching: find.text(r'$6.00')),
          findsOneWidget,
        );
        expect(find.text('Propina al motorista'), findsOneWidget);
        expect(find.text(r'$1.00'), findsOneWidget);
        await tester.tap(find.byTooltip('Página siguiente'));
        await tester.pumpAndSettle();
        expect(queries.last['page'], '2');
        expect(find.text('Pedido #4'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('restaurant-history-filter-3')),
        );
        await tester.pumpAndSettle();
        expect(queries.last['status'], 'cancelled');
        expect(queries.last['page'], '1');
        expect(find.text('Cancelado'), findsOneWidget);
        expect(find.text('Entregado'), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('restaurant-history-period')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hoy').last);
        await tester.pumpAndSettle();
        expect(queries.last['period'], 'today');
        fail = true;
        await tester.tap(find.byTooltip('Actualizar historial'));
        await tester.pumpAndSettle();
        expect(find.text('Sin conexión'), findsOneWidget);
        fail = false;
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(find.text('Cancelado'), findsOneWidget);
        empty = true;
        await tester.tap(find.byTooltip('Actualizar historial'));
        await tester.pumpAndSettle();
        expect(find.text('No hay pedidos con estos filtros.'), findsOneWidget);
        empty = false;
        await tester.tap(find.text('Ver todo el historial'));
        await tester.pumpAndSettle();
        expect(queries.last['period'], 'all');
        expect(queries.last.containsKey('status'), isFalse);
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );
}
