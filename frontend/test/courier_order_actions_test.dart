import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/motorizado/courier_screen.dart';

void main() {
  testWidgets(
    'Las acciones identifican cada pedido, permanecen visibles y conservan la confirmación',
    (tester) async {
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final gps = Completer<bool>();
      const channel = MethodChannel('flutter.baseflow.com/geolocator');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) => gps.future,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      int mutations = 0;
      String pickupStatus = 'ready';
      Map<String, dynamic> order(int id, String status) => {
        'id': id,
        'status': status,
        'status_label': status == 'ready' ? 'Listo para recoger' : 'En camino',
        'is_active': true,
        'pickup_pin_required': id == 21 && status == 'ready',
        'restaurant': {
          'id': 7,
          'name': 'Restaurante de prueba',
          'address': 'Centro',
          'latitude': 14.1,
          'longitude': -89.1,
        },
        'delivery': {
          'address':
              'Dirección larga para comprobar el desplazamiento del contenido del pedido',
          'reference': 'Portón azul',
          'latitude': 14.2,
          'longitude': -89.2,
        },
        'items': [],
        'subtotal': '4.00',
        'delivery_fee': '2.00',
        'courier_fee': '1.50',
        'platform_fee': '0.50',
        'total': '6.00',
        'payment_method': 'cash',
      };
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
        if (request.method != 'GET') mutations++;
        if (request.method == 'PATCH' &&
            request.url.path.endsWith('/courier/orders/21')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['status'], 'picked_up');
          if (body['pickup_pin'] != '012345') {
            return http.Response('{"message":"PIN incorrecto"}', 422);
          }
          pickupStatus = 'picked_up';
          return http.Response(
            jsonEncode({'order': order(21, pickupStatus)}),
            200,
          );
        }
        if (request.url.path.endsWith('/me')) {
          return http.Response('{"is_available":false}', 200);
        }
        if (request.url.path.endsWith('/courier/summary')) {
          return http.Response(
            '{"date":"2026-10-07","deliveries":0,"earnings":"0.00"}',
            200,
          );
        }
        if (request.url.path.endsWith('/courier/orders')) {
          return http.Response(
            jsonEncode({
              'orders': [order(21, pickupStatus), order(22, 'picked_up')],
            }),
            200,
          );
        }
        fail('Petición inesperada: ${request.url}');
      });
      addTearDown(client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const CourierScreen(onLogout: null),
          ),
        );
        await tester.tap(find.byTooltip('Actualizar'));
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        final pickup = find.byKey(const ValueKey('courier-action-21'));
        final delivery = find.byKey(const ValueKey('courier-action-22'));
        expect(pickup.hitTestable(), findsOneWidget);
        expect(delivery.hitTestable(), findsOneWidget);
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pump();
        expect(delivery.hitTestable(), findsOneWidget);
        await tester.tap(pickup);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('PIN de recogida · #21'), findsOneWidget);
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.text('Confirmar recogida').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Confirmar recogida'));
        await tester.pump();
        expect(find.text('Ingresá los 6 dígitos del código.'), findsOneWidget);
        expect(mutations, 0);
        await tester.tap(find.text('Cancelar'));
        tester.view.resetViewInsets();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(pickup);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(find.byType(TextFormField), '111111');
        await tester.tap(find.text('Confirmar recogida'));
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(find.text('PIN incorrecto'), findsOneWidget);
        expect(mutations, 1);
        await tester.tap(pickup);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.enterText(find.byType(TextFormField), '012345');
        await tester.tap(find.text('Confirmar recogida'));
        for (int i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(pickupStatus, 'picked_up');
        expect(mutations, 2);
        await tester.pump(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester.getBottomRight(delivery).dy,
          lessThanOrEqualTo(tester.getTopLeft(find.byType(NavigationBar)).dy),
        );
        await tester.ensureVisible(delivery);
        await tester.tap(delivery);
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          find.text('¿Marcar el pedido #22 como entregado?'),
          findsOneWidget,
        );
        expect(
          find.text(
            r'Se cobra $6.00 en efectivo al cliente. Después no se puede deshacer.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancelar'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(mutations, 2);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );
}
