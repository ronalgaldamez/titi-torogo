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
    'Mi local carga categorías, conserva selección ante error y guarda sin modificar el estado',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      var fail = true;
      var selected = [1];
      final categories = [
        {'id': 1, 'name': 'Pupusas'},
        {'id': 2, 'name': 'Mariscos'},
      ];
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test');
        if (request.url.path.endsWith('/categories')) {
          if (request.method == 'PUT') {
            expect(jsonDecode(request.body), {
              'category_ids': [1, 2],
            });
            if (fail) {
              return http.Response('{"message":"No se pudo guardar"}', 503);
            }
            selected = [1, 2];
            return http.Response('{}', 200);
          }
          return http.Response(
            jsonEncode({'categories': categories, 'selected_ids': selected}),
            200,
          );
        }
        expect(request.method, 'GET');
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
              'estimated_delivery_minutes': 30,
              'food_categories': categories
                  .where((c) => selected.contains(c['id']))
                  .toList(),
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
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('local-categories')),
          150,
        );
        await tester.tap(find.byKey(const ValueKey('local-categories')));
        await tester.pumpAndSettle();
        final first = find.byKey(const ValueKey('local-category-1'));
        final second = find.byKey(const ValueKey('local-category-2'));
        expect(tester.widget<CheckboxListTile>(first).value, isTrue);
        await tester.tap(second);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Guardar categorías'));
        await tester.pumpAndSettle();
        expect(find.text('No se pudo guardar'), findsOneWidget);
        expect(tester.widget<CheckboxListTile>(second).value, isTrue);
        fail = false;
        await tester.tap(find.text('Guardar categorías'));
        await tester.pumpAndSettle();
        expect(find.text('Categorías de mi local'), findsOneWidget);
        expect(find.text('Pupusas · Mariscos'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );
}
