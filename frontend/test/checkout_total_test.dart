import 'dart:async';
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
import 'package:torogo/features/cliente/pedido/pending_order_storage.dart';
import 'package:torogo/models/product.dart';

void main() {
  for (final int status in <int>[201, 200, 500, 0, -1]) {
    testWidgets(
      'El checkout conserva total e intento (respuesta $status; 0=corte, -1=timeout)',
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
        final Map<String, dynamic> serverOrder = <String, dynamic>{
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
              };
        int submissions = 0;
        Map<String, dynamic>? originalBody;
        final MockClient client = MockClient((http.Request request) async {
          if (request.method == 'GET' && request.url.path.endsWith('/me')) {
            return http.Response(jsonEncode(<String, int>{'id': 9}), 200);
          }
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
          if (request.method == 'POST' && request.url.path.endsWith('/orders/recover')) {
            expect(jsonDecode(request.body), <String, dynamic>{
              'idempotency_key': originalBody!['idempotency_key'],
            });
            return http.Response(jsonEncode(<String, dynamic>{
              'order': status == -1 ? null : serverOrder,
            }), 200);
          }
          if (request.method == 'POST' && request.url.path.endsWith('/orders')) {
            submissions++;
            final Map<String, dynamic> body =
                jsonDecode(request.body) as Map<String, dynamic>;
            final PendingOrder? saved = await PendingOrderStorage().load(9);
            // La solicitud ya debe estar guardada ANTES de viajar a la API.
            expect(saved!.body, body);
            originalBody ??= body;
            if (submissions == 1) {
              expect(body, originalBody);
            } else {
              expect(body['idempotency_key'], isNot(originalBody!['idempotency_key']));
            }
            expect(body['items'], <Map<String, int>>[
              <String, int>{'product_id': submissions == 1 ? 3 : 4, 'quantity': 1},
            ]);
            expect(body.containsKey('total'), isFalse);
            if (submissions == 1 && status == -1) {
              return Completer<http.Response>().future;
            }
            if (submissions == 1 && status == 0) {
              throw http.ClientException('El servidor guardó el pedido, pero se perdió la respuesta');
            }
            if (submissions == 1 && status == 500) {
              return http.Response('{"message":"Falló la notificación después de guardar"}', 500);
            }
            return http.Response(jsonEncode(<String, dynamic>{
              'order': serverOrder,
            }), submissions > 1 ? 200 : status);
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

          ProviderContainer activeContainer = container;
          if (status <= 0 || status == 500) {
            expect(find.byType(OrderSentScreen), findsNothing);
            expect(submissions, 1);
            await tester.runAsync(() async {
              expect((await PendingOrderStorage().load(9))!.body, originalBody);
            });
            // Los avisos de pendiente y error alargan la lista. Flutter no
            // construye todos sus hijos hasta desplazarse hacia ellos.
            await tester.scrollUntilVisible(
              find.widgetWithText(FilledButton, 'Recuperar pedido'),
              200,
            );
            expect(find.text('Recuperar pedido'), findsOneWidget);
            expect(container.read(cartProvider).isNotEmpty, isTrue);

            if (status == 500) {
              // Si se edito el carrito fuera del checkout, el reintento sigue
              // siendo el original y no borra las nuevas modificaciones.
              await tester.runAsync(() async {
                await container.read(cartProvider.notifier).add(
                  const Product(id: 3, name: 'Sub de pollo', price: '4.00',
                    isAvailable: true, sortOrder: 0),
                  restaurantId: 7,
                  restaurantName: 'Nombre guardado en el carrito',
                );
              });
            }

            // Simula salir y reiniciar: nueva pantalla, repositorio y estado.
            await tester.pumpWidget(const SizedBox.shrink());
            activeContainer = ProviderContainer();
            addTearDown(activeContainer.dispose);
            await tester.pumpWidget(UncontrolledProviderScope(
              container: activeContainer,
              child: const MaterialApp(home: CheckoutScreen()),
            ));
            await tester.pumpAndSettle();
            expect(find.text(r'$6.00'), findsOneWidget);
            final Finder recover = find.widgetWithText(FilledButton, 'Recuperar pedido');
            await tester.scrollUntilVisible(recover, 200);
            await tester.tap(recover);
            await tester.pumpAndSettle();
            expect(submissions, 1);
            if (status == -1) {
              expect(find.byType(OrderSentScreen), findsNothing);
              await tester.runAsync(() async {
                expect(await PendingOrderStorage().load(9), isNull);
                await activeContainer.read(cartProvider.notifier).add(
                  const Product(id: 4, name: 'Otro plato', price: '5.50',
                    isAvailable: true, sortOrder: 0),
                  restaurantId: 7, restaurantName: 'Restaurante',
                );
              });
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(find.byTooltip('Quitar plato').first, -200);
              await tester.tap(find.byTooltip('Quitar plato').first);
              await tester.pumpAndSettle();
              expect(activeContainer.read(cartProvider).quantityOf(3), 0);
              final Finder confirmAgain = find.widgetWithText(FilledButton, 'Confirmar pedido');
              await tester.scrollUntilVisible(confirmAgain, 200);
              await tester.tap(confirmAgain);
              await tester.pumpAndSettle();
              expect(submissions, 2);
            }
          } else {
            expect(submissions, 1);
          }

          expect(find.byType(OrderSentScreen), findsOneWidget);
          expect(tester.widget<OrderSentScreen>(find.byType(OrderSentScreen)).alreadySent,
              status == 500 || status == 0);
          expect(find.text(r'$7.25'), findsOneWidget);
          expect(find.text('Pedido #42 · Restaurante confirmado'), findsOneWidget);
          if (status == 500) {
            expect(activeContainer.read(cartProvider).quantityOf(3), 2);
          } else {
            expect(activeContainer.read(cartProvider).isEmpty, isTrue);
          }
          await tester.runAsync(() async {
            expect(await PendingOrderStorage().load(9), isNull);
          });
          expect(tester.takeException(), isNull);
        }, () => client);
      },
    );
  }
}
