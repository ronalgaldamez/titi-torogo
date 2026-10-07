import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/cliente/carrito/cart_provider.dart';
import 'package:torogo/features/cliente/carrito/cart_sheet.dart';
import 'package:torogo/models/product.dart';

void main() {
  testWidgets(
    'Los controles del carrito tienen 48 px y actualizan cantidades',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        await container
            .read(cartProvider.notifier)
            .add(
              const Product(
                id: 3,
                name: 'Sub de pollo',
                price: '4.00',
                isAvailable: true,
                sortOrder: 0,
              ),
              restaurantId: 7,
              restaurantName: 'Restaurante',
            );
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: CartSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Finder add = find.byTooltip('Agregar una unidad de Sub de pollo');
      final Finder remove = find.byTooltip('Quitar una unidad de Sub de pollo');
      for (final Finder control in <Finder>[add, remove]) {
        expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
      }
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(container.read(cartProvider).quantityOf(3), 2);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(container.read(cartProvider).quantityOf(3), 1);
      expect(tester.takeException(), isNull);
    },
  );
}
