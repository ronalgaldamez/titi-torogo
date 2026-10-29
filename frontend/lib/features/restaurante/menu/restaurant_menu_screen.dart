import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../models/menu_category.dart';
import '../../../models/product.dart';
import 'categories_screen.dart';
import 'menu_repository.dart';
import 'product_form_screen.dart';

/// El menu del restaurante: la pantalla de "Gestion de Menu" del AGENDS.
///
/// Muestra las categorias con sus platos, y cada plato trae un interruptor
/// para marcarlo agotado SIN borrarlo del menu.
///
/// "Se me acabo la sopa de pata" no es lo mismo que "ya no vendo sopa de
/// pata": lo primero se prende de nuevo manana, lo segundo se borra.
class RestaurantMenuScreen extends StatefulWidget {
  const RestaurantMenuScreen({required this.onLogout, super.key});

  /// null = no hay sesion que cerrar. En esta pantalla siempre hay (no se
  /// llega sin token), pero el parametro es el mismo que usa el Home del
  /// cliente para no inventar dos formas de hacer lo mismo.
  final VoidCallback? onLogout;

  @override
  State<RestaurantMenuScreen> createState() => _RestaurantMenuScreenState();
}

class _RestaurantMenuScreenState extends State<RestaurantMenuScreen> {
  final Session _session = Session(AuthStorage());

  List<MenuCategory> _categories = <MenuCategory>[];

  /// Platos que no estan en ninguna categoria.
  ///
  /// Existen de verdad: se pueden crear sin categoria, y al borrar una
  /// categoria sus platos quedan sueltos (no se borran). Se muestran igual,
  /// en su propia seccion, para que no desaparezcan de la vista.
  List<Product> _uncategorized = <Product>[];

  final TextEditingController _search = TextEditingController();
  int _category = -1;
  int _availability = -1;
  int _page = 0;
  static const int _pageSize = 8;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _search.clear();
    setState(() {
      _category = -1;
      _availability = -1;
      _page = 0;
    });
  }

  static String _normalize(String value) {
    var result = value.toLowerCase().trim();
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
    };
    accents.forEach((accent, letter) {
      result = result.replaceAll(accent, letter);
    });
    return result;
  }

  String? _error;
  bool _loading = true;

  /// Ids de los platos con una peticion en vuelo.
  ///
  /// Mientras un plato esta aqui, su interruptor se reemplaza por un circulo
  /// de carga. Sin esto, tocar dos veces seguidas manda dos peticiones y la
  /// segunda puede llegar antes que la primera: el plato quedaria al reves
  /// de lo que el restaurante acaba de ver.
  final Set<int> _saving = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ApiClient api = await _session.client();
      final MenuData data = await MenuRepository(api).load();

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = data.categories;
        _uncategorized = data.uncategorized;
        if (!_categories.any((category) => category.id == _category) &&
            _category > 0) {
          _category = -1;
        }
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  /// Prende o apaga un plato.
  ///
  /// El estado de la pantalla NO se toca antes de que conteste el backend.
  /// Si la peticion falla, el interruptor se queda solo donde estaba: no hay
  /// nada que deshacer, porque nunca se movio.
  Future<void> _toggle(Product product, bool isAvailable) async {
    setState(() => _saving.add(product.id));

    try {
      final ApiClient api = await _session.client();
      final Product updated = await MenuRepository(
        api,
      ).setAvailable(product.id, isAvailable: isAvailable);

      if (!mounted) {
        return;
      }

      // Se reemplaza SOLO ese plato, con lo que devolvio el backend. Asi lo
      // que se ve es exactamente lo que quedo guardado, y no lo que creiamos.
      setState(() {
        _categories = _categories
            .map(
              (MenuCategory category) => category.copyWith(
                products: category.products
                    .map(
                      (Product item) => item.id == updated.id ? updated : item,
                    )
                    .toList(),
              ),
            )
            .toList();

        _uncategorized = _uncategorized
            .map((Product item) => item.id == updated.id ? updated : item)
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _saving.remove(product.id));
      }
    }
  }

  /// Abre el formulario para agregar un plato o para editar uno existente.
  ///
  /// Al volver, si guardo algo, se recarga el menu ENTERO en vez de parchear
  /// la lista a mano. Crear, editar o borrar cambian los conteos, el orden y
  /// hasta la categoria en la que cae el plato: pedirlo de nuevo es mas
  /// simple y siempre queda bien.
  Future<void> _openForm({Product? product, int? categoryId}) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => ProductFormScreen(
          categories: _categories,
          product: product,
          categoryId: categoryId,
        ),
      ),
    );

    if (!mounted || saved != true) {
      return;
    }

    await _load();
  }

  /// Abre la pantalla de categorias.
  ///
  /// Se recarga SIEMPRE al volver, aunque no se sepa si cambio algo: una
  /// peticion de mas es mas barata que una pantalla mostrando datos viejos.
  Future<void> _openCategories() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            CategoriesScreen(categories: _categories),
      ),
    );

    if (!mounted) {
      return;
    }

    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.discoveryAccent,
          brightness: Brightness.dark,
          surface: AppTheme.discoveryBackground,
          primary: AppTheme.discoveryAccent,
          onSurface: AppTheme.discoveryPaper,
        ),
        iconTheme: const IconThemeData(color: AppTheme.discoveryMuted),
        textTheme: theme.textTheme.apply(
          bodyColor: AppTheme.discoveryPaper,
          displayColor: AppTheme.discoveryPaper,
        ),
      ),
      child: Scaffold(
        backgroundColor: AppTheme.discoveryBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: 'toro'),
                                  TextSpan(
                                    text: 'go',
                                    style: TextStyle(color: AppTheme.yellow),
                                  ),
                                  TextSpan(
                                    text: '.',
                                    style: TextStyle(
                                      color: AppTheme.discoveryAccent,
                                    ),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'MI NEGOCIO',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 2,
                            color: AppTheme.discoveryMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(color: Color(0x334E6B77), height: 1),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: 'Mi menú'),
                                TextSpan(
                                  text: '.',
                                  style: TextStyle(
                                    color: AppTheme.discoveryAccent,
                                  ),
                                ),
                              ],
                            ),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.3,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _openCategories,
                          icon: const Icon(Icons.category_outlined),
                          color: AppTheme.discoveryMuted,
                          tooltip: 'Categorías',
                        ),
                        if (widget.onLogout != null)
                          IconButton(
                            onPressed: _confirmLogout,
                            icon: const Icon(Icons.logout_rounded),
                            color: AppTheme.discoveryMuted,
                            tooltip: 'Cerrar sesión',
                          ),
                      ],
                    ),
                    const Text(
                      'Cada plato, listo para antojar.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.discoveryMuted,
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
              Expanded(child: Builder(builder: _body)),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: FilledButton(
              onPressed: _loading || _error != null
                  ? null
                  : () =>
                        _openForm(categoryId: _category > 0 ? _category : null),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.discoveryAccent,
                foregroundColor: AppTheme.discoveryBackground,
                minimumSize: const Size.fromHeight(58),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Agregar plato',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.discoveryBackground,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.north_east_rounded,
                      color: AppTheme.discoveryPaper,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: 'No pudimos cargar tu menú',
        message: _error!,
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    }

    if (_categories.isEmpty && _uncategorized.isEmpty) {
      return _Message(
        icon: Icons.restaurant_menu_rounded,
        title: 'Tu menú está vacío',
        message: 'Creá una categoría para empezar a cargar tus platos.',
        actionLabel: 'Crear categoría',
        onAction: _openCategories,
      );
    }

    final entries = <({Product product, int categoryId, String categoryName})>[
      for (final category in _categories)
        for (final product in category.products)
          (
            product: product,
            categoryId: category.id,
            categoryName: category.name,
          ),
      for (final product in _uncategorized)
        (product: product, categoryId: 0, categoryName: 'Sin categoría'),
    ];
    final filtered = entries
        .where(
          (entry) =>
              (_category == -1 || entry.categoryId == _category) &&
              (_availability == -1 ||
                  entry.product.isAvailable == (_availability == 1)) &&
              _normalize(entry.product.name).contains(_normalize(_search.text)),
        )
        .toList();
    final pages = (filtered.length / _pageSize).ceil().clamp(
      1,
      entries.length + 1,
    );
    final page = _page.clamp(0, pages - 1);
    final visible = filtered.skip(page * _pageSize).take(_pageSize);
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        key: const ValueKey('menu-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  TextField(
                    style: const TextStyle(
                      fontSize: 13,
                      letterSpacing: 0,
                      color: AppTheme.discoveryPaper,
                    ),
                    controller: _search,
                    onChanged: (_) => setState(() => _page = 0),
                    decoration: InputDecoration(
                      hintText: 'Buscar un plato',
                      isDense: true,
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        letterSpacing: 0,
                        color: AppTheme.discoveryMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: AppTheme.discoveryMuted,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide(color: const Color(0x7078919C)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(
                          color: AppTheme.discoveryAccent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    key: const ValueKey('menu-filter-line'),
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0x22FFFFFF)),
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var index = 0; index < 3; index++)
                            Semantics(
                              key: ValueKey('menu-availability-$index'),
                              selected: _availability == [-1, 1, 0][index],
                              button: true,
                              child: InkWell(
                                onTap: () => setState(() {
                                  _availability = [-1, 1, 0][index];
                                  _page = 0;
                                }),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 48,
                                  ),
                                  alignment: Alignment.center,
                                  margin: EdgeInsets.only(
                                    right: index == 2 ? 0 : 19,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color:
                                            _availability == [-1, 1, 0][index]
                                            ? AppTheme.discoveryAccent
                                            : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: [
                                            'Todos',
                                            'Disponibles',
                                            'Agotados',
                                          ][index],
                                        ),
                                        if (index == 0)
                                          TextSpan(
                                            text: '  ${entries.length}',
                                            style: const TextStyle(
                                              color: AppTheme.discoveryAccent,
                                            ),
                                          ),
                                      ],
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _availability == [-1, 1, 0][index]
                                          ? AppTheme.discoveryPaper
                                          : AppTheme.discoveryMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          key: const ValueKey('menu-category-filter'),
                          onPressed: _pickCategory,
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.discoveryPaper,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.centerLeft,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.tune_rounded,
                                size: 14,
                                color: AppTheme.discoveryAccent,
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  _category == -1
                                      ? 'Todas las categorías'
                                      : _category == 0
                                      ? 'Sin categoría'
                                      : _categories
                                            .firstWhere(
                                              (category) =>
                                                  category.id == _category,
                                            )
                                            .name,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${filtered.length} de ${entries.length} platos',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.discoveryMuted,
                        ),
                      ),
                    ],
                  ),
                  if (_category != -1 ||
                      _availability != -1 ||
                      _search.text.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _resetFilters,
                        child: const Text('Limpiar filtros'),
                      ),
                    ),
                ],
              ),
            ),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'No hay platos con estos filtros. Probá otra búsqueda o limpiá los filtros.',
                ),
              ),
            for (final entry in visible)
              _ProductTile(
                key: ValueKey(entry.product.id),
                product: entry.product,
                categoryName: entry.categoryName,
                saving: _saving.contains(entry.product.id),
                onChanged: (value) => _toggle(entry.product, value),
                onTap: () => _openForm(
                  product: entry.product,
                  categoryId: entry.categoryId == 0 ? null : entry.categoryId,
                ),
              ),
            if (filtered.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Página anterior',
                    onPressed: page == 0
                        ? null
                        : () => setState(() => _page = page - 1),
                    icon: const Icon(Icons.chevron_left_rounded, size: 16),
                  ),
                  Flexible(
                    child: Text(
                      'Página ${page + 1} de $pages',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.discoveryMuted,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Página siguiente',
                    onPressed: page + 1 >= pages
                        ? null
                        : () => setState(() => _page = page + 1),
                    icon: const Icon(Icons.chevron_right_rounded, size: 16),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCategory() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF183744),
      builder: (context) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Filtrar por categoría',
                  style: const TextStyle(
                    color: AppTheme.discoveryPaper,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in <({int id, String name, int count})>[
                      (
                        id: -1,
                        name: 'Todas las categorías',
                        count:
                            _categories.fold<int>(
                              0,
                              (sum, category) => sum + category.products.length,
                            ) +
                            _uncategorized.length,
                      ),
                      for (final category in _categories)
                        (
                          id: category.id,
                          name: category.name,
                          count: category.products.length,
                        ),
                      if (_uncategorized.isNotEmpty || _category == 0)
                        (
                          id: 0,
                          name: 'Sin categoría',
                          count: _uncategorized.length,
                        ),
                    ])
                      ListTile(
                        key: ValueKey('menu-category-${entry.id}'),
                        selected: _category == entry.id,
                        textColor: AppTheme.discoveryPaper,
                        iconColor: AppTheme.discoveryMuted,
                        selectedColor: AppTheme.discoveryAccent,
                        selectedTileColor: const Color(0xFF204653),
                        leading: Icon(
                          _category == entry.id
                              ? Icons.check_circle_rounded
                              : Icons.restaurant_menu_rounded,
                        ),
                        title: Text(entry.name),
                        trailing: Text('${entry.count}'),
                        onTap: () => Navigator.of(context).pop(entry.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _category = selected;
      _page = 0;
    });
  }

  Future<void> _confirmLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Vas a tener que volver a entrar con tu correo.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      widget.onLogout?.call();
    }
  }
}

/// Una fila del menu: el plato a la izquierda, su interruptor a la derecha.
///
/// Tocar la fila abre el formulario para editarlo. El interruptor es SOLO
/// para agotar: son dos acciones distintas y por eso estan separadas.
class _ProductTile extends StatelessWidget {
  const _ProductTile({
    super.key,
    required this.categoryName,
    required this.product,
    required this.saving,
    required this.onChanged,
    required this.onTap,
  });

  final String categoryName;
  final Product product;
  final bool saving;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = product.isAvailable;
    final photoWidth = MediaQuery.sizeOf(context).width <= 350 ? 65.0 : 80.0;
    const placeholder = ColoredBox(
      color: Color(0xFF204653),
      child: Center(
        child: Icon(
          Icons.restaurant_menu_rounded,
          color: AppTheme.discoveryMuted,
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x334E6B77))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: saving ? null : onTap,
                child: Row(
                  children: [
                    Opacity(
                      opacity: available ? 1 : .55,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: photoWidth,
                          height: 94,
                          child: product.imageUrl == null
                              ? placeholder
                              : Image.network(
                                  product.imageUrl!,
                                  fit: BoxFit.cover,
                                  semanticLabel: product.name,
                                  errorBuilder: (_, error, stackTrace) =>
                                      placeholder,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.discoveryPaper,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            categoryName,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.discoveryMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (product.hasDiscount)
                            Text(
                              '\$${product.regularPrice}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.discoveryMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            '\$${product.price}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.discoveryAccent,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 12,
                                color: AppTheme.discoveryMuted,
                              ),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Editar plato',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.discoveryMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Column(
              children: [
                if (saving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Semantics(
                    label: product.name,
                    toggled: available,
                    onTap: () => onChanged(!available),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: () => onChanged(!available),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: ExcludeSemantics(
                          child: IgnorePointer(
                            child: Transform.scale(
                              scale: .82,
                              child: Switch(
                                value: available,
                                onChanged: onChanged,
                                activeTrackColor: AppTheme.discoveryAccent,
                                activeThumbColor: AppTheme.discoveryBackground,
                                inactiveTrackColor: const Color(0xFF47616C),
                                inactiveThumbColor: AppTheme.discoveryPaper,
                                trackOutlineColor: const WidgetStatePropertyAll(
                                  Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Text(
                  available ? 'Disponible' : 'Agotado',
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppTheme.discoveryMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla de aviso: error de red o menu vacio.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: AppTheme.discoveryAccent),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.discoveryPaper,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppTheme.discoveryPaper),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
