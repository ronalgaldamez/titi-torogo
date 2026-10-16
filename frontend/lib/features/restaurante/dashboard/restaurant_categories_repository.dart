import '../../../core/api_client.dart';
import '../../../models/food_category.dart';

class RestaurantCategoryOptions {
  const RestaurantCategoryOptions(this.categories, this.selectedIds);
  final List<FoodCategory> categories;
  final Set<int> selectedIds;
}

class RestaurantCategoriesRepository {
  RestaurantCategoriesRepository(this.api);
  final ApiClient api;

  Future<RestaurantCategoryOptions> load() async {
    final json = await api.get('/restaurant/categories');
    return RestaurantCategoryOptions(
      (json['categories'] as List<dynamic>)
          .map((value) => FoodCategory.fromJson(value as Map<String, dynamic>))
          .toList(),
      (json['selected_ids'] as List<dynamic>).cast<int>().toSet(),
    );
  }

  Future<void> save(Set<int> ids) async {
    await api.put(
      '/restaurant/categories',
      body: {'category_ids': ids.toList()},
    );
  }
}
