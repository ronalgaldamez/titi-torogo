import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/features/cliente/carrito/cart_provider.dart';
import 'package:torogo/features/cliente/direcciones/addresses_screen.dart';
import 'package:torogo/features/cliente/pedido/checkout_screen.dart';
import 'package:torogo/features/cliente/pedido/pending_order_storage.dart';
import 'package:torogo/models/product.dart';

void main() {
  const rejection = {
    'fee_changed': (
      'expected_delivery_fee',
      'Cambió el costo del envío. Revisá el nuevo total antes de confirmar.',
    ),
    'address_changed': (
      'expected_address_version',
      'La dirección cambió. Revisá dónde querés recibir el pedido antes de confirmar.',
    ),
    'price_changed': ('items', 'Cambió el precio de un plato.'),
  };
  for (final scenario in ['edited', 'removed', 'failed', ...rejection.keys]) {
    testWidgets('Checkout actualiza dirección y cotización: $scenario', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        await container
            .read(cartProvider.notifier)
            .add(
              const Product(
                id: 3,
                name: 'Plato',
                price: '4.00',
                isAvailable: true,
                sortOrder: 0,
              ),
              restaurantId: 7,
              restaurantName: 'Local',
              quantity: scenario == 'price_changed' ? 2 : 1,
            );
      });
      var changed = false;
      var price = '4.00';
      final submissions = <Map<String, dynamic>>[];
      final feeLatitudes = <String?>[];
      const restaurant = {
        'id': 7,
        'name': 'Local',
        'address': 'Centro',
        'latitude': 14.1,
        'longitude': -89.1,
        'is_open': true,
        'is_busy': false,
        'estimated_delivery_minutes': 30,
      };
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/me')) {
          return http.Response(jsonEncode({'id': 9}), 200);
        }
        if (request.url.path.endsWith('/addresses')) {
          if (changed && scenario == 'failed') {
            return http.Response(
              jsonEncode({
                'message': 'No se pudieron actualizar las direcciones.',
              }),
              503,
            );
          }
          return http.Response(
            jsonEncode({
              'addresses': changed && scenario == 'removed'
                  ? []
                  : [
                      {
                        'id': 1,
                        'label': 'Casa',
                        'address': changed
                            ? 'Casa actualizada'
                            : 'Casa anterior',
                        'reference': changed
                            ? 'Portón nuevo'
                            : 'Portón anterior',
                        'latitude': changed ? 14.3 : 14.2,
                        'longitude': -89.2,
                        'is_default': true,
                        'delivery_version':
                            changed &&
                                (scenario == 'address_changed' ||
                                    scenario == 'edited')
                            ? 'version-2'
                            : 'version-1',
                      },
                    ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/restaurants/7')) {
          feeLatitudes.add(request.url.queryParameters['latitude']);
          return http.Response(
            jsonEncode({
              'restaurant': {
                ...restaurant,
                'delivery_fee':
                    changed &&
                        (scenario == 'edited' || scenario == 'fee_changed')
                    ? '3.00'
                    : '2.00',
              },
              'categories': [
                {
                  'id': 1,
                  'name': 'Platos',
                  'sort_order': 0,
                  'products': [
                    {
                      'id': 3,
                      'name': 'Plato',
                      'price': price,
                      'is_available': true,
                      'sort_order': 0,
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }
        if (request.method == 'POST' && request.url.path.endsWith('/orders')) {
          submissions.add(jsonDecode(request.body) as Map<String, dynamic>);
          if (submissions.length == 1) {
            expect(submissions.single['expected_delivery_fee'], '2.00');
            expect(submissions.single['expected_address_version'], 'version-1');
            final (field, message) = rejection[scenario]!;
            changed = true;
            if (scenario == 'price_changed') price = '5.50';
            return http.Response(
              jsonEncode({
                'errors': {
                  field: [message],
                },
              }),
              422,
            );
          }

          return http.Response(
            jsonEncode({
              'order': {
                'id': 42,
                'status': 'pending',
                'status_label': 'Pendiente',
                'is_active': true,
                'restaurant': restaurant,
                'total': scenario == 'price_changed' ? '14.00' : '6.00',
                'payment_method': 'cash',
              },
            }),
            201,
          );
        }
        fail('Solicitud inesperada: ${request.method} ${request.url}');
      });
      addTearDown(client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: CheckoutScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Casa anterior'), findsOneWidget);
        expect(
          find.text(scenario == 'price_changed' ? r'$10.00' : r'$6.00'),
          findsOneWidget,
        );
        if (rejection.containsKey(scenario)) {
          final confirm = find.widgetWithText(FilledButton, 'Confirmar pedido');
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(submissions, hasLength(1));
          switch (scenario) {
            case 'address_changed':
              expect(find.text('Casa actualizada'), findsOneWidget);
              expect(find.text('Casa anterior'), findsNothing);
              expect(feeLatitudes.last, '14.3');
              expect(find.text(r'$6.00'), findsOneWidget);
            case 'price_changed':
              expect(find.text(r'$13.00'), findsOneWidget);
              expect(container.read(cartProvider).quantityOf(3), 2);
              expect(
                container.read(cartProvider).items.single.product.price,
                '5.50',
              );
            case 'fee_changed':
              expect(find.text(r'$7.00'), findsOneWidget);
          }
          final quoteError = find.text(
            scenario == 'price_changed'
                ? 'Cambió el precio de uno o más platos. Revisá el nuevo total antes de confirmar.'
                : rejection[scenario]!.$2,
          );
          await tester.scrollUntilVisible(
            quoteError,
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(quoteError, findsOneWidget);
          await tester.runAsync(() async {
            expect(await PendingOrderStorage().load(9), isNull);
          });
          if (scenario == 'price_changed') {
            price = '6.00';
            final update = find.text('Actualizar');
            await tester.scrollUntilVisible(
              update,
              120,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.tap(update);
            await tester.pumpAndSettle();
            expect(find.text(r'$14.00'), findsOneWidget);
            expect(submissions, hasLength(1));
          }
          if (scenario != 'fee_changed') {
            await tester.tap(confirm);
            await tester.pumpAndSettle();
            expect(submissions, hasLength(2));
            expect(
              submissions.last['idempotency_key'],
              isNot(submissions.first['idempotency_key']),
            );
            if (scenario == 'address_changed') {
              expect(submissions.last['expected_address_version'], 'version-2');
            } else {
              expect(submissions.last['items'], [
                {'product_id': 3, 'quantity': 2, 'expected_unit_price': '6.00'},
              ]);
            }
            expect(find.text('¡Pedido enviado!'), findsOneWidget);
          }
        } else {
          await tester.tap(find.text('Casa anterior'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Administrar mis direcciones'));
          await tester.pumpAndSettle();
          expect(find.byType(AddressesScreen), findsOneWidget);
          // La edición conserva el mismo id; al volver debe usarse la copia del servidor.
          changed = true;
          Navigator.of(tester.element(find.byType(AddressesScreen))).pop();
          await tester.pumpAndSettle();
          final confirm = tester.widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirmar pedido'),
          );
          if (scenario == 'edited') {
            expect(find.text('Casa actualizada'), findsOneWidget);
            expect(find.text('Portón nuevo'), findsOneWidget);
            expect(find.text('Casa anterior'), findsNothing);
            expect(feeLatitudes.last, '14.3');
            expect(find.text(r'$7.00'), findsOneWidget);
            expect(confirm.onPressed, isNotNull);
          } else {
            expect(confirm.onPressed, isNull);
            expect(submissions, isEmpty);
          }
        }
        expect(tester.takeException(), isNull);
      }, () => client);
    });
  }
}
