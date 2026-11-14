import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/location.dart';
import 'package:torogo/features/motorizado/courier_screen.dart';
import 'package:torogo/models/order.dart';

Map<String, dynamic> orderResponse(String status) => <String, dynamic>{
  'id': 20,
  'status': status,
  'status_label': 'Listo para recoger',
  'is_active': true,
  'restaurant': <String, dynamic>{
    'id': 7,
    'name': 'Restaurante',
    'address': 'Centro',
    'latitude': 14.1,
    'longitude': -89.1,
  },
  'delivery': <String, dynamic>{
    'address': 'Casa',
    'latitude': 14.2,
    'longitude': -89.2,
  },
  'items': <dynamic>[],
  'subtotal': '4.00',
  'delivery_fee': '2.00',
  'courier_fee': '1.50',
  'platform_fee': '0.50',
  'total': '6.00',
  'payment_method': 'cash',
};

void main() {
  test('La navegación cambia del restaurante al cliente al recoger', () {
    final data = orderResponse('ready');
    const origin = Place(latitude: 14.2, longitude: -89.2, isReal: true);
    final Uri pickup = courierDirectionsUri(
      Order.fromJson(data),
      origin: origin,
    );
    expect(pickup.host, 'www.google.com');
    expect(pickup.path, '/maps/dir/');
    expect(pickup.queryParameters['api'], '1');
    expect(pickup.queryParameters['destination'], '14.1,-89.1');
    expect(pickup.queryParameters['origin'], '14.2,-89.2');
    data['status'] = 'picked_up';
    final Uri delivery = courierDirectionsUri(
      Order.fromJson(data),
      origin: origin,
    );
    expect(delivery.queryParameters['destination'], '14.2,-89.2');
    expect(
      delivery.queryParameters['origin'],
      delivery.queryParameters['destination'],
    );
    expect(
      courierDirectionsUri(
        Order.fromJson(data),
        origin: LocationService.fallback,
      ),
      isA<Uri>().having(
        (uri) => uri.queryParameters['origin'],
        'origin',
        isNull,
      ),
    );
    expect(
      courierDirectionsUri(
        Order.fromJson(data),
        origin: const Place(
          latitude: 14.2,
          longitude: -89.2,
          isReal: true,
          accuracyMeters: 200,
        ),
      ),
      isA<Uri>().having(
        (uri) => uri.queryParameters['origin'],
        'origin',
        isNull,
      ),
    );
  });

  for (final status in ['ready', 'picked_up']) {
    for (final gps in ['recent', 'stale', 'missing']) {
      testWidgets('El botón abre el destino de la API ($status, GPS $gps)', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
        tester.view.physicalSize = const Size(900, 2200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final messenger = tester.binding.defaultBinaryMessenger;
        const locationChannel = MethodChannel(
          'flutter.baseflow.com/geolocator',
        );
        const updatesChannel = EventChannel(
          'flutter.baseflow.com/geolocator_updates',
        );
        const launcherChannel = MethodChannel(
          'plugins.flutter.io/url_launcher',
        );
        final initialLocation = Completer<bool>();
        var serviceChecks = 0;
        var currentPositionReads = 0;
        MockStreamHandlerEventSink? positions;
        final opened = <Uri>[];
        messenger.setMockMethodCallHandler(locationChannel, (call) async {
          switch (call.method) {
            case 'isLocationServiceEnabled':
              // Evita abrir Reverb; la pantalla se carga con Actualizar.
              return serviceChecks++ == 0 ? initialLocation.future : true;
            case 'checkPermission':
              return 3;
            case 'getCurrentPosition':
              currentPositionReads++;
              throw PlatformException(code: 'LOCATION_UPDATE_FAILURE');
            default:
              throw StateError('Llamada GPS inesperada: ${call.method}');
          }
        });
        messenger.setMockStreamHandler(
          updatesChannel,
          MockStreamHandler.inline(
            onListen: (_, events) {
              positions = events;
            },
          ),
        );
        messenger.setMockMethodCallHandler(launcherChannel, (call) async {
          expect(call.method, 'launch');
          opened.add(Uri.parse((call.arguments as Map)['url'] as String));
          return true;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(locationChannel, null);
          messenger.setMockStreamHandler(updatesChannel, null);
          messenger.setMockMethodCallHandler(launcherChannel, null);
        });
        final client = MockClient((request) async {
          if (request.url.host == 'tile.openstreetmap.org') {
            return http.Response.bytes(
              base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
              ),
              200,
              headers: {'content-type': 'image/png'},
            );
          }
          if (request.url.path.endsWith('/me')) {
            return http.Response('{"is_available":false}', 200);
          }
          if (request.url.path.endsWith('/courier/summary')) {
            return http.Response(
              '{"date":"2026-11-13","deliveries":0,"earnings":"0.00"}',
              200,
            );
          }
          if (request.url.path.endsWith('/courier/orders')) {
            return http.Response(
              jsonEncode({
                'orders': [orderResponse(status)],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/location')) {
            return http.Response('{"accepted":true}', 200);
          }
          throw StateError('Petición inesperada: ${request.url}');
        });
        addTearDown(client.close);
        await http.runWithClient(() async {
          await tester.pumpWidget(
            const MaterialApp(home: CourierScreen(onLogout: null)),
          );
          await tester.tap(find.byTooltip('Actualizar'));
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 10));
          }
          final activateGps = find.byTooltip('Activar seguimiento GPS');
          if (activateGps.evaluate().isNotEmpty) {
            await tester.ensureVisible(activateGps);
            await tester.tap(activateGps);
            await tester.pump();
          }
          expect(positions, isNotNull);
          if (gps != 'missing') {
            positions!.success({
              'latitude': 14.2,
              'longitude': -89.2,
              'accuracy': 12.0,
              'timestamp': DateTime.now()
                  .subtract(
                    gps == 'stale'
                        ? const Duration(seconds: 31)
                        : Duration.zero,
                  )
                  .millisecondsSinceEpoch,
            });
            await tester.pump();
          }
          final button = find.text(
            status == 'picked_up'
                ? 'Cómo llegar al cliente'
                : 'Cómo llegar al restaurante',
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pump();
          expect(opened, hasLength(1));
          expect(
            opened.single.queryParameters['destination'],
            status == 'picked_up' ? '14.2,-89.2' : '14.1,-89.1',
          );
          expect(
            opened.single.queryParameters['origin'],
            gps == 'recent' ? '14.2,-89.2' : isNull,
          );
          expect(currentPositionReads, 0);
          expect(
            opened.single.queryParameters['destination'],
            isNot(
              '${LocationService.fallback.latitude},${LocationService.fallback.longitude}',
            ),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }, () => client);
      });
    }
  }
}
