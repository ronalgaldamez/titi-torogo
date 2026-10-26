import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/restaurante/dashboard/dashboard_screen.dart';
import 'package:torogo/features/restaurante/dashboard/restaurant_local_content.dart';
import 'package:torogo/models/restaurant.dart';

void main() {
  testWidgets('El acceso aprobado abre Mi menú y se deshabilita al guardar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var opened = 0;
    Future<void> showLocal(bool saving) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RestaurantLocalContent(
              restaurant: const Restaurant(
                id: 1,
                name: 'Baruk',
                address: 'Tejutla',
                latitude: 14.1,
                longitude: -89.1,
                isOpen: true,
                isBusy: false,
                estimatedDeliveryMinutes: 25,
              ),
              saving: saving,
              onOpen: (_) {},
              onBusy: (_) {},
              onPreparation: () {},
              onCategories: () {},
              onImagesSaved: (_) {},
              onImagesSaving: (_) {},
              onMenu: () => opened++,
            ),
          ),
        ),
      ),
    );
    await showLocal(false);
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('manage-local-menu'));
    for (
      var attempt = 0;
      attempt < 30 && entry.hitTestable().evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
      await tester.pumpAndSettle();
    }
    expect(entry.hitTestable(), findsOneWidget);
    expect(find.text('Tu menú,\ncon tu sello.'), findsOneWidget);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(opened, 1);
    expect(tester.takeException(), isNull);
    await showLocal(true);
    await tester.pump();
    expect(tester.widget<FilledButton>(entry).onPressed, isNull);
    expect(opened, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

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
        expect(find.text('Listos para el próximo antojo.'), findsOneWidget);
        final cover = tester.getRect(
          find.byKey(const ValueKey('local-cover-frame')),
        );
        final logo = tester.getRect(
          find.byKey(const ValueKey('local-logo-frame')),
        );
        expect(cover.left, 0);
        expect(cover.width, 320);
        expect(logo.left, 24);
        expect(logo.top, closeTo(cover.bottom - 24, 0.1));
        expect(find.text('MI NEGOCIO'), findsOneWidget);

        expect(find.text('TU NEGOCIO, A TU MANERA.'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.semanticsLabel == 'Los Tres Cerditos con nombre largo',
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          AppTheme.discoveryBackground,
        );
        expect(tester.takeException(), isNull);

        Future<void> reveal(Finder target) async {
          final scrollable = find.byType(Scrollable).first;
          tester.state<ScrollableState>(scrollable).position.jumpTo(0);
          await tester.pumpAndSettle();
          for (
            var attempt = 0;
            attempt < 30 && target.hitTestable().evaluate().isEmpty;
            attempt++
          ) {
            await tester.drag(scrollable, const Offset(0, -180));
            await tester.pumpAndSettle();
          }
          expect(target.hitTestable(), findsOneWidget);
        }

        await reveal(find.byKey(const ValueKey('local-delivery-time')));
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Text && widget.semanticsLabel == '31 min',
          ),
          findsOneWidget,
        );
        Future<void> toggle(String key) async {
          final tile = find.byKey(ValueKey(key));
          await reveal(tile);
          await tester.tap(tile);
          await tester.pumpAndSettle();
        }

        await toggle('local-busy');
        expect(busy, isTrue);
        await reveal(find.text('A todo fuego, con más tiempo.'));
        expect(find.text('A todo fuego, con más tiempo.'), findsOneWidget);
        await reveal(find.byKey(const ValueKey('local-delivery-time')));
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Text && widget.semanticsLabel == '45 min',
          ),
          findsOneWidget,
        );
        await toggle('local-open');
        expect(open, isFalse);
        await reveal(find.byKey(const ValueKey('local-busy')));
        expect(
          tester
              .widget<Switch>(
                find.descendant(
                  of: find.byKey(const ValueKey('local-busy')),
                  matching: find.byType(Switch),
                ),
              )
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
              .widget<Switch>(
                find.descendant(
                  of: find.byKey(const ValueKey('local-open')),
                  matching: find.byType(Switch),
                ),
              )
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
      final edit = find.byKey(const ValueKey('edit-preparation'));
      for (
        var attempt = 0;
        attempt < 30 && edit.hitTestable().evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      expect(edit.hitTestable(), findsOneWidget);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('prep-minimum')), '25');
      await tester.enterText(find.byKey(const ValueKey('prep-maximum')), '15');
      await tester.tap(find.text('Guardar tiempo'));
      await tester.pumpAndSettle();
      expect(
        find.text('El máximo debe ser igual o mayor al mínimo.'),
        findsOneWidget,
      );
      expect(saves, 0);
      await tester.enterText(find.byKey(const ValueKey('prep-minimum')), '1');
      await tester.enterText(find.byKey(const ValueKey('prep-maximum')), '30');
      await tester.tap(find.text('Guardar tiempo'));
      await tester.pumpAndSettle();
      expect(find.text('Usá entre 10 y 45 minutos.'), findsOneWidget);
      expect(saves, 0);
      await tester.enterText(find.byKey(const ValueKey('prep-minimum')), '10');
      await tester.enterText(find.byKey(const ValueKey('prep-maximum')), '46');
      await tester.tap(find.text('Guardar tiempo'));
      await tester.pumpAndSettle();
      expect(find.text('Usá entre 10 y 45 minutos.'), findsOneWidget);
      expect(saves, 0);
      await tester.enterText(find.byKey(const ValueKey('prep-minimum')), '15');
      await tester.enterText(find.byKey(const ValueKey('prep-maximum')), '25');
      await tester.tap(find.text('Guardar tiempo'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && widget.semanticsLabel == '15–25 min',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
