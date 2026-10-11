import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/cliente/pedido/order_sent_screen.dart';

void main() {
  testWidgets(
    'El check aparece antes de los detalles y conserva total y propina',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const OrderSentScreen(
            orderId: 29,
            restaurantName: 'Los Tres Cerditos con un nombre largo',
            total: '6.00',
            tipAmount: '1.00',
          ),
        ),
      );
      final checkFade = find
          .descendant(
            of: find.byType(OrderSentScreen),
            matching: find.byType(FadeTransition),
          )
          .first;
      final detailsFade = find
          .descendant(
            of: find.byType(OrderSentScreen),
            matching: find.byType(FadeTransition),
          )
          .last;
      expect(tester.widget<FadeTransition>(detailsFade).opacity.value, 0);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<FadeTransition>(checkFade).opacity.value, 1);
      expect(tester.widget<FadeTransition>(detailsFade).opacity.value, 0);
      await tester.pumpAndSettle();
      expect(tester.widget<FadeTransition>(detailsFade).opacity.value, 1);
      expect(find.text(r'$6.00'), findsOneWidget);
      expect(
        find.text(r'Incluye $1.00 de propina para el motorista'),
        findsOneWidget,
      );
      expect(find.text('¡Pedido enviado!'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Ver seguimiento'), 150);
      expect(find.text('Ver seguimiento').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Movimiento reducido y recuperación muestran los datos sin esperar',
    (tester) async {
      for (final recovered in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: !recovered),
              child: child!,
            ),
            home: OrderSentScreen(
              key: ValueKey(recovered),
              orderId: 29,
              restaurantName: 'Los Tres Cerditos',
              total: '3.00',
              alreadySent: recovered,
            ),
          ),
        );
        final detailsFade = find
            .descendant(
              of: find.byType(OrderSentScreen),
              matching: find.byType(FadeTransition),
            )
            .last;
        expect(tester.widget<FadeTransition>(detailsFade).opacity.value, 1);
        expect(
          find.text(recovered ? 'Pedido recuperado' : '¡Pedido enviado!'),
          findsOneWidget,
        );
        if (recovered) {
          expect(
            find.text(
              'Este pedido ya se había enviado. No se creó otro pedido.',
            ),
            findsOneWidget,
          );
        }
        expect(find.textContaining('de propina'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
