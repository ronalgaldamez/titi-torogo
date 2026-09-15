import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../models/restaurant.dart';

/// Una tarjeta de restaurante en la lista del Home.
///
/// Muestra lo que el cliente necesita para decidir sin entrar: nombre,
/// que vende, cuanto tarda, a que distancia esta y cuanto cuesta el envio.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({required this.restaurant, super.key});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Logo(restaurant: restaurant, colors: colors),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        restaurant.name,
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (restaurant.isBusy) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      _BusyBadge(colors: colors, text: text),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  restaurant.description ?? restaurant.address,
                  style: text.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                _MetaRow(
                  restaurant: restaurant,
                  colors: colors,
                  text: text,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El logo, o un cuadrado con la inicial mientras no haya foto.
class _Logo extends StatelessWidget {
  const _Logo({required this.restaurant, required this.colors});

  final Restaurant restaurant;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final String? url = restaurant.logoUrl;

    if (url == null || url.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          restaurant.name.isEmpty
              ? '?'
              : restaurant.name.substring(0, 1).toUpperCase(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        // Si el logo no carga, no rompemos la tarjeta.
        errorBuilder: (_, _, _) => Container(
          width: 56,
          height: 56,
          color: colors.surfaceContainerHighest,
          child: Icon(Icons.storefront, color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Tiempo de entrega y distancia.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.restaurant,
    required this.colors,
    required this.text,
  });

  final Restaurant restaurant;
  final ColorScheme colors;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style =
        text.bodySmall?.copyWith(color: colors.onSurfaceVariant);

    return Row(
      children: <Widget>[
        Icon(Icons.schedule, size: 14, color: colors.onSurfaceVariant),
        const SizedBox(width: AppSpacing.xs),
        Text('${restaurant.estimatedDeliveryMinutes} min', style: style),
        if (restaurant.distanceKm != null) ...<Widget>[
          Text('  ·  ', style: style),
          Icon(Icons.place_outlined, size: 14, color: colors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text('${restaurant.distanceKm} km', style: style),
        ],
        const Spacer(),
        Text(
          'Envio \$${restaurant.deliveryFee}',
          style: text.bodySmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Marca de "muy ocupado": el AGENDS dice que alarga los tiempos.
class _BusyBadge extends StatelessWidget {
  const _BusyBadge({required this.colors, required this.text});

  final ColorScheme colors;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Muy ocupado',
        style: text.labelSmall?.copyWith(color: colors.onTertiaryContainer),
      ),
    );
  }
}
