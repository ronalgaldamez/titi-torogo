import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/shared/account_profile.dart';

Future<void> revealProfileControl(WidgetTester tester, Finder control) async {
  if (control.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      control,
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(control);
  await tester.pumpAndSettle();
  expect(control.hitTestable(), findsOneWidget);
}

void main() {
  testWidgets(
    'Perfil valida, conserva los datos tras un error y guarda al reintentar',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      var name = 'Cliente Demo';
      String? phone;
      var fail = true;
      var saves = 0;
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test');
        if (request.method == 'PATCH') {
          saves++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.keys.toSet(), {'name', 'phone'});
          expect(body['name'], 'Ronald Galdámez');
          expect(body['phone'], '+503 7000-1234');
          if (fail) {
            return http.Response('{"message":"No se pudo guardar"}', 503);
          }
          name = body['name'] as String;
          phone = '70001234';
        }
        return http.Response(
          jsonEncode({
            'id': 1,
            'name': name,
            'phone': phone,
            'email': 'cliente@torogo.local',
            'role': 'client',
            'role_label': 'Cliente',
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
            home: Scaffold(body: AccountProfile(onLogout: () {})),
          ),
        );
        await tester.pumpAndSettle();
        await revealProfileControl(tester, find.text('Información personal'));
        await tester.tap(find.text('Información personal'));
        await tester.pumpAndSettle();
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), ' ');
        await tester.enterText(fields.at(1), '123');
        final save = find.text('Guardar cambios');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(saves, 0);
        expect(find.text('Escribí tu nombre.'), findsOneWidget);
        expect(
          find.text('Usá 8 dígitos que comiencen con 2, 6 o 7.'),
          findsOneWidget,
        );
        await tester.ensureVisible(fields.at(0));
        await tester.enterText(fields.at(0), '  Ronald Galdámez  ');
        await tester.ensureVisible(fields.at(1));
        await tester.enterText(fields.at(1), '+503 7000-1234');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.text('No se pudo guardar'), findsOneWidget);
        expect(
          tester.widget<TextFormField>(fields.at(0)).controller!.text,
          '  Ronald Galdámez  ',
        );
        expect(
          tester.widget<TextFormField>(fields.at(1)).controller!.text,
          '+503 7000-1234',
        );
        fail = false;
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(saves, 2);
        expect(find.text('Tus datos se guardaron.'), findsOneWidget);
        expect(find.text('Ronald\nGaldámez.'), findsOneWidget);
        await revealProfileControl(tester, find.text('Información personal'));
        await tester.tap(find.text('Información personal'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).at(1))
              .controller!
              .text,
          '70001234',
        );
        expect(
          tester.widget<TextField>(find.byType(TextField).last).readOnly,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }, () => client);
    },
  );

  testWidgets('Perfil evita envíos repetidos mientras guarda', (tester) async {
    SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
    final pending = Completer<http.Response>();
    var saves = 0;
    const json =
        '{"id":1,"name":"Cliente Demo","phone":null,"email":"cliente@torogo.local","role":"client","role_label":"Cliente"}';
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        saves++;
        return pending.future;
      }
      return http.Response(json, 200);
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: AccountProfile(onLogout: () {})),
        ),
      );
      await tester.pumpAndSettle();
      await revealProfileControl(tester, find.text('Información personal'));
      await tester.tap(find.text('Información personal'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Volver al perfil'),
            )
            .onPressed,
        isNull,
      );
      pending.complete(http.Response(json, 200));
      await tester.pumpAndSettle();
      expect(find.text('Tus datos se guardaron.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }, () => client);
  });

  testWidgets('El avatar se conserva por cuenta y el correo es de consulta', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
    int userId = 1;
    final client = MockClient(
      (request) async => http.Response(
        '{"id":$userId,"name":"Cliente Demo","email":"cliente@torogo.local","role":"client","role_label":"Cliente"}',
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
            home: Scaffold(body: AccountProfile(onLogout: () {})),
          ),
        );
        await tester.pumpAndSettle();
      }

      await openProfile();
      await revealProfileControl(tester, find.text('Elegí tu avatar'));
      await tester.tap(find.text('Elegí tu avatar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avatar 2'));
      await tester.pumpAndSettle();
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getInt('torogo_client_avatar_1'), isNull);
      await tester.ensureVisible(find.text('Usar este avatar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar este avatar'));
      await tester.pumpAndSettle();
      expect(preferences.getInt('torogo_client_avatar_1'), 2);
      await openProfile();
      expect(find.text('CD'), findsNothing);
      expect(
        (tester.widget<Image>(find.byType(Image)).image as AssetImage)
            .assetName,
        'assets/avatars/avatar_2.png',
      );
      await revealProfileControl(tester, find.text('Información personal'));
      await tester.tap(find.text('Información personal'));
      await tester.pumpAndSettle();
      expect(find.text('CORREO ELECTRÓNICO'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      final email = tester.widget<TextField>(find.byType(TextField).last);
      expect(email.readOnly, isTrue);
      await tester.ensureVisible(find.text('Volver al perfil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver al perfil'));
      await tester.pumpAndSettle();
      userId = 2;
      await openProfile();
      expect(find.text('CD'), findsOneWidget);
      await revealProfileControl(tester, find.text('Elegí tu avatar'));
      await tester.tap(find.text('Elegí tu avatar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avatar 1'));
      await tester.pumpAndSettle();
      await revealProfileControl(tester, find.text('Cancelar'));
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(preferences.getInt('torogo_client_avatar_2'), isNull);
      expect(preferences.getInt('torogo_client_avatar_1'), 2);
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
              '{"id":1,"name":"Cliente Demo","email":"cliente@torogo.local","role":"client","role_label":"Cliente"}',
              200,
            );
    });
    addTearDown(client.close);
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: AccountProfile(onLogout: () => logout = true)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sin conexión'), findsOneWidget);
      await tester.tap(find.text('Cerrar sesión'));
      expect(logout, isTrue);
      fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Cliente\nDemo.'), findsOneWidget);
      expect(find.text('CD'), findsOneWidget);
      expect(find.text('cliente@torogo.local'), findsOneWidget);
      expect(find.text('Sin conexión'), findsNothing);
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
