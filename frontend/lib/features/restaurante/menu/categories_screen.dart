import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../models/menu_category.dart';
import 'menu_repository.dart';

/// Las categorias del menu: crear, renombrar y borrar.
///
/// Es la parte de "Categorias del menu" del AGENDS. Las categorias son lo que
/// le da orden a la carta: sin ellas el cliente ve una lista larga de platos
/// sueltos y no encuentra nada.
///
/// Esta pantalla NO devuelve nada al cerrarse: la pantalla del menu se
/// recarga siempre al volver. Una peticion de mas cuesta menos que mostrar
/// datos viejos.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({required this.categories, super.key});

  /// Las que ya tenia el menu, para no abrir con un circulo de carga.
  final List<MenuCategory> categories;

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final Session _session = Session(AuthStorage());

  late List<MenuCategory> _categories = widget.categories;

  /// Mientras hay una peticion en vuelo no se deja tocar nada: dos toques
  /// seguidos sobre "borrar" mandarian dos borrados y el segundo daria 404.
  bool _busy = false;

  Future<void> _reload() async {
    try {
      final ApiClient api = await _session.client();
      final MenuData data = await MenuRepository(api).load();

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = data.categories;
        _busy = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _busy = false);
      _showError(error.message);
    }
  }

  /// Hace una accion contra la API y despues recarga la lista.
  ///
  /// Las tres acciones comparten esto: bloquear, avisar si falla y volver a
  /// pedir las categorias. Escribirlo tres veces es pedir que una quede
  /// distinta de las otras.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);

    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _busy = false);
      _showError(error.message);
      return;
    }

    if (!mounted) {
      return;
    }

    await _reload();
  }

  Future<void> _create() async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) =>
          const _NameDialog(title: 'Nueva categoría'),
    );

    if (name == null || !mounted) {
      return;
    }

    await _run(() async {
      final ApiClient api = await _session.client();
      await MenuRepository(api).createCategory(name);
    });
  }

  Future<void> _rename(MenuCategory category) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _NameDialog(
        title: 'Renombrar categoría',
        initial: category.name,
      ),
    );

    // Si no cambio nada, no se molesta al servidor.
    if (name == null || name == category.name || !mounted) {
      return;
    }

    await _run(() async {
      final ApiClient api = await _session.client();
      await MenuRepository(api).updateCategory(id: category.id, name: name);
    });
  }

  Future<void> _delete(MenuCategory category) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('¿Borrar "${category.name}"?'),
        // El aviso cambia segun tenga platos o no. Es la diferencia entre
        // "no pasa nada" y "tus platos se van a desacomodar".
        content: Text(
          category.productCount == 0
              ? 'La categoría está vacía: no se pierde ningún plato.'
              : 'Sus ${category.productCount} platos NO se borran: quedan sin '
                  'categoría y los podés volver a acomodar.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false) || !mounted) {
      return;
    }

    await _run(() async {
      final ApiClient api = await _session.client();
      await MenuRepository(api).deleteCategory(category.id);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
          'Categorías',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(minHeight: 4),
              )
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _create,
        backgroundColor: AppTheme.coral,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva categoría'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    final TextTheme text = Theme.of(context).textTheme;

    if (_categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.category_outlined,
                size: 48,
                color: AppTheme.teal,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Todavía no tenés categorías',
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Creá la primera para poder ordenar tus platos.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: AppTheme.navy),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl * 3,
      ),
      children: <Widget>[
        for (final MenuCategory category in _categories)
          _CategoryRow(
            category: category,
            onRename: _busy ? null : () => _rename(category),
            onDelete: _busy ? null : () => _delete(category),
          ),
      ],
    );
  }
}

/// Una categoria en la lista: se toca para renombrarla, o se borra.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onRename,
    required this.onDelete,
  });

  final MenuCategory category;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onRename,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        category.name,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.productCount == 1
                            ? '1 plato'
                            : '${category.productCount} platos',
                        style: text.labelMedium?.copyWith(
                          color: AppTheme.teal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: AppTheme.coral,
                  tooltip: 'Borrar categoría',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El cuadro para pedir o editar el nombre de una categoria.
///
/// Es un widget con estado propio y no un par de lineas dentro del dialogo
/// porque el `TextEditingController` tiene que vivir y morir con el. Crearlo
/// afuera y liberarlo al cerrar deja un hueco: Flutter lo sigue usando
/// mientras el cuadro se esta cerrando.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _controller.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Poné un nombre.');
      return;
    }

    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Nombre',
          hintText: 'Postres',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
