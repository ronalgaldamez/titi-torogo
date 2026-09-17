import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../models/restaurant.dart';

/// La tarjeta de un restaurante.
///
/// Sigue el patron de las apps de delivery de verdad (Glovo, Rappi,
/// Uber Eats y las referencias que mandaste):
///
///   1. Una PORTADA grande de color  <- esto es lo que le da "cuerpo"
///   2. El nombre y la descripcion
///   3. Bloques de datos con icono: tiempo, distancia y envio
///
/// Cuando el restaurante suba su foto, la portada de color se reemplaza
/// sola por la imagen. Mientras tanto, el bloque de color con la inicial
/// se ve INTENCIONAL en vez de roto.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({required this.restaurant, this.onTap, super.key});

  final Restaurant restaurant;
  final VoidCallback? onTap;

  /// Colores de portada, repartidos por id.
  ///
  /// Son los 4 tonos de la paleta de marca, asi que la lista se ve viva
  /// SIN salirse de "paleta limitada y consistente" (AGENDS).
  static const List<List<Color>> _covers = <List<Color>>[
    <Color>[AppTheme.teal, Colors.white],
    <Color>[AppTheme.coral, Colors.white],
    <Color>[AppTheme.mint, AppTheme.navy],
    <Color>[AppTheme.tealDeep, Colors.white],
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final BorderRadius radius = BorderRadius.circular(AppRadius.card);
    final List<Color> cover = _covers[restaurant.id % _covers.length];

    return Material(
      color: colors.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _Cover(restaurant: restaurant, cover: cover),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (restaurant.isBusy) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        _Pill(
                          label: 'Muy ocupado',
                          background: AppTheme.yellow,
                          foreground: AppTheme.navy,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    restaurant.description ?? restaurant.address,
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _MetaRow(restaurant: restaurant, colors: colors, text: text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La portada: la foto del restaurante, o un bloque de color con su inicial.
class _Cover extends StatelessWidget {
  const _Cover({required this.restaurant, required this.cover});

  final Restaurant restaurant;
  final List<Color> cover;

  @override
  Widget build(BuildContext context) {
    final String? url = restaurant.logoUrl;

    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        height: 140,
        width: double.infinity,
        fit: BoxFit.cover,
        // Si la foto no carga, cae al bloque de color en vez de romperse.
        errorBuilder: (_, _, _) => _ColorBlock(restaurant: restaurant, cover: cover),
      );
    }

    return _ColorBlock(restaurant: restaurant, cover: cover);
  }
}

class _ColorBlock extends StatelessWidget {
  const _ColorBlock({required this.restaurant, required this.cover});

  final Restaurant restaurant;
  final List<Color> cover;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      width: double.infinity,
      color: cover[0],
      alignment: Alignment.center,
      child: Text(
        restaurant.name.isEmpty
            ? '?'
            : restaurant.name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: 54,
          fontWeight: FontWeight.w800,
          color: cover[1],
        ),
      ),
    );
  }
}

/// Tiempo, distancia y tarifa, como bloques con icono.
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        // Expanded + Wrap: si las dos pildoras no caben en un telefono
        // angosto, la segunda baja a la linea de abajo en vez de desbordar.
        Expanded(
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              _Stat(
                icon: Icons.schedule_rounded,
                label: '${restaurant.estimatedDeliveryMinutes} min',
                colors: colors,
                text: text,
              ),
              if (restaurant.distanceKm != null)
                _Stat(
                  icon: Icons.near_me_rounded,
                  label: '${restaurant.distanceKm} km',
                  colors: colors,
                  text: text,
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              'envio',
              style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            Text(
              '\$${restaurant.deliveryFee}',
              style: text.titleMedium?.copyWith(
                color: AppTheme.coral,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bloque de dato con icono, tipo "30 min" o "1.2 km".
class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.colors,
    required this.text,
  });

  final IconData icon;
  final String label;
  final ColorScheme colors;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
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

/// Etiqueta redondeada, tipo "Muy ocupado".
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
