import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/motorizado/courier_profile.dart';

void main() {
  testWidgets('El avatar se conserva por cuenta y los datos son de consulta', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
    int userId = 1;
    final client = MockClient(
      (request) async => http.Response(
        '{"id":$userId,"name":"Motorizado Demo","email":"moto@torogo.local","role":"courier","role_label":"Motorizado"}',
        200,
      ),
    );
    addTearDown(client.close);
    await http.runWithClient(() async {
      Future<void> openProfile() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: CourierProfile(onLogout: () {})),
          ),
        );
        await tester.pumpAndSettle();
      }

      await openProfile();
      await tester.tap(find.text('Cambiar avatar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avatar 2'));
      await tester.pumpAndSettle();
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('torogo_courier_avatar_1'), 2);
      await openProfile();
      expect(find.text('MD'), findsNothing);
      expect(
        (tester.widget<Image>(find.byType(Image)).image as AssetImage)
            .assetName,
        'assets/avatars/avatar_2.png',
      );
      await tester.tap(find.text('Información personal'));
      await tester.pumpAndSettle();
      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      userId = 2;
      await openProfile();
      expect(find.text('MD'), findsOneWidget);
      await tester.tap(find.text('Cambiar avatar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(preferences.getInt('torogo_courier_avatar_2'), isNull);
      expect(preferences.getInt('torogo_courier_avatar_1'), 2);
      expect(tester.takeException(), isNull);
    }, () => client);
  });

  testWidgets('Perfil recupera un error y mantiene disponible cerrar sesión', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
    bool fail = true;
    bool logout = false;
    final client = MockClient((request) async {
      expect(request.url.path.endsWith('/me'), isTrue);
      expect(request.headers['Authorization'], 'Bearer test');
      return fail
          ? http.Response('{"message":"Sin conexión"}', 503)
          : http.Response(
              '{"id":1,"name":"Motorizado Demo","email":"moto@torogo.local","role":"courier","role_label":"Motorizado"}',
              200,
            );
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: CourierProfile(onLogout: () => logout = true)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin conexión'), findsOneWidget);
      await tester.tap(find.text('Cerrar sesión'));
      expect(logout, isTrue);
      fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Motorizado Demo'), findsOneWidget);
      expect(find.text('MD'), findsOneWidget);
      expect(find.text('moto@torogo.local'), findsOneWidget);
      expect(find.text('Sin conexión'), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
