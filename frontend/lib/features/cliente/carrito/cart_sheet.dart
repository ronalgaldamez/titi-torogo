import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import 'cart.dart';
import 'cart_provider.dart';

/// La barrita que aparece abajo cuando hay algo en el carrito.
///
/// Aparece SOLA cuando hay algo adentro, y desaparece cuando no: no ocupa
/// lugar en la pantalla si no hay nada que mostrar.
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Cart cart = ref.watch(cartProvider);

    if (cart.isEmpty) {
      return const SizedBox.shrink();
    }

    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Material(
          color: AppTheme.teal,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => CartSheet.show(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  // El globito con cuantas unidades llevas. Es el dato que el
                  // cliente busca de reojo mientras sigue mirando la carta.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.yellow,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${cart.totalUnits}',
                      style: text.labelLarge?.copyWith(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Ver pedido',
                      style: text.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '\$${cart.subtotal}',
                    style: text.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
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
}

/// La hoja con el pedido armado.
///
/// Se abre desde la barrita. Sirve para repasar y ajustar cantidades antes de
/// seguir, sin salir de la carta.
///
/// Todavia NO tiene el boton de continuar: el checkout (elegir direccion y
/// confirmar) viene en el paso siguiente, y un boton que no lleva a ningun
/// lado es peor que no tener boton.
class CartSheet extends ConsumerWidget {
  const CartSheet({super.key});

  /// Abre la hoja desde abajo.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (BuildContext context) => const CartSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Cart cart = ref.watch(cartProvider);
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8DEE3),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              cart.restaurantName ?? 'Tu pedido',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (cart.isEmpty)
              Text(
                'Tu carrito está vacío.',
                style: text.bodyMedium?.copyWith(color: AppTheme.navy),
              )
            else ...<Widget>[
              for (final CartItem item in cart.items) _ItemRow(item: item),
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Subtotal',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy,
                      ),
                    ),
                  ),
                  Text(
                    '\$${cart.subtotal}',
                    style: text.titleMedium?.copyWith(
                      color: AppTheme.coral,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              // El envio NO se muestra con un numero inventado: depende de la
              // direccion, y eso se elige en el checkout.
              Text(
                'El envío se calcula al elegir la dirección.',
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () async {
                    await ref.read(cartProvider.notifier).clear();

                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Vaciar carrito'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Una linea del pedido, con los botones de cantidad.
class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.product.name,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${item.product.price} c/u',
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // Los botones de cantidad. El de menos, cuando queda en 1 unidad,
          // saca la linea entera: mantener una linea de cero no tiene sentido.
          _RoundButton(
            icon: Icons.remove_rounded,
            onPressed: () =>
                ref.read(cartProvider.notifier).decrease(item.product.id),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
          ),
          _RoundButton(
            icon: Icons.add_rounded,
            onPressed: () => ref.read(cartProvider.notifier).add(
                  item.product,
                  restaurantId: ref.read(cartProvider).restaurantId!,
                  restaurantName: ref.read(cartProvider).restaurantName ?? '',
                ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '\$${item.subtotal}',
              textAlign: TextAlign.right,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.coral,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un boton redondo chiquito, para sumar y restar.
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: AppTheme.tealSoft,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(icon, size: 18, color: AppTheme.tealDeep),
        ),
      ),
    );
  }
}
