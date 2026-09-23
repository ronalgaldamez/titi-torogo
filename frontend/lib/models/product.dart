/// Un plato del menu, tal como lo devuelve `GET /api/restaurant/menu`.
///
/// Espeja `backend/app/Http/Resources/ProductResource.php`. Si ese resource
/// cambia, este archivo cambia con el.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.isAvailable,
    required this.sortOrder,
    this.description,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String? description;

  /// El precio viaja como TEXTO ("3.50"), igual que en el backend.
  ///
  /// Nunca se convierte a double: si se convirtiera, al sumar el carrito
  /// empezarian a aparecer centavos fantasma (0.1 + 0.2 = 0.30000000000000004).
  final String price;

  /// Foto del plato en MinIO. Llega null mientras el restaurante no suba una.
  final String? imageUrl;

  /// false = el restaurante lo marco agotado ("se me acabo la sopa de pata").
  ///
  /// El cliente NO lo ve; el restaurante SI, porque es justo el que viene a
  /// reactivar con el toggle. Por eso la pantalla del menu no filtra.
  final bool isAvailable;

  final int sortOrder;

  /// Una copia con algunos campos cambiados.
  ///
  /// Los campos son `final` a proposito (el objeto es inmutable), asi que el
  /// toggle no puede modificar el plato en el lugar: devuelve uno nuevo. Eso
  /// es lo que hace que Flutter redibuje la fila sin sobresaltos.
  Product copyWith({bool? isAvailable}) {
    return Product(
      id: id,
      name: name,
      description: description,
      price: price,
      imageUrl: imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      sortOrder: sortOrder,
    );
  }

  /// Para guardar el carrito en el telefono.
  ///
  /// Usa las MISMAS claves que la API (snake_case) para que un producto
  /// guardado se pueda volver a leer con [Product.fromJson] sin traducciones
  /// en el medio. Si los dos formatos se separaran, un dia guardariamos una
  /// cosa y leeria otra.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'is_available': isAvailable,
      'sort_order': sortOrder,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      // '${...}' en vez de 'as String': el backend ya manda texto, pero si
      // algun dia mandara el precio como numero, esto igual funciona en vez
      // de reventar en la cara del usuario.
      price: '${json['price']}',
      imageUrl: json['image_url'] as String?,
      isAvailable: json['is_available'] as bool,
      sortOrder: json['sort_order'] as int,
    );
  }
}
