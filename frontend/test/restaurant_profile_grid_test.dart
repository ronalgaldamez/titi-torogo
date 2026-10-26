import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/cliente/restaurante/restaurant_profile_widgets.dart';
import 'package:torogo/models/product.dart';
import 'package:torogo/models/restaurant.dart';

void main() {
  testWidgets(
    'Encabezado conserva datos en filas y abre información con texto grande',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      const restaurant = Restaurant(
        id: 1,
        name: 'Los Tres Cerditos',
        address: 'Mall del Sol, km 51 carretera Troncal del Norte, Tejutla',
        latitude: 14.1,
        longitude: -89.1,
        isOpen: true,
        isBusy: false,
        estimatedDeliveryMinutes: 30,
        deliveryFee: '2.00',
        distanceKm: 0.1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: SingleChildScrollView(
                child: RestaurantProfileHeader(
                  restaurant: restaurant,
                  onInfo: () => opened = true,
                ),
              ),
            ),
          ),
        ),
      );
      final preparation = find.byKey(
        const ValueKey('restaurant-fact-Preparación'),
      );
      final delivery = find.byKey(const ValueKey('restaurant-fact-Envío'));
      final payment = find.byKey(const ValueKey('restaurant-fact-Pago'));
      expect(
        tester.getTopLeft(preparation).dy,
        lessThan(tester.getTopLeft(delivery).dy),
      );
      expect(
        tester.getTopLeft(delivery).dy,
        lessThan(tester.getTopLeft(payment).dy),
      );
      expect(find.text('30 min'), findsOneWidget);
      expect(find.text(r'$2.00'), findsOneWidget);
      await tester.tap(find.text('A 0.1 km de vos · Ver información'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Menú en dos columnas admite nombres largos y texto grande', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final products = [
      for (var id = 1; id <= 3; id++)
        Product(
          id: id,
          name: 'Pupusa de frijol con queso y loroco $id',
          description: 'Preparada con ingredientes del restaurante.',
          price: '1.25',
          isAvailable: true,
          sortOrder: id,
        ),
    ];
    Product? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: RestaurantProductGrid(
                  products: products,
                  onOpen: (value) => opened = value,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final first = find.byKey(const ValueKey('menu-product-1'));
    final second = find.byKey(const ValueKey('menu-product-2'));
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
    expect(
      tester.getTopLeft(second).dx,
      greaterThan(tester.getTopLeft(first).dx),
    );
    await tester.tap(second);
    expect(opened?.id, 2);
    await tester.ensureVisible(find.byKey(const ValueKey('menu-product-3')));
    expect(tester.takeException(), isNull);
  });
}
