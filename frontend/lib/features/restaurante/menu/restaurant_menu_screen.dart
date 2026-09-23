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
      final Product updated = await MenuRepository(api).setAvailable(
        product.id,
        isAvailable: isAvailable,
      );

      if (!mounted) {
        return;
      }

      // Se reemplaza SOLO ese plato, con lo que devolvio el backend. Asi lo
      // que se ve es exactamente lo que quedo guardado, y no lo que creiamos.
      setState(() {
        _categories = _categories
            .map((MenuCategory category) => category.copyWith(
                  products: category.products
                      .map((Product item) =>
                          item.id == updated.id ? updated : item)
                      .toList(),
                ))
            .toList();

        _uncategorized = _uncategorized
            .map((Product item) => item.id == updated.id ? updated : item)
            .toList();
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppTheme.coral,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar plato'),
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

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.teal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          // Espacio de sobra abajo: el boton flotante de "Agregar plato" tapa
          // la ultima fila si la lista termina justo en el borde.
          AppSpacing.xl * 3,
        ),
        children: <Widget>[
          for (final MenuCategory category in _categories) ...<Widget>[
            _CategoryHeader(
              title: category.name,
              subtitle: _countLabel(category.productCount),
            ),
            ..._rowsOf(category.products, categoryId: category.id),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Los platos sin categoria van al final, en su propia seccion. Solo
          // aparece si hay alguno.
          if (_uncategorized.isNotEmpty) ...<Widget>[
            _CategoryHeader(
              title: 'Sin categoría',
              subtitle: _countLabel(_uncategorized.length),
            ),
            ..._rowsOf(_uncategorized),
          ],
        ],
      ),
    );
  }

  static String _countLabel(int count) =>
      count == 1 ? '1 plato' : '$count platos';

  /// Las filas de una lista de platos, o el aviso de que la categoria esta
  /// vacia.
  List<Widget> _rowsOf(List<Product> products, {int? categoryId}) {
    if (products.isEmpty) {
      return const <Widget>[_EmptyCategory()];
    }

    return products
        .map((Product product) => _ProductTile(
              product: product,
              saving: _saving.contains(product.id),
              onChanged: (bool value) => _toggle(product, value),
              onTap: () => _openForm(product: product, categoryId: categoryId),
            ))
        .toList();
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

/// El encabezado de una seccion: una barrita de color, el nombre y cuantos
/// platos tiene.
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: AppTheme.teal,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            subtitle,
            style: text.labelMedium?.copyWith(color: AppTheme.teal),
          ),
        ],
      ),
    );
  }
}

/// Una fila del menu: el plato a la izquierda, su interruptor a la derecha.
///
/// Tocar la fila abre el formulario para editarlo. El interruptor es SOLO
/// para agotar: son dos acciones distintas y por eso estan separadas.
class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.saving,
    required this.onChanged,
    required this.onTap,
  });

  final Product product;
  final bool saving;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final bool available = product.isAvailable;
    final String? description = product.description;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
                          decoration:
                              available ? null : TextDecoration.lineThrough,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description != null &&
                          description.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
                  Switch(
                    value: available,
                    onChanged: onChanged,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El aviso de una categoria sin platos.
class _EmptyCategory extends StatelessWidget {
  const _EmptyCategory();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.tealSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(
        'Esta categoría todavía no tiene platos.',
        style: text.bodySmall?.copyWith(color: AppTheme.tealDeep),
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
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
