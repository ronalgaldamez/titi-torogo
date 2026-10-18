import 'package:flutter/material.dart';

import '../../models/food_category.dart';
import '../api_client.dart';
import '../theme.dart';

class FoodCategoryIcon extends StatelessWidget {
  const FoodCategoryIcon({
    required this.category,
    this.size = 24,
    this.color = AppTheme.tealDeep,
    super.key,
  });
  final FoodCategory category;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      switch (category.iconKey) {
        'burger' => Icons.lunch_dining_rounded,
        'menu' => Icons.restaurant_menu_rounded,
        'fastfood' => Icons.fastfood_rounded,
        'rice' => Icons.rice_bowl_rounded,
        'all' => Icons.apps_rounded,
        _ => Icons.restaurant_rounded,
      },
      size: size,
      color: color,
    );
    final url = category.iconUrl;
    if (url == null || url.isEmpty) {
      return fallback;
    }
    return Image.network(
      Uri.parse(ApiClient.baseUrl).resolve(url).toString(),
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (_, error, stackTrace) => fallback,
    );
  }
}
