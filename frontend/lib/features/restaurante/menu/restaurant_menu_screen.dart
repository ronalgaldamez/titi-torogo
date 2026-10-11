import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/filter_tabs.dart';
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
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Mi menú',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _openCategories,
            icon: const Icon(Icons.category_outlined),
            color: AppTheme.navy,
            tooltip: 'Categorías',
          ),
          if (widget.onLogout != null)
            IconButton(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded),
              color: AppTheme.navy,
              tooltip: 'Cerrar sesión',
            ),
        ],
      ),
      body: _body(),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton.icon(
            onPressed: _loading || _error != null
                ? null
                : () => _openForm(categoryId: _category > 0 ? _category : null),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.coral,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar plato'),
          ),
        ),
      ),
    );
  }

  Widget _body() {
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() => _page = 0),
                decoration: InputDecoration(
                  hintText: 'Buscar un plato',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.image),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.image),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.image),
                    borderSide: const BorderSide(color: AppTheme.teal),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilterTabs(
                labels: const ['Todos', 'Disponibles', 'Agotados'],
                selectedIndex: _availability == -1
                    ? 0
                    : (_availability == 1 ? 1 : 2),
                onSelected: (index) => setState(() {
                  _availability = [-1, 1, 0][index];
                  _page = 0;
                }),
                keyPrefix: 'menu-availability',
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const ValueKey('menu-category-filter'),
                  onPressed: _pickCategory,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.tealDeep,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    minimumSize: const Size(0, 48),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      const Icon(Icons.tune_rounded, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _category == -1
                              ? 'Todas las categorías'
                              : _category == 0
                              ? 'Sin categoría'
                              : _categories
                                    .firstWhere(
                                      (category) => category.id == _category,
                                    )
                                    .name,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              Wrap(
                spacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      '${filtered.length} de ${entries.length} platos',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (_category != -1 ||
                      _availability != -1 ||
                      _search.text.isNotEmpty)
                    TextButton(
                      onPressed: _resetFilters,
                      child: const Text('Limpiar filtros'),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
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
                      categoryId: entry.categoryId == 0
                          ? null
                          : entry.categoryId,
                    ),
                  ),
              ],
            ),
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
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Flexible(child: Text('Página ${page + 1} de $pages')),
              IconButton(
                tooltip: 'Página siguiente',
                onPressed: page + 1 >= pages
                    ? null
                    : () => setState(() => _page = page + 1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _pickCategory() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.background,
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
                  style: Theme.of(context).textTheme.titleMedium,
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
                        selectedColor: AppTheme.tealDeep,
                        selectedTileColor: AppTheme.tealSoft,
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
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final bool available = product.isAvailable;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: saving ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product.name,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          // Agotado: tachado y en gris. Asi el restaurante ve
                          // de un vistazo que sigue en el menu pero hoy no se
                          // puede pedir.
                          color: available
                              ? AppTheme.navy
                              : colors.onSurfaceVariant,
                          decoration: available
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$categoryName · ${available ? 'Disponible' : 'Agotado'} · Editar',
                        style: text.bodySmall?.copyWith(
                          color: AppTheme.tealDeep,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${product.price}',
                        style: text.titleSmall?.copyWith(
                          color: AppTheme.coral,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (saving)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Switch(value: available, onChanged: onChanged),
              ],
            ),
          ),
        ),
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
            Icon(icon, size: 48, color: AppTheme.teal),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppTheme.navy),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
