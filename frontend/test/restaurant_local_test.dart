import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/restaurante/dashboard/dashboard_screen.dart';

void main() {
  testWidgets(
    'Mi local conserva estados, tiempo real del servidor y errores al guardar',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      var open = true;
      var busy = false;
      var fail = false;
      final client = MockClient((request) async {
        expect(request.url.path.endsWith('/restaurant/status'), isTrue);
        if (request.method == 'PATCH') {
          if (fail) {
            return http.Response('{"message":"No se pudo guardar"}', 503);
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.keys, containsAll(['is_open', 'is_busy']));
          open = body['is_open'] as bool;
          busy = body['is_busy'] as bool;
        }
        return http.Response(
          jsonEncode({
            'restaurant': {
              'id': 1,
              'name': 'Los Tres Cerditos con nombre largo',
              'description': 'Carnes, parrilladas y típicos.',
              'address': 'Centro',
              'latitude': 14.1,
              'longitude': -89.1,
              'is_open': open,
              'is_busy': busy,
              'estimated_delivery_minutes': busy ? 45 : 31,
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const DashboardScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Recibiendo pedidos'), findsOneWidget);
        Future<void> reveal(Finder target) async {
          final scrollable = find.byType(Scrollable).first;
          tester.state<ScrollableState>(scrollable).position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
          await tester.pumpAndSettle();
        }

        await reveal(find.byKey(const ValueKey('local-delivery-time')));
        expect(find.text('31 min'), findsOneWidget);
        Future<void> toggle(String key) async {
          final tile = find.byKey(ValueKey(key));
          await reveal(tile);
          await tester.tap(tile);
          await tester.pumpAndSettle();
        }

        await toggle('local-busy');
        expect(busy, isTrue);
        await reveal(find.text('Abierto y muy ocupado'));
        expect(find.text('Abierto y muy ocupado'), findsOneWidget);
        await reveal(find.byKey(const ValueKey('local-delivery-time')));
        expect(find.text('45 min'), findsOneWidget);
        await toggle('local-open');
        expect(open, isFalse);
        await reveal(find.byKey(const ValueKey('local-busy')));
        expect(
          tester
              .widget<SwitchListTile>(find.byKey(const ValueKey('local-busy')))
              .onChanged,
          isNull,
        );
        expect(find.byKey(const ValueKey('local-delivery-time')), findsNothing);
        await reveal(find.text('Pedidos nuevos pausados'));
        expect(find.text('Pedidos nuevos pausados'), findsOneWidget);
        tester
            .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
            .clearSnackBars();
        await tester.pumpAndSettle();
        fail = true;
        await toggle('local-open');
        expect(open, isFalse);
        expect(
          tester
              .widget<SwitchListTile>(find.byKey(const ValueKey('local-open')))
              .value,
          isFalse,
        );
        expect(find.text('No se pudo guardar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );
  testWidgets('Mi local valida y guarda mínimo y máximo de preparación', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
    var minimum = 30;
    var maximum = 30;
    var saves = 0;
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        saves++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['is_open'], isTrue);
        expect(body['is_busy'], isFalse);
        minimum = body['prep_time_min_minutes'] as int;
        maximum = body['prep_time_max_minutes'] as int;
      }
      return http.Response(
        jsonEncode({
          'restaurant': {
            'id': 1,
            'name': 'Local',
            'address': 'Centro',
            'latitude': 14.1,
            'longitude': -89.1,
            'is_open': true,
            'is_busy': false,
            'estimated_delivery_minutes': maximum,
            'prep_time_min_minutes': minimum,
            'prep_time_max_minutes': maximum,
            'estimated_prep_min_minutes': minimum,
            'estimated_prep_max_minutes': maximum,
          },
        }),
        200,
      );
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const DashboardScreen()),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('edit-preparation')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('edit-preparation')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('prep-minimum')), '25');
      await tester.enterText(find.byKey(const ValueKey('prep-maximum')), '15');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(
        find.text('El máximo debe ser igual o mayor al mínimo.'),
        findsOneWidget,
      );
      expect(saves, 0);
      await tester.enterText(find.byKey(const ValueKey('prep-minimum')), '1');
      await tester.enterText(find.byKey(const ValueKey('prep-maximum')), '30');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Usá entre 10 y 45 minutos.'), findsOneWidget);
      expect(saves, 0);
      await tester.enterText(find.byKey(const ValueKey('prep-minimum')), '10');
      await tester.enterText(find.byKey(const ValueKey('prep-maximum')), '46');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Usá entre 10 y 45 minutos.'), findsOneWidget);
      expect(saves, 0);
      await tester.enterText(find.byKey(const ValueKey('prep-minimum')), '15');
      await tester.enterText(find.byKey(const ValueKey('prep-maximum')), '25');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(find.text('15–25 min'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
