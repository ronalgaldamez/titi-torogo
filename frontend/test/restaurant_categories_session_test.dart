import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/restaurante/dashboard/dashboard_screen.dart';
import 'package:torogo/features/restaurante/menu/categories_screen.dart';

void main() {
  Future<void> showScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Categorías conserva crear, renombrar y borrar con el nuevo panel',
    (tester) async {
      String? name;
      final writes = <String>[];
      final client = MockClient((request) async {
        if (request.method == 'POST' || request.method == 'PUT') {
          writes.add(request.method);
          name =
              (jsonDecode(request.body) as Map<String, dynamic>)['name']
                  as String;
          return http.Response(
            jsonEncode({
              'category': {'id': 1, 'name': name, 'sort_order': 0},
            }),
            200,
          );
        }
        if (request.method == 'DELETE') {
          writes.add('DELETE');
          name = null;
          return http.Response('{}', 200);
        }
        return http.Response(
          jsonEncode({
            'categories': [
              if (name != null)
                {'id': 1, 'name': name, 'sort_order': 0, 'products': []},
            ],
            'uncategorized': [],
          }),
          200,
        );
      });
      addTearDown(client.close);
      await http.runWithClient(() async {
        await showScreen(tester, const CategoriesScreen(categories: []));
        expect(find.text('Ordená tu menú a tu manera.'), findsOneWidget);
        final add = find.widgetWithText(FilledButton, '+  Nueva categoría');
        await tapVisible(tester, add);
        expect(find.byType(BottomSheet), findsOneWidget);
        await tapVisible(tester, find.text('Guardar categoría'));
        expect(find.text('Poné un nombre.'), findsOneWidget);
        expect(writes, isEmpty);
        await tester.enterText(find.byType(TextField), '  Postres  ');
        await tapVisible(tester, find.text('Guardar categoría'));
        expect(find.text('Postres'), findsOneWidget);
        expect(writes, ['POST']);
        await tapVisible(tester, find.text('Postres'));
        await tester.enterText(find.byType(TextField), 'Bebidas');
        await tapVisible(tester, find.text('Guardar categoría'));
        expect(find.text('Bebidas'), findsOneWidget);
        await tapVisible(tester, find.byTooltip('Borrar categoría'));
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(writes, ['POST', 'PUT']);
        await tapVisible(tester, find.byTooltip('Borrar categoría'));
        await tester.tap(find.text('Borrar'));
        await tester.pumpAndSettle();
        expect(writes, ['POST', 'PUT', 'DELETE']);
        expect(find.text('Ordená tu menú a tu manera.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );

  testWidgets(
    'Mi local confirma salida sin cerrar el negocio ni modificar pedidos',
    (tester) async {
      var logouts = 0;
      final methods = <String>[];
      final client = MockClient((request) async {
        methods.add(request.method);
        return http.Response(
          jsonEncode({
            'restaurant': {
              'id': 1,
              'name': 'Baruk',
              'address': 'Tejutla',
              'latitude': 14.1,
              'longitude': -89.1,
              'is_open': true,
              'is_busy': false,
              'estimated_delivery_minutes': 30,
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      await http.runWithClient(() async {
        await showScreen(tester, DashboardScreen(onLogout: () => logouts++));
        final logout = find.byKey(const ValueKey('restaurant-local-logout'));
        await tester.scrollUntilVisible(
          logout,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tapVisible(tester, logout);
        expect(
          find.text(
            'Salir de tu cuenta no cierra tu local ni cambia sus pedidos.',
          ),
          findsOneWidget,
        );
        await tapVisible(tester, find.text('Me quedo aquí'));
        expect(logouts, 0);
        await tapVisible(tester, logout);
        await tapVisible(tester, find.text('Sí, cerrar sesión'));
        expect(logouts, 1);
        expect(methods, ['GET']);
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );
}
