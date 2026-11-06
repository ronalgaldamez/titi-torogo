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
  for (final scenario in ['edited', 'removed', 'failed', 'fee_changed']) {
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
            );
      });
      var changed = false;
      var submissions = 0;
      final feeLatitudes = <String?>[];
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
                'id': 7,
                'name': 'Local',
                'address': 'Centro',
                'latitude': 14.1,
                'longitude': -89.1,
                'is_open': true,
                'is_busy': false,
                'estimated_delivery_minutes': 30,
                'delivery_fee': changed ? '3.00' : '2.00',
              },
              'categories': [],
            }),
            200,
          );
        }
        if (request.method == 'POST' && request.url.path.endsWith('/orders')) {
          submissions++;
          expect(jsonDecode(request.body)['expected_delivery_fee'], '2.00');
          changed = true;
          return http.Response(
            jsonEncode({
              'errors': {
                'expected_delivery_fee': [
                  'Cambió el costo del envío. Revisá el nuevo total antes de confirmar.',
                ],
              },
            }),
            422,
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
        expect(find.text(r'$6.00'), findsOneWidget);
        if (scenario == 'fee_changed') {
          await tester.tap(
            find.widgetWithText(FilledButton, 'Confirmar pedido'),
          );
          await tester.pumpAndSettle();
          expect(submissions, 1);
          expect(find.text(r'$7.00'), findsOneWidget);
          final quoteError = find.text(
            'Cambió el costo del envío. Revisá el nuevo total antes de confirmar.',
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
            expect(submissions, 0);
          }
        }
        expect(tester.takeException(), isNull);
      }, () => client);
    });
  }
}
