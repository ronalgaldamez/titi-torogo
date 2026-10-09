import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../models/restaurant.dart';

/// Resumen del restaurante con datos reales de cobertura y envío.
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({required this.restaurant, this.onTap, super.key});
  final Restaurant restaurant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadius.image),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: constraints.maxWidth < 320 ? 80 : 104,
                  height: constraints.maxWidth < 320 ? 96 : 112,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.image),
                    child: _Cover(restaurant: restaurant),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          restaurant.name,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          restaurant.description ?? restaurant.address,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: <Widget>[
                            _Stat(
                              icon: Icons.schedule_rounded,
                              label:
                                  '${restaurant.estimatedDeliveryMinutes} min',
                            ),
                            if (restaurant.distanceKm != null)
                              _Stat(
                                icon: Icons.near_me_rounded,
                                label:
                                    '${restaurant.distanceKm!.toStringAsFixed(1)} km',
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: <Widget>[
                            if (restaurant.deliveryFee != null)
                              Text(
                                'Envío \$${restaurant.deliveryFee}',
                                style: text.labelLarge?.copyWith(
                                  color: AppTheme.coralDeep,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            if (!restaurant.isOpen || restaurant.isBusy)
                              Text(
                                restaurant.isOpen ? 'Muy ocupado' : 'Cerrado',
                                style: text.labelSmall?.copyWith(
                                  color: AppTheme.navy,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
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

class _Cover extends StatelessWidget {
  const _Cover({required this.restaurant});
  final Restaurant restaurant;

  Widget _fallback(BuildContext context) {
    final List<Color> cover = AppTheme.coverFor(restaurant.id);
    return ColoredBox(
      color: cover[0],
      child: Center(
        child: Text(
          restaurant.name.isEmpty
              ? '?'
              : restaurant.name.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: cover[1],
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? url = restaurant.logoUrl;
    return url == null || url.isEmpty
        ? _fallback(context)
        : Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(context),
          );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: AppTheme.tealDeep),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: AppTheme.navy),
        ),
      ],
    );
  }
}
