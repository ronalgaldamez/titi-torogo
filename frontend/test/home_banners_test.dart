import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/cliente/home/widgets/home_banners.dart';

void main() {
  testWidgets(
    'Banners cambian entre tres imágenes, filtran y admiten texto grande',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  HomePromoSlider(onExplore: (value) => selected = value),
                  LocalFoodBanner(onExplore: () => selected = 'tipicos'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('home-promo-swipe'))).width,
        288,
      );
      expect(tester.getSize(find.byType(IndexedStack)).width, 288);
      await tester.tap(find.text('Se me antojaron'));
      expect(selected, 'pupusas');
      await tester.tap(find.byTooltip('Siguiente banner'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.tap(find.text('Voy a ver'));
      expect(selected, 'burgers');
      await tester.fling(
        find.byKey(const ValueKey('home-promo-swipe')),
        const Offset(-180, 0),
        600,
      );
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
      await tester.tap(find.text('Ver los típicos'));
      expect(selected, 'tipicos');
      await tester.tap(find.byTooltip('Siguiente banner'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      selected = null;
      final localAction = find.text('Conocé los restaurantes').hitTestable();
      await tester.scrollUntilVisible(
        localAction,
        180,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(localAction);
      expect(selected, 'tipicos');
      expect(tester.takeException(), isNull);
    },
  );
}
