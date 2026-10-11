import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/cliente/direcciones/addresses_screen.dart';

void main() {
  testWidgets('Mis direcciones mantiene el botón accesible y abre la edición', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'addresses': [
            {
              'id': 1,
              'label': 'Casa con un nombre suficientemente largo',
              'address': 'Aguaje Escondido Cas Valle Nuevo',
              'reference': 'Portón azul',
              'latitude': 14.10175,
              'longitude': -89.15859,
              'is_default': true,
            },
          ],
        }),
        200,
      ),
    );
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
          home: const AddressesScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Predeterminada'), findsOneWidget);
      expect(find.text('Portón azul'), findsOneWidget);
      expect(find.text('Nueva dirección').hitTestable(), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Casa con un nombre suficientemente largo'));
      await tester.pumpAndSettle();
      expect(find.text('Editar dirección'), findsOneWidget);
      expect(
        find.text('Casa con un nombre suficientemente largo'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
