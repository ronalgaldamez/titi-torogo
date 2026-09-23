import '../../../core/api_client.dart';
import '../../../models/menu_category.dart';
import '../../../models/product.dart';

/// Todo lo que devuelve `GET /api/restaurant/menu`.
class MenuData {
  const MenuData({required this.categories, required this.uncategorized});

  /// Las categorias, cada una con sus productos adentro.
  final List<MenuCategory> categories;

  /// Platos que no estan en ninguna categoria.
  ///
  /// Existen de verdad, por dos caminos: se pueden crear sin elegir
  /// categoria, y al BORRAR una categoria sus platos quedan sueltos (no se
  /// borran). Viajan aparte para que la pantalla los pueda mostrar igual: si
  /// no, desaparecerian sin que nadie los haya borrado.
  final List<Product> uncategorized;

  bool get isEmpty => categories.isEmpty && uncategorized.isEmpty;
}

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
  Future<MenuData> load() async {
    final Map<String, dynamic> json = await _api.get('/restaurant/menu');

    final List<dynamic> rawCategories =
        (json['categories'] as List<dynamic>?) ?? <dynamic>[];

    final List<dynamic> rawUncategorized =
        (json['uncategorized'] as List<dynamic>?) ?? <dynamic>[];

    return MenuData(
      categories: rawCategories
          .cast<Map<String, dynamic>>()
          .map(MenuCategory.fromJson)
          .toList(),
      uncategorized: rawUncategorized
          .cast<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList(),
    );
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

  /// POST /api/restaurant/menu/categories
  Future<MenuCategory> createCategory(String name) async {
    final Map<String, dynamic> json = await _api.post(
      '/restaurant/menu/categories',
      body: <String, dynamic>{'name': name},
    );

    return MenuCategory.fromJson(json['category'] as Map<String, dynamic>);
  }

  /// PUT /api/restaurant/menu/categories/{id}
  ///
  /// El backend rechaza un nombre que ya tenga otra categoria del mismo
  /// restaurante (pero deja guardar sin cambiarle el nombre).
  Future<MenuCategory> updateCategory({
    required int id,
    required String name,
  }) async {
    final Map<String, dynamic> json = await _api.put(
      '/restaurant/menu/categories/$id',
      body: <String, dynamic>{'name': name},
    );

    return MenuCategory.fromJson(json['category'] as Map<String, dynamic>);
  }

  /// DELETE /api/restaurant/menu/categories/{id}
  ///
  /// Los PLATOS no se borran: el backend los deja sin categoria. Por eso
  /// despues hay que volver a cargar el menu, no solo quitar la fila.
  Future<void> deleteCategory(int id) async {
    await _api.delete('/restaurant/menu/categories/$id');
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
