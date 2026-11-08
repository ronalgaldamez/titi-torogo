import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../cliente/pedido/order_presentation.dart';
import '../../shared/client_profile_widgets.dart';
import '../restaurant_sheets.dart';
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
    final String? name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OrderPresentation.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
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
    final String? name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: OrderPresentation.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
      ),
      builder: (BuildContext context) =>
          _NameDialog(title: 'Renombrar categoría', initial: category.name),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: OrderPresentation.theme(context),
    child: Scaffold(
      backgroundColor: OrderPresentation.background,
      body: SafeArea(
        child: Column(
          children: [
            const _CategoriesBrand(),
            if (_busy) const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Mi menú',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: OrderPresentation.muted,
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                          const SizedBox(height: 19),
                          const Text(
                            'CADA PLATO, EN SU LUGAR',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w700,
                              color: OrderPresentation.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: 'Categorías'),
                                TextSpan(
                                  text: '.',
                                  style: TextStyle(
                                    color: OrderPresentation.coral,
                                  ),
                                ),
                              ],
                            ),
                            style: TextStyle(
                              fontSize: 34,
                              height: 1.05,
                              letterSpacing: -1.4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Ordená tu menú a tu manera.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.65,
                              color: OrderPresentation.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_categories.isEmpty)
                    const SliverPadding(
                      padding: EdgeInsets.fromLTRB(24, 45, 24, 35),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 86,
                              height: 83,
                              child: Stack(
                                children: [
                                  Icon(
                                    Icons.category_outlined,
                                    size: 62,
                                    color: OrderPresentation.yellow,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 8,
                                    child: Icon(
                                      Icons.add_rounded,
                                      size: 30,
                                      color: OrderPresentation.coral,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 22),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        'Lo bueno empieza\ncon un poco de orden',
                                  ),
                                  TextSpan(
                                    text: '.',
                                    style: TextStyle(
                                      color: OrderPresentation.coral,
                                    ),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                fontSize: 26,
                                height: 1.12,
                                letterSpacing: -.8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 14),
                            Text(
                              'Creá tu primera categoría.\nDespués, sumá los platos que van ahí.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.65,
                                color: OrderPresentation.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
                      sliver: SliverList.builder(
                        itemCount: _categories.length,
                        itemBuilder: (context, index) => _CategoryRow(
                          category: _categories[index],
                          onRename: _busy
                              ? null
                              : () => _rename(_categories[index]),
                          onDelete: _busy
                              ? null
                              : () => _delete(_categories[index]),
                        ),
                      ),
                    ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ProfilePrimaryButton(
                            label: '+  Nueva categoría',
                            icon: Icons.north_east_rounded,
                            onPressed: _busy ? null : _create,
                          ),
                          const SizedBox(height: 13),
                          const Text(
                            'Por ejemplo: entradas, parrilla o bebidas.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: OrderPresentation.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CategoriesBrand extends StatelessWidget {
  const _CategoriesBrand();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 24),
    padding: const EdgeInsets.only(top: 24, bottom: 25),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: OrderPresentation.line)),
    ),
    child: const Row(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'toro'),
              TextSpan(
                text: 'go',
                style: TextStyle(color: OrderPresentation.yellow),
              ),
              TextSpan(
                text: '.',
                style: TextStyle(color: OrderPresentation.coral),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 29,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
            color: OrderPresentation.ink,
          ),
        ),
        SizedBox(width: 20),
        Expanded(
          child: Text(
            'MI NEGOCIO',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.8,
              color: OrderPresentation.muted,
            ),
          ),
        ),
      ],
    ),
  );
}

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
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: OrderPresentation.line)),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      onTap: onRename,
      title: Text(
        category.name,
        style: const TextStyle(fontSize: 15, color: OrderPresentation.ink),
      ),
      subtitle: Text(
        category.productCount == 0
            ? 'Sin platos todavía'
            : category.productCount == 1
            ? '1 plato'
            : '${category.productCount} platos',
        style: const TextStyle(fontSize: 11, color: OrderPresentation.muted),
      ),
      trailing: IconButton(
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline_rounded),
        color: OrderPresentation.coral,
        tooltip: 'Borrar categoría',
      ),
    ),
  );
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
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );

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
  Widget build(BuildContext context) => Theme(
    data: OrderPresentation.theme(context),
    child: RestaurantSheet(
      eyebrow: 'DALE SU LUGAR',
      title: widget.title,
      onClose: () => Navigator.pop(context),
      children: [
        const Text(
          'Un nombre corto. Un menú más claro.',
          style: TextStyle(
            fontSize: 12,
            height: 1.65,
            color: OrderPresentation.muted,
          ),
        ),
        const SizedBox(height: 31),
        const Text(
          'NOMBRE DE LA CATEGORÍA',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w700,
            color: OrderPresentation.muted,
          ),
        ),
        TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          style: const TextStyle(fontSize: 19, color: OrderPresentation.ink),
          decoration: InputDecoration(
            hintText: 'Ej. Postres',
            hintStyle: const TextStyle(color: OrderPresentation.muted),
            filled: false,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            border: const UnderlineInputBorder(),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: OrderPresentation.muted),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: OrderPresentation.coral),
            ),
            helperText: 'Así la verán tus clientes.',
            helperMaxLines: 2,
            helperStyle: const TextStyle(
              fontSize: 11,
              color: OrderPresentation.muted,
            ),
            counterStyle: const TextStyle(
              fontSize: 11,
              color: OrderPresentation.muted,
            ),
            errorText: _error,
            errorMaxLines: 3,
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 33),
        ProfilePrimaryButton(label: 'Guardar categoría', onPressed: _submit),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Volver a categorías',
            style: TextStyle(fontSize: 12, color: OrderPresentation.muted),
          ),
        ),
      ],
    ),
  );
}
