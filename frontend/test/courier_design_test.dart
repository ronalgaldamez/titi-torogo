import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/features/motorizado/courier_screen.dart';

void main() {
  testWidgets(
    'Diseño del motorizado conserva disponibilidad, filtros y cierre de sesión en pantalla pequeña',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
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
      var available = false;
      var rejectAvailability = true;
      var logouts = 0;
      final historyRequests = <Map<String, String>>[];
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/courier/availability')) {
          if (rejectAvailability) {
            return http.Response(
              '{"message":"No se pudo cambiar disponibilidad"}',
              503,
            );
          }
          available =
              (jsonDecode(request.body) as Map<String, dynamic>)['is_available']
                  as bool;
          return http.Response(
            jsonEncode({
              'user': {'is_available': available},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/me')) {
          return http.Response(
            jsonEncode({
              'id': 1,
              'name': 'Motorizado de pruebas',
              'email': 'motorizado.pruebas@torogo.local',
              'role': 'courier',
              'role_label': 'Motorizado',
              'is_available': available,
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/courier/summary')) {
          return http.Response(
            '{"date":"2026-11-07","earnings":"3.30","deliveries":2}',
            200,
          );
        }
        if (request.url.path.endsWith('/courier/history')) {
          historyRequests.add(request.url.queryParameters);
          return http.Response(
            '{"orders":[],"summary":{"earnings":"3.30","deliveries":2},"from":"2026-11-01","to":"2026-11-07","next_page":null}',
            200,
          );
        }
        return http.Response('{"orders":[]}', 200);
      });
      addTearDown(client.close);

      Future<void> tapVisible(Finder target) async {
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            target,
            150,
            scrollable: find.byType(Scrollable).last,
          );
        }
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'Después de tocar $target',
        );
      }

      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: CourierScreen(onLogout: () => logouts++),
          ),
        );
        await tester.tap(find.byTooltip('Actualizar'));
        await tester.pumpAndSettle();
        expect(find.text('Mi día.'), findsOneWidget);
        expect(find.text(r'$3.30'), findsOneWidget);
        await tapVisible(find.byType(Switch));
        expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
        rejectAvailability = false;
        await tapVisible(find.byType(Switch));
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
        expect(available, isTrue);
        await tapVisible(find.text('Historial'));
        expect(find.text('Tus entregas.'), findsOneWidget);
        await tapVisible(find.text('Cancelados'));
        expect(historyRequests.last['status'], 'cancelled');
        await tapVisible(find.byType(DropdownButtonFormField<String>));
        await tapVisible(find.text('Últimos 7 días').last);
        expect(historyRequests.last['period'], 'week');
        await tapVisible(find.text('Perfil'));
        await tapVisible(find.text('Información personal'));
        expect(find.text('CORREO ELECTRÓNICO'), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        await tapVisible(find.text('Volver al perfil'));
        await tapVisible(find.text('Cerrar sesión'));
        await tapVisible(find.text('Me quedo aquí'));
        expect(logouts, 0);
        await tapVisible(find.text('Cerrar sesión'));
        await tapVisible(find.text('Sí, cerrar sesión'));
        expect(logouts, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );
}
