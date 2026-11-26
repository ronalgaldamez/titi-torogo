import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../checkout_appearance.dart';
import '../pedido/checkout_screen.dart';
import 'cart.dart';
import 'cart_provider.dart';

/// La barrita que aparece abajo cuando hay algo en el carrito.
///
/// Aparece SOLA cuando hay algo adentro, y desaparece cuando no: no ocupa
/// lugar en la pantalla si no hay nada que mostrar.
class CartBar extends ConsumerWidget {
  const CartBar({this.restaurantId, this.discovery = false, super.key});

  final bool discovery;

  /// El restaurante cuya carta se esta mirando. null = no se sabe (o no
  /// importa, porque la barrita no esta dentro de una carta).
  ///
  /// Sirve para un caso concreto y molesto: el carrito es de UN restaurante, y
  /// si el cliente se mete a la carta de otro, la barrita le sigue mostrando el
  /// pedido viejo. Sin decir de quien es, toca "Ver pedido" creyendo que va a
  /// pedir lo que acaba de ver, y termina en el checkout del otro.
  final int? restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Cart cart = ref.watch(cartProvider);

    if (cart.isEmpty) {
      return const SizedBox.shrink();
    }

    final TextTheme text = Theme.of(context).textTheme;
    final foreground = discovery ? AppTheme.discoveryBackground : Colors.white;

    final bool fromAnother =
        restaurantId != null &&
        cart.restaurantId != null &&
        cart.restaurantId != restaurantId;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Material(
          color: discovery ? AppTheme.discoveryAccent : AppTheme.tealDeep,
          borderRadius: BorderRadius.circular(AppRadius.image),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              final bool? go = await CartSheet.show(context);

              if ((go ?? false) && context.mounted) {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const CheckoutScreen(),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.shopping_cart_outlined, color: foreground),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (fromAnother)
                          Text(
                            'Pedido de '
                            '${cart.restaurantName ?? 'otro restaurante'}',
                            style: text.labelSmall?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          'Ver pedido',
                          style: text.titleSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cart.totalUnits == 1
                              ? '1 producto'
                              : '${cart.totalUnits} productos',
                          style: text.bodySmall?.copyWith(color: foreground),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        'Subtotal',
                        style: text.labelSmall?.copyWith(color: foreground),
                      ),
                      Text(
                        '\$${cart.subtotal}',
                        style: text.titleMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.chevron_right_rounded, color: foreground),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Devuelve true al continuar para que la ruta que abrió la hoja navegue.
class CartSheet extends ConsumerWidget {
  const CartSheet({super.key});

  static Future<bool?> show(BuildContext context) => showModalBottomSheet<bool>(
    context: context,
    backgroundColor: flowSheet,
    barrierColor: const Color(0xA6040E17),
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const CartSheet(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final theme = checkoutTheme(context);

    Future<void> clearCart() async {
      final route = ModalRoute.of(context);
      await ref.read(cartProvider.notifier).clear();
      if (context.mounted && route?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    }

    return Theme(
      data: theme,
      child: Material(
        color: flowSheet,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CheckoutHeading(
                        'Tu carrito',
                        caption: cart.restaurantName,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar carrito',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (cart.isEmpty)
                  const Text('Tu carrito está vacío.')
                else ...[
                  for (final (index, item) in cart.items.indexed) ...[
                    const Divider(height: 1),
                    _ItemRow(
                      item: item,
                      onClear: index == 0 ? clearCart : null,
                    ),
                  ],
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      const Expanded(child: Text('Subtotal')),
                      Text(
                        '\$${cart.subtotal}',
                        style: const TextStyle(
                          color: AppTheme.discoveryAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'El envío se calcula al elegir la dirección.',
                    style: TextStyle(color: AppTheme.discoveryMuted),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CheckoutAction(
                    'Continuar a la entrega',
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item, this.onClear});

  final CartItem item;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(cartProvider.notifier);
    final product = item.product;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        children: [
          Row(
            children: [
              CheckoutThumbnail(product.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '\$${product.price} c/u',
                      style: const TextStyle(color: AppTheme.discoveryMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '\$${item.subtotal}',
                style: const TextStyle(
                  color: AppTheme.discoveryAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: flowRule),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          minimumSize: const Size.square(48),
                        ),
                        tooltip: 'Quitar una unidad de ${product.name}',
                        onPressed: () => notifier.decrease(product.id),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Text('${item.quantity}'),
                      IconButton(
                        style: IconButton.styleFrom(
                          minimumSize: const Size.square(48),
                        ),
                        tooltip: 'Agregar una unidad de ${product.name}',
                        onPressed: () {
                          final cart = ref.read(cartProvider);
                          notifier.add(
                            product,
                            restaurantId: cart.restaurantId!,
                            restaurantName: cart.restaurantName ?? '',
                          );
                        },
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
                if (onClear != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.discoveryAccent,
                    ),
                    onPressed: onClear,
                    child: const Text('Vaciar carrito'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
