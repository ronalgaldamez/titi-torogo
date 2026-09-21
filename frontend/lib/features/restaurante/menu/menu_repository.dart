import '../../../core/api_client.dart';
import '../../../models/menu_category.dart';
import '../../../models/product.dart';

/// La capa de datos del menu del restaurante.
///
/// La pantalla no sabe que existe HTTP: pide y recibe objetos. El dia que
/// cambie un endpoint, se toca solo aqui.
///
/// TODOS los metodos trabajan sobre EL restaurante de la sesion. El backend
/// lo saca del token, asi que aqui nunca se manda un restaurant_id — ni
/// falta que exista.
class MenuRepository {
  MenuRepository(this._api);

  final ApiClient _api;

  /// GET /api/restaurant/menu
  ///
  /// El menu completo: categorias con sus productos adentro, INCLUIDOS los
  /// agotados. Es al reves que la carta del cliente a proposito: aca el
  /// restaurante necesita ver lo que apago para poder reactivarlo.
  Future<List<MenuCategory>> load() async {
    final Map<String, dynamic> json = await _api.get('/restaurant/menu');

    final List<dynamic> raw =
        (json['categories'] as List<dynamic>?) ?? <dynamic>[];

    return raw
        .cast<Map<String, dynamic>>()
        .map(MenuCategory.fromJson)
        .toList();
  }

  /// PATCH /api/restaurant/menu/products/{id}/availability
  ///
  /// El toggle de la lista. Devuelve el plato ya actualizado POR EL BACKEND,
  /// no el estado que creiamos: asi la pantalla nunca muestra algo distinto
  /// de lo que quedo guardado.
  Future<Product> setAvailable(
    int productId, {
    required bool isAvailable,
  }) async {
    final Map<String, dynamic> json = await _api.patch(
      '/restaurant/menu/products/$productId/availability',
      body: <String, dynamic>{'is_available': isAvailable},
    );

    return Product.fromJson(json['product'] as Map<String, dynamic>);
  }
}
