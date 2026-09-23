import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../models/menu_category.dart';
import '../../../models/product.dart';
import '../../../models/restaurant.dart';
import '../carrito/cart.dart';
import '../carrito/cart_provider.dart';
import '../carrito/cart_sheet.dart';
import 'restaurant_detail_repository.dart';

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
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (BuildContext sheetContext) => _ProductSheet(
        product: product,
        quantityInCart: cart.quantityOf(product.id),
        onAdd: () {
          Navigator.of(sheetContext).pop();
          _add(product);
        },
      ),
    );
  }

  /// Agrega una unidad del plato al carrito.
  Future<void> _add(Product product) async {
    final CartNotifier cart = ref.read(cartProvider.notifier);
    final Restaurant restaurant = widget.restaurant;

    final bool added = await cart.add(
      product,
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
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
          widget.restaurant.name,
          style: text.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      // La barrita del carrito. Se muestra sola cuando hay algo adentro.
      bottomNavigationBar: const CartBar(),
      body: FutureBuilder<RestaurantDetail>(
        future: _future,
        builder: (
          BuildContext context,
          AsyncSnapshot<RestaurantDetail> snapshot,
        ) {
          // Mientras carga se ve el encabezado con los datos que ya tenemos
          // del Home, y solo la carta queda esperando.
          final Restaurant restaurant =
              snapshot.data?.restaurant ?? widget.restaurant;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            children: <Widget>[
              _Header(restaurant: restaurant),
              const SizedBox(height: AppSpacing.lg),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                _ErrorBox(
                  message: _errorMessage(snapshot.error),
                  onRetry: _reload,
                )
              else if (!(snapshot.data?.hasMenu ?? false))
                const _EmptyMenu()
              else
                for (final MenuCategory category
                    in snapshot.data!.categories) ...<Widget>[
                  _CategoryHeader(category: category),
                  for (final Product product in category.products)
                    _ProductRow(
                      product: product,
                      onTap: () => _openProduct(product),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                ],
            ],
          );
        },
      ),
    );
  }
}

/// El encabezado: portada de color, nombre, direccion y los tres datos que le
/// importan al cliente.
class _Header extends StatelessWidget {
  const _Header({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<Color> cover = AppTheme.coverFor(restaurant.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // La misma portada que la tarjeta del Home, con el MISMO color: por
        // eso el color se pide al tema y no se elige aca.
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: cover[0],
            borderRadius: BorderRadius.circular(AppRadius.image),
          ),
          alignment: Alignment.center,
          child: Text(
            restaurant.name.isEmpty
                ? '?'
                : restaurant.name.substring(0, 1).toUpperCase(),
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w800,
              color: cover[1],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          restaurant.name,
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        if (restaurant.description != null &&
            restaurant.description!.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            restaurant.description!,
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            Icon(
              Icons.place_outlined,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                restaurant.address,
                style: text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _Stat(
              icon: Icons.schedule_rounded,
              label: '${restaurant.estimatedDeliveryMinutes} min',
            ),
            if (restaurant.distanceKm != null)
              _Stat(
                icon: Icons.near_me_rounded,
                label: '${restaurant.distanceKm} km',
              ),
            if (restaurant.deliveryFee != null)
              _Stat(
                icon: Icons.delivery_dining_rounded,
                label: 'envío \$${restaurant.deliveryFee}',
              ),
          ],
        ),
        // El aviso de cerrado o muy ocupado. Va abajo de los datos, no
        // arriba: primero el cliente ve QUE hay, despues cuando.
        if (!restaurant.isOpen || restaurant.isBusy) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _Notice(
            message: restaurant.isOpen
                ? 'Este restaurante está muy ocupado: puede tardar más.'
                : 'Está cerrado en este momento.',
            background: restaurant.isOpen ? AppTheme.yellow : AppTheme.coral,
          ),
        ],
      ],
    );
  }
}

/// Un dato con icono, tipo "30 min" o "envío $2.00".
class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F6),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppTheme.teal),
          const SizedBox(width: 4),
          Text(
            label,
            style: text.labelMedium?.copyWith(
              color: AppTheme.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Una franja de aviso.
class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.background});

  /// OJO con el nombre: es 'message' y no 'text' a proposito.
  ///
  /// Adentro de build hay un `TextTheme text`, y si el campo se llamara igual,
  /// el local taparia al campo: el `Text()` terminaria recibiendo el tema en
  /// vez del mensaje, y no compila.
  final String message;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color foreground = background == AppTheme.yellow
        ? AppTheme.navy
        : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        message,
        style: text.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// El encabezado de una categoria del menu.
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category});

  final MenuCategory category;

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
              category.name,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            category.productCount == 1
                ? '1 plato'
                : '${category.productCount} platos',
            style: text.labelMedium?.copyWith(color: AppTheme.teal),
          ),
        ],
      ),
    );
  }
}

/// Un plato de la carta.
///
/// Se toca para ver el detalle y agregarlo. El toque NO agrega directo: la
/// biblia pide el detalle del plato, y ademas agregar sin querer es la forma
/// mas facil de armarle a alguien un pedido que no pidio.
class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        product.name,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                      ),
                      if (product.description != null &&
                          product.description!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          product.description!,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
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
        ),
      ),
    );
  }
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
        color: AppTheme.tealSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.restaurant_menu_rounded,
            size: 40,
            color: AppTheme.tealDeep,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Por ahora no hay platos disponibles',
            textAlign: TextAlign.center,
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'El restaurante no tiene nada cargado o se le agotó todo.',
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: AppTheme.navy),
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
        color: AppTheme.tealSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.cloud_off_rounded, size: 40, color: AppTheme.teal),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppTheme.navy),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

/// La hoja con el detalle de un plato, y el boton de agregar.
///
/// La biblia la pide asi: *"Detalle de producto (modal/bottom sheet)"*.
class _ProductSheet extends StatelessWidget {
  const _ProductSheet({
    required this.product,
    required this.quantityInCart,
    required this.onAdd,
  });

  final Product product;

  /// Cuantas unidades hay ya en el carrito. Se avisa para que el cliente no
  /// agregue dos veces creyendo que la primera no entro.
  final int quantityInCart;

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              product.name,
              style: text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
            if (product.description != null &&
                product.description!.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                product.description!,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              '\$${product.price}',
              style: text.headlineSmall?.copyWith(
                color: AppTheme.coral,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (quantityInCart > 0) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                quantityInCart == 1
                    ? 'Ya tenés 1 en el carrito.'
                    : 'Ya tenés $quantityInCart en el carrito.',
                style: text.bodySmall?.copyWith(color: AppTheme.tealDeep),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                label: const Text(
                  'Agregar al carrito',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
