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
        final categoriesEntry = find.byKey(const ValueKey('local-categories'));
        for (
          var attempt = 0;
          attempt < 30 && categoriesEntry.hitTestable().evaluate().isEmpty;
          attempt++
        ) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -180),
          );
          await tester.pumpAndSettle();
        }
        expect(categoriesEntry.hitTestable(), findsOneWidget);
        await tester.tap(categoriesEntry);
        await tester.pumpAndSettle();
        final first = find.byKey(const ValueKey('local-category-1'));
        final second = find.byKey(const ValueKey('local-category-2'));
        expect(tester.widget<Semantics>(first).properties.checked, isTrue);
        expect(find.text('Una categoría seleccionada'), findsOneWidget);
        final dialogScroll = find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Scrollable),
            )
            .first;
        for (
          var attempt = 0;
          attempt < 30 && second.hitTestable().evaluate().isEmpty;
          attempt++
        ) {
          await tester.drag(dialogScroll, const Offset(0, -100));
          await tester.pumpAndSettle();
        }
        expect(second.hitTestable(), findsOneWidget);
        await tester.tap(second);
        await tester.pumpAndSettle();
        expect(find.text('2 categorías seleccionadas'), findsOneWidget);
        await tester.tap(find.text('Guardar selección'));
        await tester.pumpAndSettle();
        expect(find.text('No se pudo guardar'), findsOneWidget);
        expect(tester.widget<Semantics>(second).properties.checked, isTrue);
        fail = false;
        await tester.tap(find.text('Guardar selección'));
        await tester.pumpAndSettle();
        expect(find.text('Lo que se cocina aquí.'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('local-category-tag-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('local-category-tag-2')),
          findsOneWidget,
        );
        expect(find.text('Pupusas'), findsOneWidget);
        expect(find.text('Mariscos'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );
}
