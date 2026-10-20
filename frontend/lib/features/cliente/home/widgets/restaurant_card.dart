import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../models/restaurant.dart';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({required this.restaurant, this.onTap, super.key});
  final Restaurant restaurant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cover = AppTheme.coverFor(restaurant.id);
    final fallback = ColoredBox(
      color: cover.first,
      child: Center(
        child: Text(
          restaurant.name.isEmpty
              ? '?'
              : restaurant.name.characters.first.toUpperCase(),
          style: TextStyle(
            color: cover.last,
            fontSize: 44,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
    final url = restaurant.logoUrl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.25,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (url == null || url.isEmpty)
                        fallback
                      else
                        Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => fallback,
                        ),
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.discoveryBackground.withValues(
                                alpha: .92,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              !restaurant.isOpen
                                  ? 'Cerrado'
                                  : restaurant.isBusy
                                  ? 'Muy ocupado'
                                  : 'Abierto',
                              style: const TextStyle(
                                color: AppTheme.discoveryPaper,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppTheme.discoveryAccent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.north_east,
                            color: AppTheme.discoveryBackground,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                restaurant.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                restaurant.foodCategories.isNotEmpty
                    ? restaurant.foodCategories.map((c) => c.name).join(' · ')
                    : restaurant.description ?? restaurant.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Preparación ${restaurant.preparationTimeLabel}',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
              if (restaurant.distanceKm != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${restaurant.distanceKm!.toStringAsFixed(1)} km',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
              if (restaurant.deliveryFee != null) ...[
                const SizedBox(height: 5),
                Text(
                  'Envío \$${restaurant.deliveryFee}',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Divider(height: 1, color: colors.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}
