import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/cliente/direcciones/address_form_screen.dart';
import 'package:torogo/models/address.dart';

void main() {
  testWidgets('El formulario conserva coordenadas y validaciones al editar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const AddressFormScreen(
          address: Address(
            id: 1,
            label: 'Casa',
            address: 'Calle principal',
            latitude: 14.10175,
            longitude: -89.15859,
            isDefault: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nombre de la dirección'), findsOneWidget);
    expect(find.text('Referencia (opcional)'), findsOneWidget);
    expect(find.text('14.10175, -89.15859'), findsNothing);
    await tester.tap(find.text('Ver coordenadas'));
    await tester.pumpAndSettle();
    expect(find.text('14.10175, -89.15859'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.pumpAndSettle();
    expect(
      find.text('Poné un nombre para reconocerla (Casa, Trabajo...).'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
