import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/restaurante/menu/restaurant_menu_screen.dart';
import 'package:torogo/features/restaurante/pedidos/orders_screen.dart';

Map<String, dynamic> product(int id) => {
  'id': id,
  'name': 'Pláto $id',
  'price': '1.00',
  'is_available': id.isOdd,
  'sort_order': id,
  if (id == 1) 'image_url': 'https://example.test/plato-1.jpg',
};

void main() {
  testWidgets('Menú de 50 platos busca, pagina y filtra sin recargar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      if (request.method == 'PATCH') {
        return http.Response('{"message":"No se pudo guardar"}', 503);
      }
      return http.Response(
        jsonEncode({
          'categories': [
            {
              'id': 1,
              'name': 'Típicos',
              'sort_order': 0,
              'products': [for (var id = 1; id <= 49; id++) product(id)],
            },
          ],
          'uncategorized': [product(50)],
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
          home: const RestaurantMenuScreen(onLogout: null),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Carga inicial del menú');
      expect(find.text('50 de 50 platos'), findsOneWidget);
      expect(find.text('Cada plato, listo para antojar.'), findsOneWidget);
      final photo = tester.widget<Image>(find.byType(Image).first);
      expect(
        (photo.image as NetworkImage).url,
        'https://example.test/plato-1.jpg',
      );
      expect(find.byIcon(Icons.restaurant_menu_rounded), findsWidgets);
      await tester.tap(find.text('Editar plato').first);
      await tester.pumpAndSettle();
      expect(find.text('Editar plato'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Pláto 1'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Página 1 de 7'), findsOneWidget);
      await tester.tap(find.byTooltip('Página siguiente'));
      await tester.pumpAndSettle();
      expect(find.text('Página 2 de 7'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'plato 50');
      await tester.pumpAndSettle();
      expect(find.text('1 de 50 platos'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Búsqueda y selector de categoría',
      );
      expect(find.text('Pláto 50'), findsOneWidget);
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-category-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-category-0')));
      await tester.pumpAndSettle();
      expect(find.text('Pláto 50'), findsOneWidget);
      expect(find.text('1 de 50 platos'), findsOneWidget);
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('menu-availability-2')),
      );
      await tester.tap(find.byKey(const ValueKey('menu-availability-2')));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Filtro de disponibilidad',
      );
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('menu-availability-2')),
            )
            .properties
            .selected,
        isTrue,
      );
      expect(find.text('25 de 50 platos'), findsOneWidget);
      expect(requests, 1);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('No se pudo guardar'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
      expect(find.text('Agregar plato').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('Pedidos conserva todas las etapas y acciones de cocina', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response(
        jsonEncode({
          'restaurant': {'id': 0},
          'orders': [
            for (final entry in {
              1: 'pending',
              2: 'accepted',
              3: 'preparing',
              4: 'ready',
              5: 'picked_up',
            }.entries)
              {
                'id': entry.key,
                'status': entry.value,
                'status_label': entry.value,
                'is_active': true,
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
                  'latitude': 14.1,
                  'longitude': -89.1,
                },
                'items': [
                  {
                    'id': 1,
                    'name': 'Pupusa',
                    'unit_price': '1.00',
                    'quantity': 1,
                    'subtotal': '1.00',
                  },
                ],
                'notes': 'Sin cebolla',
                'subtotal': '1.00',
                'delivery_fee': '2.00',
                'courier_fee': '1.50',
                'platform_fee': '0.50',
                'tip_amount': '1.00',
                'total': '4.00',
                'payment_method': 'cash',
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
      final tabs = [
        for (var index = 0; index < 3; index++)
          find.byKey(ValueKey('restaurant-stage-$index')),
      ];
      final positions = tabs.map(tester.getTopLeft).toList();
      expect(positions[0].dy, positions[1].dy);
      expect(positions[1].dy, positions[2].dy);
      for (final tab in tabs) {
        expect(tab.hitTestable(), findsOneWidget);
        expect(tester.getSize(tab).height, greaterThanOrEqualTo(48));
      }
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.byIcon(Icons.soup_kitchen_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delivery_dining_rounded), findsOneWidget);
      expect(find.text('Aceptar'), findsOneWidget);
      expect(find.text('Total del pedido'), findsOneWidget);
      expect(find.text(r'$4.00'), findsOneWidget);
      expect(find.text('Sin cebolla'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('restaurant-stage-1')));
      await tester.pumpAndSettle();
      expect(find.text('Empezar a preparar'), findsOneWidget);
      expect(find.text('Listo para recoger'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('restaurant-stage-2')));
      await tester.pumpAndSettle();
      expect(find.text('Esperando un motorizado.'), findsOneWidget);
      expect(find.text('El motorizado ya lo recogió.'), findsOneWidget);
      await tester.tap(find.text('Ver detalle del pedido').first);
      await tester.pumpAndSettle();
      expect(find.text('Referencia: Portón azul'), findsOneWidget);
      expect(find.text('Propina al motorista'), findsOneWidget);
      expect(requests, 1);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
