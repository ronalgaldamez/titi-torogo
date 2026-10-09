import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/cliente/home/home_screen.dart';
import 'package:torogo/features/cliente/home/widgets/restaurant_card.dart';
import 'package:torogo/models/restaurant.dart';

void main() {
  testWidgets(
    'Inicio busca restaurantes, conserva pedidos y distingue funciones pendientes',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues(<String, Object>{
        'torogo_token': 'test',
      });
      const channel = MethodChannel('flutter.baseflow.com/geolocator');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      int loads = 0;
      int logouts = 0;
      bool failLoad = false;
      bool outside = false;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/me')) {
          return http.Response(
            jsonEncode({
              'id': 1,
              'name': 'Cliente Demo',
              'email': 'cliente@torogo.local',
              'role': 'client',
              'role_label': 'Cliente',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/orders')) {
          return http.Response('{"orders":[]}', 200);
        }
        expect(request.url.path.endsWith('/restaurants'), isTrue);
        expect(request.url.queryParameters.containsKey('latitude'), isTrue);
        loads++;
        if (failLoad) {
          return http.Response('{"message":"Sin conexión"}', 503);
        }
        return http.Response(
          jsonEncode(<String, dynamic>{
            'zone': outside
                ? null
                : <String, dynamic>{
                    'id': 1,
                    'name': 'Zona de prueba',
                    'delivery_fee': '2.00',
                    'courier_fee': '1.50',
                    'platform_fee': '0.50',
                  },
            'restaurants': <dynamic>[
              for (final name in <String>['Los Tres Cerditos', 'Urban Pizza'])
                <String, dynamic>{
                  'id': name == 'Urban Pizza' ? 2 : 1,
                  'name': name,
                  'address': 'Centro',
                  'latitude': 14.1,
                  'longitude': -89.1,
                  'is_open': true,
                  'is_busy': false,
                  'estimated_delivery_minutes': 30,
                  'delivery_fee': '2.00',
                  'distance_km': 0.9,
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
            home: HomeScreen(
              onLogout: () async {
                logouts++;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Zona de prueba'), findsOneWidget);
        expect(find.text('Categorías · Próximamente'), findsOneWidget);
        final initialLoads = loads;
        await tester.enterText(find.byType(TextField), 'URBAN');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Urban Pizza'),
          250,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Urban Pizza'), findsOneWidget);
        expect(find.text('Los Tres Cerditos'), findsNothing);
        expect(loads, initialLoads);
        await tester.drag(find.byType(ListView), const Offset(0, 1000));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'No existe');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('No encontramos ese restaurante'),
          250,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('No encontramos ese restaurante'), findsOneWidget);
        await tester.tap(find.text('Perfil'));
        await tester.pumpAndSettle();
        expect(find.text('Cliente Demo'), findsOneWidget);
        expect(find.text('Cambiar avatar'), findsOneWidget);
        await tester.ensureVisible(find.text('Cerrar sesión'));
        await tester.tap(find.text('Cerrar sesión'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(logouts, 0);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byTooltip('Actualizar'), findsOneWidget);
        await tester.tap(find.text('Pedidos'));
        await tester.pumpAndSettle();
        expect(find.text('Mis pedidos'), findsOneWidget);
        await tester.tap(find.text('Inicio'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Notificaciones · Próximamente'));
        await tester.pumpAndSettle();
        expect(
          find.text('Próximamente. Esta función todavía no está disponible.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();
        failLoad = true;
        await tester.tap(find.byTooltip('Actualizar'));
        await tester.pumpAndSettle();
        expect(find.text('No pudimos cargar los restaurantes'), findsOneWidget);
        failLoad = false;
        outside = true;
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(find.text('Todavia no llegamos ahi'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );

  testWidgets(
    'Tarjeta compacta admite textos grandes y conserva tarifa y apertura',
    (tester) async {
      tester.view.physicalSize = const Size(320, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int opened = 0;
      const restaurant = Restaurant(
        id: 1,
        name: 'Restaurante con un nombre bastante largo',
        address: 'Dirección larga del restaurante',
        latitude: 14.1,
        longitude: -89.1,
        isOpen: true,
        isBusy: true,
        estimatedDeliveryMinutes: 45,
        distanceKm: 0.9,
        deliveryFee: '2.00',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: ListView(
                children: <Widget>[
                  RestaurantCard(
                    restaurant: restaurant,
                    onTap: () {
                      opened++;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(r'Envío $2.00'), findsOneWidget);
      expect(find.text('Muy ocupado'), findsOneWidget);
      await tester.tap(find.text(restaurant.name));
      expect(opened, 1);
    },
  );
}
