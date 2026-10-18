/// Catálogo del administrador, separado de las secciones del menú.
class FoodCategory {
  const FoodCategory({
    required this.id,
    required this.name,
    this.iconKey = 'restaurant',
    this.iconUrl,
  });
  final int id;
  final String name;
  final String iconKey;
  final String? iconUrl;

  factory FoodCategory.fromJson(Map<String, dynamic> json) => FoodCategory(
    id: json['id'] as int,
    name: json['name'] as String,
    iconKey: json['icon_key'] as String? ?? 'restaurant',
    iconUrl: json['icon_url'] as String?,
  );
}
