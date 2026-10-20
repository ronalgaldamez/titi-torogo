import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/api_client.dart';
import 'package:torogo/core/auth_storage.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/auth/auth_repository.dart';
import 'package:torogo/features/auth/login_screen.dart';
import 'package:torogo/models/user.dart';

void main() {
  testWidgets(
    'Registro valida, conserva datos tras error y guarda la sesión sin duplicar envíos',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final storage = AuthStorage();
      final response = Completer<http.Response>();
      var requests = 0;
      User? authenticated;
      final client = MockClient((request) async {
        requests++;
        expect(request.url.path, endsWith('/register'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], 'Ronal');
        expect(body['email'], 'nuevo@example.com');
        expect(body['password_confirmation'], 'clave1234');
        expect(body.containsKey('role'), isFalse);
        if (requests == 1) {
          return http.Response(
            jsonEncode({
              'errors': {
                'email': ['Ese correo ya esta registrado.'],
              },
            }),
            422,
          );
        }
        return response.future;
      });
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: LoginScreen(
            repository: AuthRepository(ApiClient(client: client), storage),
            onAuthenticated: (user) => authenticated = user,
            onSkip: () {},
          ),
        ),
      );
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      Future<void> enter(int index, String value) async {
        await tester.ensureVisible(fields.at(index));
        await tester.enterText(fields.at(index), value);
      }

      Future<void> submit() async {
        final button = find.widgetWithText(FilledButton, 'Crear mi cuenta');
        await tester.pumpAndSettle();
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pump();
      }

      await submit();
      expect(requests, 0);
      expect(find.text('Escribí tu nombre.'), findsOneWidget);
      await enter(0, '  Ronal  ');
      await enter(1, 'nuevo@example.com');
      await enter(2, 'corta');
      await enter(3, 'distinta');
      await submit();
      expect(find.text('Usá al menos 8 caracteres.'), findsOneWidget);
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(requests, 0);
      await enter(2, 'clave1234');
      await enter(3, 'clave1234');
      await submit();
      await tester.pumpAndSettle();
      expect(find.text('Ese correo ya esta registrado.'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(fields.first).controller!.text,
        '  Ronal  ',
      );
      expect(
        tester.widget<TextFormField>(fields.at(2)).controller!.text,
        'clave1234',
      );
      expect(await storage.readToken(), isNull);
      await submit();
      expect(requests, 2);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(requests, 2);
      response.complete(
        http.Response(
          jsonEncode({
            'token': 'test-token',
            'user': {
              'id': 77,
              'name': 'Ronal',
              'email': 'nuevo@example.com',
              'role': 'client',
              'role_label': 'Cliente',
            },
          }),
          201,
        ),
      );
      await tester.pumpAndSettle();
      expect(authenticated?.id, 77);
      expect(await storage.readToken(), 'test-token');
      expect(await storage.readRole(), 'client');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Login conserva validación, contraseña y explorar con teclado en móvil angosto',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      var explored = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: LoginScreen(
            onAuthenticated: (_) => fail('No debe autenticar campos vacíos.'),
            onSkip: () => explored = true,
          ),
        ),
      );
      expect(find.textContaining('Pedí cerca.'), findsOneWidget);
      final submit = find.widgetWithText(FilledButton, 'Puyale, pedí ya');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Escribí tu correo.'), findsOneWidget);
      expect(find.text('Escribí tu contraseña.'), findsOneWidget);
      final password = find.byType(TextFormField).last;
      await tester.ensureVisible(password);
      await tester.enterText(password, 'clave de prueba');
      final visibility = find.byTooltip('Mostrar contraseña');
      await tester.ensureVisible(visibility);
      await tester.tap(visibility);
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        isFalse,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      final explore = find.text('Primero quiero explorar');
      await tester.ensureVisible(explore);
      await tester.tap(explore);
      await tester.pump();
      expect(explored, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
