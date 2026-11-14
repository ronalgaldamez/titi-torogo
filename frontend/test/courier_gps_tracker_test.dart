import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:torogo/core/api_client.dart';
import 'package:torogo/features/motorizado/pedidos/courier_gps_tracker.dart';
import 'package:torogo/features/motorizado/pedidos/courier_order_repository.dart';

Map<String, dynamic> gpsOrder() => {
  'id': 1,
  'status': 'ready',
  'status_label': 'Listo',
  'is_active': true,
  'restaurant': {
    'id': 1,
    'name': 'Local',
    'address': 'Centro',
    'latitude': 14.1,
    'longitude': -89.1,
  },
  'subtotal': '1.00',
  'delivery_fee': '2.00',
  'courier_fee': '1.50',
  'platform_fee': '0.50',
  'total': '3.00',
  'payment_method': 'cash',
};

Position sample({double accuracy = 12, DateTime? time}) => Position(
  latitude: 14.15,
  longitude: -89.15,
  timestamp: time ?? DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  testWidgets(
    'Disponible sin entregas publica GPS real y deja de publicar al salir',
    (tester) async {
      final positions = StreamController<Position>();
      var presence = 0;
      final presenceRequests = <http.Request>[];
      var failConnection = true;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response('{"orders":[]}', 200);
        }
        presenceRequests.add(request);
        presence++;
        return failConnection
            ? http.Response('{"message":"Sin conexión"}', 503)
            : http.Response('{"accepted":true}', 200);
      });
      final tracker = CourierGpsTracker(
        repository: () async =>
            CourierOrderRepository(ApiClient(client: client)),
        positionSource: (_) async => positions.stream,
        onAssignmentsChanged: () {},
      );
      addTearDown(tracker.dispose);
      addTearDown(positions.close);
      addTearDown(client.close);
      tracker.setAvailable(true);
      await tracker.start();
      positions.add(sample(accuracy: 200));
      positions.add(
        sample(time: DateTime.now().subtract(const Duration(minutes: 5))),
      );
      await tester.pump();
      expect(presence, 0);
      positions.add(sample());
      await tester.pumpAndSettle();
      expect(presence, 1, reason: tracker.message);
      // Fuera del callback HTTP: expect() no debe competir con tester.pump().
      expect(presenceRequests.single.method, 'PATCH');
      expect(presenceRequests.single.url.path, endsWith('/courier/presence'));
      expect(jsonDecode(presenceRequests.single.body)['accuracy'], 12);
      expect(tracker.message, contains('Reintentaremos'));
      failConnection = false;
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(presence, 2);
      expect(tracker.message, contains('Disponible para recibir'));
      tracker.setAvailable(false);
      expect(tracker.running, isFalse);
      await tester.pump(const Duration(seconds: 20));
      positions.add(sample());
      await tester.pump();
      expect(presence, 2);
    },
  );

  testWidgets(
    'Terminar entrega mantiene presencia solo mientras sigue disponible',
    (tester) async {
      final positions = StreamController<Position>();
      var assigned = true;
      var presence = 0;
      var delivery = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'orders': assigned ? [gpsOrder()] : [],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/presence')) {
          presence++;
        } else {
          delivery++;
        }
        return http.Response('{"accepted":true}', 200);
      });
      final tracker = CourierGpsTracker(
        repository: () async =>
            CourierOrderRepository(ApiClient(client: client)),
        positionSource: (_) async => positions.stream,
        onAssignmentsChanged: () {},
      );
      addTearDown(tracker.dispose);
      addTearDown(positions.close);
      addTearDown(client.close);
      tracker.setAvailable(true);
      tracker.setOrders({1});
      await tracker.start();
      positions.add(sample());
      await tester.pumpAndSettle();
      expect(delivery, 1);
      assigned = false;
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(delivery, 1);
      expect(presence, 2);
      expect(tracker.running, isTrue);
      tracker.setAvailable(false);
      expect(tracker.running, isFalse);
    },
  );

  testWidgets(
    'Sin permiso no hay captura; el reintento explícito puede iniciar y detener GPS',
    (tester) async {
      final positions = StreamController<Position>();
      var attempts = 0;
      final tracker = CourierGpsTracker(
        repository: () async =>
            throw StateError('No debería enviar sin una posición'),
        positionSource: (ask) async {
          attempts++;
          if (!ask) {
            throw ApiException('Concedé el permiso de ubicación.');
          }
          return positions.stream;
        },
        onAssignmentsChanged: () {},
      );
      addTearDown(tracker.dispose);
      addTearDown(positions.close);
      tracker.setOrders({1});
      await tracker.start();
      expect(tracker.running, isFalse);
      expect(tracker.message, contains('permiso'));
      await tracker.start(ask: true);
      expect(tracker.running, isTrue);
      expect(attempts, 2);
      tracker.setOrders({});
      expect(tracker.running, isFalse);
    },
  );

  testWidgets(
    'GPS no envía puntos imprecisos y se detiene al desaparecer la entrega',
    (tester) async {
      final positions = StreamController<Position>();
      var assigned = true;
      var patches = 0;
      var changed = 0;
      final client = MockClient((request) async {
        if (request.method == 'PATCH') {
          patches++;
          expect(jsonDecode(request.body)['latitude'], 14.15);
          return http.Response('{"accepted":true}', 200);
        }
        return http.Response(
          jsonEncode({
            'orders': assigned ? [gpsOrder()] : [],
          }),
          200,
        );
      });
      final tracker = CourierGpsTracker(
        repository: () async =>
            CourierOrderRepository(ApiClient(client: client)),
        positionSource: (_) async => positions.stream,
        onAssignmentsChanged: () => changed++,
      );
      addTearDown(tracker.dispose);
      addTearDown(positions.close);
      addTearDown(client.close);
      tracker.setOrders({1});
      await tracker.start();
      positions.add(sample(accuracy: 200));
      await tester.pump();
      expect(patches, 0);
      positions.add(
        sample(time: DateTime.now().subtract(const Duration(minutes: 5))),
      );
      await tester.pump();
      expect(patches, 0);
      positions.add(sample());
      await tester.pumpAndSettle();
      expect(patches, 1);
      expect(tracker.running, isTrue);
      assigned = false;
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(tracker.running, isFalse);
      expect(changed, 1);
      positions.add(sample());
      await tester.pump();
      expect(patches, 1);
    },
  );

  testWidgets(
    'Cerrar seguimiento mientras carga no envía una posición pendiente',
    (tester) async {
      final positions = StreamController<Position>();
      final response = Completer<http.Response>();
      var patches = 0;
      final client = MockClient((request) async {
        if (request.method == 'PATCH') {
          patches++;
          return http.Response('{}', 200);
        }
        return response.future;
      });
      final tracker = CourierGpsTracker(
        repository: () async =>
            CourierOrderRepository(ApiClient(client: client)),
        positionSource: (_) async => positions.stream,
        onAssignmentsChanged: () {},
      );
      addTearDown(tracker.dispose);
      addTearDown(positions.close);
      addTearDown(client.close);
      tracker.setOrders({1});
      await tracker.start();
      positions.add(sample());
      await tester.pump();
      tracker.setOrders({});
      response.complete(
        http.Response(
          jsonEncode({
            'orders': [gpsOrder()],
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(patches, 0);
      expect(tracker.running, isFalse);
    },
  );
}
