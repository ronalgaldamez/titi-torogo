import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/cliente/carrito/cart_provider.dart';
import 'package:torogo/features/cliente/restaurante/restaurant_detail_screen.dart';
import 'package:torogo/models/restaurant.dart';

void main() {
  testWidgets('La carta filtra categorías sin agregar platos hasta confirmar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final restaurant = <String, dynamic>{
      'id': 1,
      'name': 'Restaurante de prueba',
      'address': 'Centro de Tejutla',
      'latitude': 14.1,
      'longitude': -89.1,
      'is_open': true,
      'is_busy': false,
      'estimated_delivery_minutes': 30,
      'delivery_fee': '2.00',
      'distance_km': 0.9,
    };
    int loads = 0;
    final client = MockClient((request) async {
      expect(request.url.path.endsWith('/restaurants/1'), isTrue);
      loads++;
      return http.Response(
        jsonEncode({
          'restaurant': restaurant,
          'categories': [
            for (final entry in [
              (1, 'Pizzas', 'Pizza personal'),
              (2, 'Bebidas', 'Limonada'),
            ])
              {
                'id': entry.$1,
                'name': entry.$2,
                'sort_order': entry.$1,
                'products': [
                  {
                    'id': entry.$1,
                    'name': entry.$3,
                    'price': '4.50',
                    'is_available': true,
                    'sort_order': 0,
                  },
                ],
              },
          ],
        }),
        200,
      );
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: RestaurantDetailScreen(
              restaurant: Restaurant.fromJson(restaurant),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == 'assets/login.jpg',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Información'));
      await tester.pumpAndSettle();
      expect(find.text('Centro de Tejutla'), findsWidgets);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      final drinks = find.widgetWithText(ChoiceChip, 'Bebidas');
      await tester.ensureVisible(drinks);
      await tester.tap(drinks);
      await tester.pumpAndSettle();
      expect(find.text('Pizza personal'), findsNothing);
      expect(find.text('Limonada'), findsOneWidget);
      expect(loads, 1);
      final add = find.byTooltip('Ver Limonada y agregar');
      await tester.ensureVisible(add);
      expect(tester.getSize(add).width, greaterThanOrEqualTo(48));
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(container.read(cartProvider).isEmpty, isTrue);
      await tester.tap(find.text('Agregar al carrito'));
      await tester.pumpAndSettle();
      expect(container.read(cartProvider).quantityOf(2), 1);
      expect(find.text('Ver pedido').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
