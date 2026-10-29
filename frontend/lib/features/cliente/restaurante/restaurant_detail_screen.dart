import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../core/money.dart';
import '../../../models/menu_category.dart';
import '../../../models/product.dart';
import '../../../models/restaurant.dart';
import '../carrito/cart.dart';
import '../carrito/cart_provider.dart';
import '../carrito/cart_sheet.dart';
import 'restaurant_detail_repository.dart';
import 'restaurant_profile_widgets.dart';

/// La carta de un restaurante.
///
/// Es la pantalla a la que se llega desde el Home. Hasta ahora ese toque no
/// llevaba a ningun lado: la tarjeta aceptaba 'onTap' y nadie se lo pasaba.
///
/// El menu que se ve es el del CLIENTE: sin platos agotados y sin categorias
/// vacias. El filtro lo hace el backend.
///
/// Tocar un plato abre su detalle, con el boton de agregar al carrito. Y abajo
/// aparece la barrita con lo que ya llevas.
class RestaurantDetailScreen extends ConsumerStatefulWidget {
  const RestaurantDetailScreen({
    required this.restaurant,
    this.latitude,
    this.longitude,
    super.key,
  });

  /// El restaurante que se toco. Se usa para pintar el encabezado MIENTRAS
  /// carga: asi la pantalla no abre en blanco.
  final Restaurant restaurant;

  /// La ubicacion del cliente, para que el backend resuelva la distancia y la
  /// tarifa de envio.
  final double? latitude;
  final double? longitude;

  @override
  ConsumerState<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState
    extends ConsumerState<RestaurantDetailScreen> {
  late Future<RestaurantDetail> _future;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<RestaurantDetail> _load() {
    return RestaurantDetailRepository(ApiClient()).load(
      widget.restaurant.id,
      latitude: widget.latitude,
      longitude: widget.longitude,
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  /// El mensaje a mostrar cuando falla la carga.
  ///
  /// Si el error vino de la API, ya trae el texto en espanol listo para
  /// mostrar (ApiException lo arma). Si fue otra cosa, se usa uno generico en
  /// vez del 'toString()' de Dart, que no le dice nada a nadie.
  String _errorMessage(Object? error) {
    return error is ApiException
        ? error.message
        : 'No pudimos cargar la carta.';
  }

  /// Abre el detalle del plato.
  ///
  /// La biblia lo pide como modal o bottom sheet: el cliente mira el plato sin
  /// perder de vista la carta que tenia atras.
  void _openProduct(Product product) {
    final Cart cart = ref.read(cartProvider);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.discoveryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (BuildContext sheetContext) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.discoveryAccent,
            surface: AppTheme.discoveryBackground,
            onSurface: AppTheme.discoveryPaper,
          ),
        ),
        child: _ProductSheet(
          product: product,
          quantityInCart: cart.quantityOf(product.id),
          onAdd: (quantity) {
            Navigator.of(sheetContext).pop();
            _add(product, quantity);
          },
        ),
      ),
    );
  }

  /// Agrega la cantidad elegida del plato al carrito.
  Future<void> _add(Product product, int quantity) async {
    final CartNotifier cart = ref.read(cartProvider.notifier);
    final Restaurant restaurant = widget.restaurant;

    final bool added = await cart.add(
      product,
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      quantity: quantity,
    );

    // Se agrego bien, o la pantalla ya no esta.
    if (added || !mounted) {
      return;
    }

    // El carrito es de OTRO restaurante. No se vacia solo: se pregunta.
    final bool confirmed = await _confirmReplace(restaurant.name) ?? false;

    if (!confirmed || !mounted) {
      return;
    }

    await cart.clear();
    await cart.add(
      product,
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      quantity: quantity,
    );
  }

  /// Pregunta si se empieza de nuevo con el carrito del otro restaurante.
  ///
  /// Se pregunta en vez de vaciarlo sin avisar porque el cliente puede haber
  /// armado un pedido con calma en el otro local.
  Future<bool?> _confirmReplace(String restaurantName) {
    final String? current = ref.read(cartProvider).restaurantName;

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('¿Empezar de nuevo?'),
        content: Text(
          'Tu pedido es de ${current ?? 'otro restaurante'}. Para pedir en '
          '$restaurantName hay que vaciarlo, porque un pedido va a un solo '
          'restaurante.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.coral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Vaciar y agregar'),
          ),
        ],
      ),
    );
  }

  void _showInfo(Restaurant restaurant) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(restaurant.name),
        content: SingleChildScrollView(
          child: Text(
            [
              restaurant.address,
              if (restaurant.phone?.isNotEmpty ?? false)
                'Teléfono: ${restaurant.phone}',
            ].join('\n\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.discoveryAccent,
          onPrimary: AppTheme.discoveryBackground,
          surface: AppTheme.discoveryBackground,
          onSurface: AppTheme.discoveryPaper,
          onSurfaceVariant: AppTheme.discoveryMuted,
          secondaryContainer: AppTheme.yellow,
          onSecondaryContainer: AppTheme.discoveryBackground,
        ),
        textTheme: theme.textTheme.apply(
          bodyColor: AppTheme.discoveryPaper,
          displayColor: AppTheme.discoveryPaper,
        ),
      ),
      child: Scaffold(
        backgroundColor: AppTheme.discoveryBackground,
        appBar: AppBar(
          backgroundColor: AppTheme.discoveryBackground,
          foregroundColor: AppTheme.discoveryPaper,
          surfaceTintColor: Colors.transparent,
          title: const Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'toro',
                  style: TextStyle(color: AppTheme.discoveryPaper),
                ),
                TextSpan(
                  text: 'go',
                  style: TextStyle(color: AppTheme.yellow),
                ),
                TextSpan(
                  text: '.',
                  style: TextStyle(color: AppTheme.discoveryAccent),
                ),
              ],
            ),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 25,
              letterSpacing: -1.4,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Información',
              onPressed: () => _showInfo(widget.restaurant),
              icon: const Icon(Icons.info_outline),
            ),
          ],
        ),
        bottomNavigationBar: ref.watch(cartProvider).isEmpty
            ? const RestaurantEmptyCartBar()
            : CartBar(restaurantId: widget.restaurant.id, discovery: true),
        body: FutureBuilder<RestaurantDetail>(
          future: _future,
          builder: (context, snapshot) {
            final restaurant = snapshot.data?.restaurant ?? widget.restaurant;
            final categories = snapshot.data?.categories ?? <MenuCategory>[];
            String? coverUrl = restaurant.coverUrl;
            for (final category in categories) {
              if (coverUrl != null) {
                break;
              }
              for (final product in category.products) {
                if (product.imageUrl?.isNotEmpty ?? false) {
                  coverUrl = product.imageUrl;
                  break;
                }
              }
              if (coverUrl != null) {
                break;
              }
            }
            final selected =
                categories.any((category) => category.id == _categoryId)
                ? _categoryId
                : null;
            return ListView(
              children: [
                RestaurantProfileCover(
                  imageUrl: coverUrl,
                  isOpen: restaurant.isOpen,
                ),
                RestaurantProfileHeader(
                  restaurant: restaurant,
                  onInfo: () => _showInfo(restaurant),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HECHO CERCA.',
                        style: TextStyle(
                          color: AppTheme.yellow,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tu próximo antojo\nempieza aquí.',
                        style: TextStyle(
                          color: AppTheme.discoveryPaper,
                          fontSize: 23,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        '¿Qué vas a pedir?',
                        style: TextStyle(
                          color: AppTheme.discoveryPaper,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (categories.isNotEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _categoryButton('Todo el menú', null, selected),
                              for (final category in categories)
                                _categoryButton(
                                  category.name,
                                  category.id,
                                  selected,
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Center(child: CircularProgressIndicator())
                      else if (snapshot.hasError)
                        _ErrorBox(
                          message: _errorMessage(snapshot.error),
                          onRetry: _reload,
                        )
                      else if (!(snapshot.data?.hasMenu ?? false))
                        const _EmptyMenu()
                      else
                        for (final category in categories.where(
                          (category) =>
                              selected == null || category.id == selected,
                        )) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              category.name,
                              style: const TextStyle(
                                color: AppTheme.discoveryMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          RestaurantProductGrid(
                            products: category.products,
                            onOpen: _openProduct,
                          ),
                        ],
                      const SizedBox(height: 12),
                      const RestaurantMenuFooter(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _categoryButton(String label, int? id, int? selected) => Padding(
    padding: const EdgeInsets.only(right: 18),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: id == selected
                ? AppTheme.discoveryAccent
                : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: TextButton(
        onPressed: () => setState(() => _categoryId = id),
        style: TextButton.styleFrom(
          foregroundColor: id == selected
              ? AppTheme.discoveryAccent
              : AppTheme.discoveryMuted,
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label),
      ),
    ),
  );
}

/// La carta esta vacia (todos los platos agotados, o el restaurante no cargo
/// ninguno).
class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF204555),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.restaurant_menu_rounded,
            size: 40,
            color: AppTheme.yellow,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Por ahora no hay platos disponibles',
            textAlign: TextAlign.center,
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.discoveryPaper,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'El restaurante no tiene nada cargado o se le agotó todo.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: AppTheme.discoveryPaper),
          ),
        ],
      ),
    );
  }
}

/// El aviso de error, con boton para reintentar.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF204555),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.cloud_off_rounded, size: 40, color: AppTheme.teal),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppTheme.discoveryPaper),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

/// La hoja con el detalle de un plato, y el boton de agregar.
///
/// La biblia la pide asi: *"Detalle de producto (modal/bottom sheet)"*.
class _ProductSheet extends StatefulWidget {
  const _ProductSheet({
    required this.product,
    required this.quantityInCart,
    required this.onAdd,
  });

  final Product product;

  /// Cuantas unidades hay ya en el carrito. Se avisa para que el cliente no
  /// agregue dos veces creyendo que la primera no entro.
  final int quantityInCart;

  final ValueChanged<int> onAdd;

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (widget.product.imageUrl?.isNotEmpty ?? false) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    widget.product.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.product.name,
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.discoveryPaper,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar detalle',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppTheme.discoveryPaper,
                  ),
                ],
              ),
              if (widget.product.description != null &&
                  widget.product.description!.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  widget.product.description!,
                  style: text.bodyMedium?.copyWith(
                    color: AppTheme.discoveryMuted,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (widget.product.hasDiscount)
                Text(
                  '\$${widget.product.regularPrice}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.discoveryMuted,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                '\$${widget.product.price}',
                style: text.headlineSmall?.copyWith(
                  color: AppTheme.discoveryAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'por unidad',
                style: text.bodySmall?.copyWith(color: AppTheme.discoveryMuted),
              ),
              if (widget.quantityInCart > 0) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.quantityInCart == 1
                      ? 'Ya tenés 1 en el carrito.'
                      : 'Ya tenés ${widget.quantityInCart} en el carrito.',
                  style: text.bodySmall?.copyWith(color: AppTheme.yellow),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Cantidad',
                      style: text.titleSmall?.copyWith(
                        color: AppTheme.discoveryPaper,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Disminuir cantidad',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      label: '$_quantity unidades',
                      child: Text('$_quantity', style: text.titleMedium),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Aumentar cantidad',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => setState(() => _quantity++),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => widget.onAdd(_quantity),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 54),
                    backgroundColor: AppTheme.discoveryAccent,
                    foregroundColor: AppTheme.discoveryBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.image),
                    ),
                  ),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                  label: Text(
                    'Agregar al carrito · \$${Money.multiply(widget.product.price, _quantity)}',
                    style: text.labelLarge?.copyWith(
                      color: AppTheme.discoveryBackground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
