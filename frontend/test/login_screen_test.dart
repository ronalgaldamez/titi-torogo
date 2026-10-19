import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/auth/login_screen.dart';

void main() {
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
      final submit = find.widgetWithText(FilledButton, 'Vamos a lo rico');
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
