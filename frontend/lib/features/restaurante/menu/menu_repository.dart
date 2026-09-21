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

  /// POST /api/restaurant/menu/products
  ///
  /// Crea un plato. Nace DISPONIBLE: apagarlo es el toggle de la lista.
  Future<Product> createProduct({
    required String name,
    required String price,
    String? description,
    int? categoryId,
  }) async {
    final Map<String, dynamic> json = await _api.post(
      '/restaurant/menu/products',
      body: <String, dynamic>{
        'name': name,
        'price': price,
        'description': description,
        'menu_category_id': categoryId,
      },
    );

    return Product.fromJson(json['product'] as Map<String, dynamic>);
  }

  /// PUT /api/restaurant/menu/products/{id}
  ///
  /// Manda el plato COMPLETO: es lo que hace el formulario.
  ///
  /// 'description' y 'menu_category_id' van siempre, aunque lleguen en null.
  /// Es a proposito: asi el backend distingue "vaciar la descripcion" de "no
  /// la toques". Si los omitieramos cuando estan vacios, borrar la descripcion
  /// desde la app no haria nada.
  Future<Product> updateProduct({
    required int id,
    required String name,
    required String price,
    String? description,
    int? categoryId,
  }) async {
    final Map<String, dynamic> json = await _api.put(
      '/restaurant/menu/products/$id',
      body: <String, dynamic>{
        'name': name,
        'price': price,
        'description': description,
        'menu_category_id': categoryId,
      },
    );

    return Product.fromJson(json['product'] as Map<String, dynamic>);
  }

  /// DELETE /api/restaurant/menu/products/{id}
  ///
  /// El backend hace un borrado SUAVE: el plato deja de aparecer en el menu,
  /// pero la fila queda en la base para que los pedidos viejos no queden con
  /// huecos.
  Future<void> deleteProduct(int id) async {
    await _api.delete('/restaurant/menu/products/$id');
  }
}
