import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/api_client.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/restaurante/menu/menu_repository.dart';
import 'package:torogo/features/restaurante/menu/product_form_screen.dart';
import 'package:torogo/models/product.dart';

void main() {
  test(
    'Crear y editar con foto envía archivo, campos y método correcto',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer test');
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );
        final body = latin1.decode(request.bodyBytes);
        expect(body, contains('name="image"; filename="plato.png"'));
        expect(body, contains('name="offer_enabled"'));
        expect(body, contains('name="sale_price"'));
        expect(body, contains('2026-10-26T11:00:00-06:00'));
        expect(body.contains('name="_method"'), requests == 2);
        if (requests == 2) expect(body, contains('PUT'));
        return http.Response(
          jsonEncode({
            'product': {
              'id': 5,
              'name': 'Burrito momia',
              'price': '7.50',
              'regular_price': '8.75',
              'sale_price': '7.50',
              'offer_enabled': true,
              'is_available': true,
              'sort_order': 0,
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      final repository = MenuRepository(
        ApiClient(client: client, authToken: 'test'),
      );
      final image = (Uint8List.fromList([1, 2, 3]), 'plato.png');
      final created = await repository.createProduct(
        name: 'Burrito momia',
        price: '8.75',
        offerEnabled: true,
        salePrice: '7.50',
        offerStartsAt: '2026-10-26T11:00:00-06:00',
        offerEndsAt: '2026-10-26T21:00:00-06:00',
        image: image,
      );
      expect(created.hasDiscount, isTrue);
      expect(Product.fromJson(created.toJson()).regularPrice, '8.75');
      expect(created.copyWith(isAvailable: false).salePrice, '7.50');
      await repository.updateProduct(
        id: 5,
        name: 'Burrito momia',
        price: '8.75',
        offerEnabled: true,
        salePrice: '7.50',
        offerStartsAt: '2026-10-26T11:00:00-06:00',
        offerEndsAt: '2026-10-26T21:00:00-06:00',
        image: image,
      );
      expect(requests, 2);
    },
  );

  testWidgets(
    'Editor conserva precio normal, valida oferta y retiene datos al fallar',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      var requests = 0;
      var selections = 0;
      final client = MockClient((request) async {
        requests++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['price'], '8.75');
        expect(body['sale_price'], '7.50');
        expect(body['offer_starts_at'], '2026-10-26T11:00:00-06:00');
        expect(body['offer_ends_at'], '2026-10-26T21:00:00-06:00');
        expect(body['offer_enabled'], isTrue);
        return http.Response('{"message":"No se pudo guardar"}', 503);
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
            home: ProductFormScreen(
              categories: const [],
              selectImage: () async => selections++ == 0
                  ? null
                  : XFile.fromData(
                      Uint8List.fromList([1]),
                      path: 'no-es-foto.svg',
                    ),
              product: Product(
                id: 5,
                name: 'Burrito momia',
                price: '7.50',
                regularPrice: '8.75',
                salePrice: '7.50',
                isAvailable: true,
                sortOrder: 0,
                offerEnabled: true,
                offerStartsAt: DateTime.parse('2026-10-26T17:00:00Z'),
                offerEndsAt: DateTime.parse('2026-10-27T03:00:00Z'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Foto principal'), findsOneWidget);
        expect(find.text('1 foto por plato'), findsOneWidget);
        final pick = find.byKey(const ValueKey('product-pick-photo'));
        await tester.ensureVisible(pick);
        await tester.tap(pick);
        await tester.pumpAndSettle();
        expect(requests, 0, reason: 'Cancelar la galería no guarda nada.');
        await tester.tap(pick);
        await tester.pumpAndSettle();
        expect(
          find.text('Elegí una imagen JPG, PNG o WebP de hasta 5 MB.'),
          findsOneWidget,
        );
        expect(requests, 0);
        final fields = find.byType(TextFormField);
        expect(
          tester.widget<TextFormField>(fields.at(2)).controller!.text,
          '8.75',
        );
        await tester.ensureVisible(fields.at(3));
        await tester.enterText(fields.at(3), '9.00');
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, 'Guardar cambios');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(requests, 0);
        expect(
          find.text('La oferta debe ser menor que el precio normal.'),
          findsOneWidget,
        );
        await tester.ensureVisible(fields.at(3));
        await tester.enterText(fields.at(3), '7.50');
        await tester.pumpAndSettle();
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(requests, 1);
        expect(find.text('No se pudo guardar'), findsOneWidget);
        expect(
          tester.widget<TextFormField>(fields.at(3)).controller!.text,
          '7.50',
        );
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );
}
