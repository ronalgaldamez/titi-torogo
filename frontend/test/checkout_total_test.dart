import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/features/cliente/carrito/cart_provider.dart';
import 'package:torogo/features/cliente/pedido/checkout_screen.dart';
import 'package:torogo/features/cliente/pedido/order_sent_screen.dart';
import 'package:torogo/models/product.dart';

void main() {
  for (final int status in <int>[201, 200]) {
    testWidgets(
      'La confirmación usa el total del servidor y vacía el carrito (HTTP $status)',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          'torogo_token': 'token-de-prueba',
        });
        final ProviderContainer container = ProviderContainer();
        addTearDown(container.dispose);
        await tester.runAsync(() async {
          await container.read(cartProvider.notifier).add(
                const Product(
                  id: 3,
                  name: 'Sub de pollo',
                  price: '4.00',
                  isAvailable: true,
                  sortOrder: 0,
                ),
                restaurantId: 7,
                restaurantName: 'Nombre guardado en el carrito',
              );
        });

        final Map<String, dynamic> restaurant = <String, dynamic>{
          'id': 7,
          'name': 'Restaurante confirmado',
          'address': 'Dirección del restaurante',
          'latitude': 14.1,
          'longitude': -89.1,
          'is_open': true,
          'is_busy': false,
          'estimated_delivery_minutes': 30,
          'delivery_fee': '2.00',
        };
        final Map<String, dynamic> address = <String, dynamic>{
          'id': 1,
          'label': 'Casa',
          'address': 'Dirección del cliente',
          'latitude': 14.2,
          'longitude': -89.2,
          'is_default': true,
        };
        final MockClient client = MockClient((http.Request request) async {
          if (request.method == 'GET' && request.url.path.endsWith('/addresses')) {
            return http.Response(jsonEncode(<String, dynamic>{
              'addresses': <Map<String, dynamic>>[address],
            }), 200);
          }
          if (request.method == 'GET' && request.url.path.endsWith('/restaurants/7')) {
            return http.Response(jsonEncode(<String, dynamic>{
              'restaurant': restaurant,
              'categories': <dynamic>[],
            }), 200);
          }
          if (request.method == 'POST' && request.url.path.endsWith('/orders')) {
            final Map<String, dynamic> body =
                jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['items'], <Map<String, int>>[
              <String, int>{'product_id': 3, 'quantity': 1},
            ]);
            expect(body.containsKey('total'), isFalse);
            return http.Response(jsonEncode(<String, dynamic>{
              'order': <String, dynamic>{
                'id': 42,
                'status': 'pending',
                'status_label': 'Pendiente',
                'is_active': true,
                'restaurant': restaurant,
                'delivery': address,
                'items': <dynamic>[],
                'subtotal': '5.25',
                'delivery_fee': '2.00',
                'courier_fee': '1.50',
                'platform_fee': '0.50',
                'total': '7.25',
                'payment_method': 'cash',
              },
            }), status);
          }
          fail('Petición inesperada: ${request.method} ${request.url}');
        });
        addTearDown(client.close);

        await http.runWithClient(() async {
          await tester.pumpWidget(UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: CheckoutScreen()),
          ));
          await tester.pumpAndSettle();
          expect(find.text(r'$6.00'), findsOneWidget);

          final Finder confirm = find.widgetWithText(FilledButton, 'Confirmar pedido');
          await tester.ensureVisible(confirm);
          await tester.tap(confirm);
          await tester.pumpAndSettle();

          expect(find.byType(OrderSentScreen), findsOneWidget);
          expect(find.text(r'$7.25'), findsOneWidget);
          expect(find.text('Pedido #42 · Restaurante confirmado'), findsOneWidget);
          expect(container.read(cartProvider).isEmpty, isTrue);
          expect(tester.takeException(), isNull);
        }, () => client);
      },
    );
  }
}
