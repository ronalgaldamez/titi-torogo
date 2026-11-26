import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/cliente/carrito/cart_provider.dart';
import 'package:torogo/features/cliente/carrito/cart_sheet.dart';
import 'package:torogo/features/cliente/checkout_appearance.dart';
import 'package:torogo/models/product.dart';

const _product = Product(
  id: 3,
  name: 'Sub de pollo',
  price: '4.00',
  isAvailable: true,
  sortOrder: 0,
);

class _SlowCartNotifier extends CartNotifier {
  final saved = Completer<void>();

  @override
  Future<void> clear() async {
    await super.clear();
    await saved.future;
  }
}

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
            .add(_product, restaurantId: 7, restaurantName: 'Restaurante');
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
      expect(find.text('Continuar a la entrega'), findsOneWidget);
      expect(find.byTooltip('Cerrar carrito'), findsOneWidget);
      expect(
        find.text('El envío se calcula al elegir la dirección.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Vaciar carrito cierra la hoja al terminar un guardado lento', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final notifier = _SlowCartNotifier();
    final container = ProviderContainer(
      overrides: [cartProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container
          .read(cartProvider.notifier)
          .add(_product, restaurantId: 7, restaurantName: 'Restaurante'),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Text('Menú'), bottomNavigationBar: CartBar()),
        ),
      ),
    );
    await tester.tap(find.text('Ver pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaciar carrito'));
    await tester.pumpAndSettle();
    expect(find.text('Tu carrito está vacío.'), findsOneWidget);

    notifier.saved.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CartSheet), findsNothing);
    expect(find.text('Menú').hitTestable(), findsOneWidget);
  });

  testWidgets('La miniatura limita ambas dimensiones según la densidad', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(devicePixelRatio: 3),
        child: Center(
          child: CheckoutThumbnail('https://example.test/plato.jpg'),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as ResizeImage;
    expect(provider.width, 162);
    expect(provider.height, 162);
    expect(provider.policy, ResizeImagePolicy.fit);
  });
}
