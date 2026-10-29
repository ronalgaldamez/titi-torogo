import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/product.dart';
import '../../../models/restaurant.dart';

class RestaurantMenuFooter extends StatelessWidget {
  const RestaurantMenuFooter({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HECHO CERCA. HECHO CON GANAS.',
                style: TextStyle(
                  color: AppTheme.discoveryMuted,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'Apoyá lo local.',
                style: TextStyle(
                  color: AppTheme.discoveryPaper,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Se siente en cada pedido.',
                style: TextStyle(color: AppTheme.discoveryPaper, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Favoritos · Próximamente',
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Favoritos · Próximamente')),
          ),
          icon: const Icon(
            Icons.favorite_border,
            color: AppTheme.discoveryAccent,
          ),
        ),
      ],
    ),
  );
}

class RestaurantEmptyCartBar extends StatelessWidget {
  const RestaurantEmptyCartBar({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Colors.white24)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              color: AppTheme.discoveryAccent,
              size: 25,
            ),
            const SizedBox(width: 12),
            const Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Elegí tu antojo.',
                    style: TextStyle(
                      color: AppTheme.discoveryPaper,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tu pedido empieza con un toque.',
                    style: TextStyle(
                      color: AppTheme.discoveryMuted,
                      fontSize: 11,
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

class RestaurantProfileCover extends StatelessWidget {
  const RestaurantProfileCover({
    this.imageUrl,
    required this.isOpen,
    super.key,
  });
  final String? imageUrl;
  final bool isOpen;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 210,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null)
          Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          )
        else
          _fallback(),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, AppTheme.discoveryBackground],
            ),
          ),
        ),
        const Positioned(
          left: 22,
          bottom: 35,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HECHO CERCA. HECHO CON GANAS.',
                style: TextStyle(
                  color: AppTheme.yellow,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'El antojo\ntiene su lugar.',
                style: TextStyle(
                  color: AppTheme.discoveryPaper,
                  fontSize: 27,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 20,
          top: 15,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.discoveryBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                isOpen ? 'Abierto ahora' : 'Cerrado',
                style: const TextStyle(
                  color: AppTheme.discoveryPaper,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _fallback() => Image.asset(
    'assets/home-pupusas.webp',
    fit: BoxFit.cover,
    excludeFromSemantics: true,
  );
}

class RestaurantProfileHeader extends StatelessWidget {
  const RestaurantProfileHeader({
    required this.restaurant,
    required this.onInfo,
    super.key,
  });
  final Restaurant restaurant;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final name = restaurant.name.trim();
    final breakAt = name.lastIndexOf(' ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONOCÉ EL LOCAL',
            style: TextStyle(
              color: AppTheme.discoveryMuted,
              fontSize: 10,
              letterSpacing: 1.7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 19),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (breakAt > 0)
                        TextSpan(text: '${name.substring(0, breakAt)}\n'),
                      TextSpan(
                        text: breakAt > 0 ? name.substring(breakAt + 1) : name,
                        style: const TextStyle(color: AppTheme.discoveryAccent),
                      ),
                    ],
                  ),
                  semanticsLabel: restaurant.name,
                  style: const TextStyle(
                    color: AppTheme.discoveryPaper,
                    fontSize: 34,
                    height: 1.04,
                    letterSpacing: -1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 19),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: restaurant.logoUrl?.isNotEmpty ?? false
                      ? ColoredBox(
                          color: Colors.white,
                          child: Image.network(
                            restaurant.logoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => _initial(),
                          ),
                        )
                      : _initial(),
                ),
              ),
            ],
          ),
          if (restaurant.description?.isNotEmpty ?? false) ...[
            const SizedBox(height: 17),
            Text(
              restaurant.description!,
              style: const TextStyle(
                color: AppTheme.discoveryMuted,
                fontSize: 13,
                height: 1.75,
              ),
            ),
          ],
          const SizedBox(height: 15),
          TextButton(
            onPressed: onInfo,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.discoveryPaper,
              padding: const EdgeInsets.only(bottom: 18, top: 4),
              alignment: Alignment.centerLeft,
              shape: const RoundedRectangleBorder(),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  color: AppTheme.discoveryAccent,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.7),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        restaurant.distanceKm == null
                            ? 'Ver información'
                            : 'A ${restaurant.distanceKm} km de vos · Ver información',
                        style: const TextStyle(
                          color: AppTheme.discoveryMuted,
                          fontSize: 11,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 10),
          _fact(Icons.schedule, 'Preparación', restaurant.preparationTimeLabel),
          if (restaurant.deliveryFee != null)
            _fact(
              Icons.delivery_dining,
              'Envío',
              '\$${restaurant.deliveryFee}',
            ),
          _fact(Icons.payments_outlined, 'Pago', 'Efectivo'),
          const Padding(
            padding: EdgeInsets.only(top: 13),
            child: Text(
              'El tiempo indicado corresponde a la preparación.',
              style: TextStyle(
                color: AppTheme.discoveryMuted,
                fontSize: 10,
                height: 1.65,
              ),
            ),
          ),
          if (!restaurant.isOpen || restaurant.isBusy)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                restaurant.isOpen
                    ? 'Este restaurante está muy ocupado: puede tardar más.'
                    : 'Está cerrado en este momento.',
                style: const TextStyle(color: AppTheme.yellow),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initial() => ColoredBox(
    color: AppTheme.yellow,
    child: Center(
      child: Text(
        restaurant.name.isEmpty
            ? '?'
            : restaurant.name.characters.first.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.discoveryBackground,
          fontSize: 30,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );

  Widget _fact(IconData icon, String label, String value) => Container(
    key: ValueKey('restaurant-fact-$label'),
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.white12)),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppTheme.discoveryAccent, size: 19),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.discoveryMuted,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppTheme.discoveryPaper,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Rows grow with their content so large text does not clip a fixed-height grid.
class RestaurantProductGrid extends StatelessWidget {
  const RestaurantProductGrid({
    required this.products,
    required this.onOpen,
    super.key,
  });
  final List<Product> products;
  final ValueChanged<Product> onOpen;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (int index = 0; index < products.length; index += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int column = 0; column < 2; column++) ...[
                if (column == 1) const SizedBox(width: 14),
                Expanded(
                  child: index + column < products.length
                      ? _ProductTile(
                          product: products[index + column],
                          onTap: () => onOpen(products[index + column]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
    ],
  );
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onTap});
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Ver ${product.name} y agregar',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('menu-product-${product.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: math.min(constraints.maxWidth, 160.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: product.imageUrl?.isNotEmpty ?? false
                          ? Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              excludeFromSemantics: true,
                              errorBuilder: (_, _, _) => _placeholder(),
                            )
                          : _placeholder(),
                    ),
                    Positioned(
                      right: 7,
                      bottom: 7,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.discoveryAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 20,
                          color: AppTheme.discoveryBackground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
              style: const TextStyle(
                color: AppTheme.discoveryPaper,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            if (product.description?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  product.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.discoveryMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            const SizedBox(height: 9),
            if (product.hasDiscount)
              Text(
                '\$${product.regularPrice}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.discoveryMuted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            Text(
              '\$${product.price}',
              style: const TextStyle(
                color: AppTheme.discoveryAccent,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white24, height: 1),
          ],
        ),
      ),
    ),
  );

  Widget _placeholder() => const ColoredBox(
    color: Color(0xFF204555),
    child: Icon(Icons.restaurant_menu, size: 36, color: AppTheme.yellow),
  );
}
