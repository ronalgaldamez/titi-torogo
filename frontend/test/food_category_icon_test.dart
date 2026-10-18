import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:torogo/core/api_client.dart';
import 'package:torogo/core/widgets/food_category_icon.dart';
import 'package:torogo/models/food_category.dart';

void main() {
  testWidgets(
    'Categorías sin imagen o con icono desconocido tienen un predeterminado',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FoodCategoryIcon(category: FoodCategory(id: 1, name: 'Cuca')),
                FoodCategoryIcon(
                  category: FoodCategory(
                    id: 2,
                    name: 'Otra',
                    iconKey: 'desconocido',
                  ),
                ),
                FoodCategoryIcon(
                  category: FoodCategory(
                    id: 3,
                    name: 'Hamburguesas',
                    iconKey: 'burger',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.restaurant_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.lunch_dining_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'Imagen personalizada usa la dirección de la API y recupera el icono si falla',
    (tester) async {
      final category = FoodCategory.fromJson({
        'id': 1,
        'name': 'Cuca',
        'icon_url': '/api/category-icons/1?v=test',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: FoodCategoryIcon(category: category)),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as NetworkImage).url,
        Uri.parse(
          ApiClient.baseUrl,
        ).resolve('/api/category-icons/1?v=test').toString(),
      );
      // El cliente HTTP de widget tests responde 400: comprueba la recuperación.
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
