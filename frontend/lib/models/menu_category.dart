import 'product.dart';

/// Una categoria del menu, con sus productos adentro.
///
/// Espeja `backend/app/Http/Resources/MenuCategoryResource.php`.
///
/// El menu no se aplana a una lista suelta de platos: la pantalla los muestra
/// agrupados ("Tipicos", "Bebidas"), y las categorias SIN productos tambien
/// llegan, porque son las que el restaurante acaba de crear.
class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.products,
  });

  final int id;
  final String name;
  final int sortOrder;

  /// Ya vienen ordenados por el backend (sort_order).
  final List<Product> products;

  /// Cuantos platos tiene la categoria. Se usa para el subtitulo de la
  /// pantalla ("5 platos") sin tener que recorrer la lista a cada rato.
  int get productCount => products.length;

  /// Una copia con los campos cambiados.
  ///
  /// Se usa al prender o apagar un plato: la categoria tambien es inmutable,
  /// asi que se devuelve una nueva con la lista de productos ya corregida.
  MenuCategory copyWith({String? name, List<Product>? products}) {
    return MenuCategory(
      id: id,
      name: name ?? this.name,
      sortOrder: sortOrder,
      products: products ?? this.products,
    );
  }

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        (json['products'] as List<dynamic>?) ?? <dynamic>[];

    return MenuCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int,
      products:
          raw.cast<Map<String, dynamic>>().map(Product.fromJson).toList(),
    );
  }
}
