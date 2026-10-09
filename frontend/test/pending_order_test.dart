import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/api_client.dart';
import 'package:torogo/features/cliente/carrito/cart.dart';
import 'package:torogo/features/cliente/pedido/order_repository.dart';
import 'package:torogo/features/cliente/pedido/pending_order_storage.dart';
import 'package:torogo/models/address.dart';
import 'package:torogo/models/product.dart';

const Address address = Address(
  id: 1,
  label: 'Casa',
  address: 'Dirección del cliente',
  latitude: 14.1,
  longitude: -89.1,
  isDefault: true,
);
const Cart cart = Cart(
  restaurantId: 7,
  restaurantName: 'Restaurante',
  items: <CartItem>[
    CartItem(
      product: Product(
        id: 3,
        name: 'Sub',
        price: '4.00',
        isAvailable: true,
        sortOrder: 0,
      ),
      quantity: 1,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'Un corte conserva el envio original y bloquea un nuevo pedido',
    () async {
      Map<String, dynamic>? original;
      int submissions = 0;
      int owner = 9;
      bool malformedRecovery = false;
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/me')) {
          return http.Response(jsonEncode(<String, int>{'id': owner}), 200);
        }
        if (request.url.path.endsWith('/orders/recover')) {
          expect(jsonDecode(request.body), <String, dynamic>{
            'idempotency_key': original!['idempotency_key'],
          });
          return malformedRecovery
              ? http.Response('{}', 200)
              : http.Response('{"message":"Sin conexión"}', 500);
        }
        submissions++;
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        original ??= body;
        expect(body, original);
        throw http.ClientException('Respuesta perdida');
      });
      addTearDown(client.close);
      final OrderRepository first = OrderRepository(ApiClient(client: client));
      await expectLater(
        first.create(
          cart: cart,
          address: address,
          deliveryFee: '2.00',
          tipAmount: '1.25',
        ),
        throwsA(isA<ApiException>()),
      );

      final OrderRepository restarted = OrderRepository(
        ApiClient(client: client),
      );
      expect((await restarted.loadPending())!.body, original);
      expect((await restarted.loadPending())!.tipAmount, '1.25');
      expect(original!['tip_amount'], '1.25');
      await expectLater(
        restarted.create(
          cart: Cart.empty,
          address: address,
          deliveryFee: '0.00',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(submissions, 1);
      await expectLater(
        restarted.recoverPending(),
        throwsA(isA<ApiException>()),
      );
      expect(submissions, 1);
      malformedRecovery = true;
      await expectLater(
        restarted.recoverPending(),
        throwsA(isA<ApiException>()),
      );
      expect(await PendingOrderStorage().load(9), isNotNull);

      // Otra cuenta no ve ni reenvia el intento de la primera.
      owner = 10;
      final OrderRepository other = OrderRepository(ApiClient(client: client));
      expect(await other.loadPending(), isNull);
      await expectLater(other.recoverPending(), throwsA(isA<ApiException>()));
      expect(submissions, 1);
      expect(await PendingOrderStorage().load(9), isNotNull);
    },
  );

  for (final int status in <int>[422, 404]) {
    test('Un rechazo HTTP $status libera el intento para corregirlo', () async {
      final List<String> keys = <String>[];
      final MockClient client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/me')) {
          return http.Response('{"id":9}', 200);
        }
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        keys.add(body['idempotency_key'] as String);
        return http.Response(
          '{"message":"Pedido rechazado antes de guardar"}',
          status,
        );
      });
      addTearDown(client.close);
      final OrderRepository repository = OrderRepository(
        ApiClient(client: client),
      );
      for (int attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          repository.create(cart: cart, address: address, deliveryFee: '2.00'),
          throwsA(isA<ApiException>()),
        );
        expect(await repository.loadPending(), isNull);
      }
      expect(keys.length, 2);
      expect(keys[0], isNot(keys[1]));
    });
  }

  test('Un intento ilegible nunca se reemplaza por uno nuevo', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'torogo_pending_order_9': '{json incompleto',
    });
    int submissions = 0;
    final MockClient client = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/me')) {
        return http.Response('{"id":9}', 200);
      }
      submissions++;
      return http.Response('{}', 500);
    });
    addTearDown(client.close);
    final OrderRepository repository = OrderRepository(
      ApiClient(client: client),
    );
    await expectLater(
      repository.create(cart: cart, address: address, deliveryFee: '2.00'),
      throwsA(isA<ApiException>()),
    );
    expect(submissions, 0);
  });
}
