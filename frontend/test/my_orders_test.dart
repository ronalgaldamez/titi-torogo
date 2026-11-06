import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/cliente/pedido/my_orders_screen.dart';
import 'package:torogo/features/cliente/pedido/my_orders_content.dart';
import 'package:torogo/models/order.dart';

Future<void> revealOrderControl(
  WidgetTester tester,
  Finder control, {
  double delta = 180,
}) async {
  if (control.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      control,
      delta,
      maxScrolls: 150,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('customer-orders-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  expect(control.hitTestable(), findsOneWidget);
}

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
  testWidgets(
    'Historial largo renderiza bajo demanda y conserva filtros y apertura',
    (tester) async {
      final history = [
        for (var id = 1; id <= 300; id++)
          Order.fromJson(
            order(
              id,
              id == 300 ? 'cancelled' : 'delivered',
              id == 300 ? 'Cancelado' : 'Entregado',
            ),
          ),
      ];
      var selected = 0;
      int? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MyOrdersContent(
                active: const [],
                history: history,
                filter: selected,
                onFilter: (value) => setState(() => selected = value),
                onOpen: (value) => opened = value.id,
                onRefresh: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pedido #1'), findsOneWidget);
      expect(find.text('Pedido #300'), findsNothing);
      await revealOrderControl(tester, find.text('Pedido #300'), delta: 1000);
      await tester.tap(find.text('Pedido #300'));
      expect(opened, 300);
      final canceled = find.byKey(const ValueKey('order-filter-3'));
      await revealOrderControl(tester, canceled, delta: -1000);
      await tester.tap(canceled);
      await tester.pumpAndSettle();
      await revealOrderControl(tester, find.text('Pedido #300'));
      expect(find.text('Pedido #1'), findsNothing);
      expect(find.text('Cancelado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'El diseño abre seguimiento y permite volver desde la navegación',
    (tester) async {
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      var destination = 1;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/orders/1')) {
          return http.Response(
            jsonEncode({'order': order(1, 'preparing', 'En preparación')}),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'orders': request.url.queryParameters['scope'] == 'history'
                ? []
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
            home: MyOrdersScreen(
              onDestinationSelected: (index) => destination = index,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Lo que se viene. Lo que ya disfrutaste.'),
          findsOneWidget,
        );
        final tracking = find.text('Ver seguimiento');
        await revealOrderControl(tester, tracking);
        await tester.tap(tracking);
        await tester.pumpAndSettle();
        expect(find.textContaining('Tu antojo,'), findsOneWidget);
        expect(find.text('Dónde va tu pedido'), findsOneWidget);
        await tester.tap(find.text('Perfil'));
        await tester.pumpAndSettle();
        expect(destination, 2);
        await revealOrderControl(
          tester,
          find.text('Lo que se viene. Lo que ya disfrutaste.'),
          delta: -180,
        );
        expect(
          find.text('Lo que se viene. Lo que ya disfrutaste.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }, () => client);
    },
  );

  testWidgets(
    'Mis pedidos refleja vencimientos sin actualizar y conserva datos si falla la red',
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
      });
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      var cancelled = false;
      var fail = false;
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        if (fail) return http.Response('{"message":"Sin conexión"}', 503);
        final history = request.url.queryParameters['scope'] == 'history';
        return http.Response(
          jsonEncode({
            'orders': history
                ? (cancelled ? [order(1, 'cancelled', 'Cancelado')] : [])
                : (cancelled ? [] : [order(1, 'pending', 'Pendiente')]),
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
          MaterialApp(theme: AppTheme.light(), home: const MyOrdersScreen()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pendiente'), findsOneWidget);
        expect(requests, 2);
        fail = true;
        await tester.pump(const Duration(seconds: 15));
        await tester.pumpAndSettle();
        expect(find.text('Pendiente'), findsOneWidget);
        expect(find.text('Sin conexión'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        fail = false;
        cancelled = true;
        await tester.pump(const Duration(seconds: 15));
        await tester.pumpAndSettle();
        expect(find.text('Pendiente'), findsNothing);
        expect(find.text('Cancelado'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('order-filter-3')));
        await tester.pumpAndSettle();
        expect(find.text('Cancelado'), findsOneWidget);
        final afterCancellation = requests;
        await tester.pump(const Duration(seconds: 30));
        await tester.pumpAndSettle();
        expect(requests, afterCancellation);
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );

  testWidgets('Mis pedidos filtra sin recargar y conserva estados y montos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
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
      await revealOrderControl(tester, find.text('En preparación'));
      expect(find.text('En preparación'), findsOneWidget);
      expect(find.text(r'$5.00'), findsWidgets);
      expect(find.textContaining('3 productos'), findsWidgets);
      Future<void> filter(String label) async {
        final index = [
          'Todos',
          'En curso',
          'Completados',
          'Cancelados',
        ].indexOf(label);
        final chip = find.byKey(ValueKey('order-filter-$index'));
        await revealOrderControl(tester, chip, delta: -180);
        await tester.tap(chip);
        await tester.pumpAndSettle();
      }

      await filter('Completados');
      await revealOrderControl(tester, find.text('Entregado'));
      expect(find.text('Entregado'), findsOneWidget);
      expect(find.text('En preparación'), findsNothing);
      expect(find.text('Cancelado'), findsNothing);
      expect(find.text('09/10/2026 · 1:45 PM'), findsOneWidget);
      await filter('Cancelados');
      await revealOrderControl(tester, find.text('Cancelado'));
      expect(find.text('Cancelado'), findsOneWidget);
      await revealOrderControl(tester, find.text('Rechazado'));
      expect(find.text('Rechazado'), findsOneWidget);
      expect(find.text('Entregado'), findsNothing);
      await filter('En curso');
      await revealOrderControl(tester, find.text('Ver seguimiento'));
      expect(find.text('Ver seguimiento'), findsOneWidget);
      expect(find.text('Ver detalle'), findsNothing);
      expect(requests, 2);
      expect(tester.takeException(), isNull);
      fail = true;
      final refresh = find.byTooltip('Actualizar');
      await revealOrderControl(tester, refresh, delta: -180);
      await tester.tap(refresh);
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
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
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
