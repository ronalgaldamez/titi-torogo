import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torogo/core/theme.dart';
import 'package:torogo/features/restaurante/dashboard/restaurant_images_editor.dart';
import 'package:torogo/models/restaurant.dart';

void main() {
  for (final slot in ['logo', 'cover']) {
    testWidgets('Confirma solamente la imagen guardada: $slot', (tester) async {
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      final image = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACXBIWXMAAAPoAAAD6AG1e1JrAAAADUlEQVQImWNgYGBgAAAABQABh6FO1AAAAABJRU5ErkJggg==',
      );
      final client = MockClient((request) async {
        final multipart = latin1.decode(request.bodyBytes);
        expect(multipart, contains('name="$slot"'));
        expect(
          multipart,
          isNot(contains('name="${slot == 'logo' ? 'cover' : 'logo'}"')),
        );
        return http.Response(
          jsonEncode({
            'restaurant': {
              'id': 1,
              'name': 'Baruk',
              'address': 'Centro',
              'latitude': 14.1,
              'longitude': -89.1,
              'is_open': true,
              'is_busy': false,
              'estimated_delivery_minutes': 25,
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: RestaurantImagesEditor(
                  restaurant: const Restaurant(
                    id: 1,
                    name: 'Baruk',
                    address: 'Centro',
                    latitude: 14.1,
                    longitude: -89.1,
                    isOpen: true,
                    isBusy: false,
                    estimatedDeliveryMinutes: 25,
                  ),
                  disabled: false,
                  onSaved: (_) {},
                  onSaving: (_) {},
                  selectImage: () async => XFile.fromData(
                    image,
                    path: 'foto.png',
                    mimeType: 'image/png',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(ValueKey('pick-$slot')));
        await tester.pumpAndSettle();
        final save = find.byKey(const ValueKey('save-restaurant-images'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(
          find.text(
            slot == 'logo' ? 'Logo actualizado.' : 'Portada actualizada.',
          ),
          findsOneWidget,
        );
        expect(find.text('Logo y portada actualizados.'), findsNothing);
        expect(tester.takeException(), isNull);
      }, () => client);
    });
  }

  testWidgets(
    'Selecciona logo y portada, conserva selección al fallar y confirma al guardar',
    (tester) async {
      SharedPreferences.setMockInitialValues({'torogo_token': 'test'});
      final image = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACXBIWXMAAAPoAAAD6AG1e1JrAAAADUlEQVQImWNgYGBgAAAABQABh6FO1AAAAABJRU5ErkJggg==',
      );
      var selections = 0;
      var requests = 0;
      var fail = true;
      Restaurant? saved;
      final client = MockClient((request) async {
        requests++;
        expect(request.method, 'POST');
        expect(request.url.path.endsWith('/restaurant/images'), isTrue);
        expect(request.headers['Authorization'], 'Bearer test');
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );
        final multipart = latin1.decode(request.bodyBytes);
        expect(multipart, contains('name="logo"'));
        expect(multipart, contains('name="cover"'));
        if (fail) {
          return http.Response('{"message":"No se pudo guardar"}', 503);
        }
        return http.Response(
          jsonEncode({
            'restaurant': {
              'id': 1,
              'name': 'Baruk',
              'address': 'Centro',
              'latitude': 14.1,
              'longitude': -89.1,
              'is_open': true,
              'is_busy': false,
              'estimated_delivery_minutes': 25,
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      await http.runWithClient(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: RestaurantImagesEditor(
                  restaurant: const Restaurant(
                    id: 1,
                    name: 'Baruk',
                    address: 'Centro',
                    latitude: 14.1,
                    longitude: -89.1,
                    isOpen: true,
                    isBusy: false,
                    estimatedDeliveryMinutes: 25,
                  ),
                  disabled: false,
                  onSaving: (_) {},
                  onSaved: (value) => saved = value,
                  selectImage: () async => XFile.fromData(
                    image,
                    path: selections++ == 0 ? 'logo.png' : 'portada.png',
                    mimeType: 'image/png',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('pick-logo')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('pick-cover')));
        await tester.pumpAndSettle();
        expect(selections, 2);
        expect(find.text('Logo y portada listos'), findsOneWidget);
        expect(
          requests,
          0,
          reason: 'Seleccionar una imagen no la sube automáticamente.',
        );
        final save = find.byKey(const ValueKey('save-restaurant-images'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(saved, isNull);
        expect(find.text('No se pudo guardar'), findsOneWidget);
        expect(find.text('Logo y portada listos'), findsOneWidget);
        fail = false;
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(saved?.name, 'Baruk');
        expect(requests, 2);
        expect(save, findsNothing);
        await tester.ensureVisible(find.byKey(const ValueKey('pick-logo')));
        await tester.tap(find.byKey(const ValueKey('pick-logo')));
        await tester.pumpAndSettle();
        expect(find.text('Logo listo'), findsOneWidget);
        final discard = find.byKey(const ValueKey('discard-restaurant-images'));
        await tester.ensureVisible(discard);
        await tester.tap(discard);
        await tester.pumpAndSettle();
        expect(save, findsNothing);
        expect(find.text('Sin guardar todavía'), findsNothing);
        expect(requests, 2, reason: 'Descartar no envía imágenes al servidor.');
        expect(tester.takeException(), isNull);
      }, () => client);
    },
  );
}
