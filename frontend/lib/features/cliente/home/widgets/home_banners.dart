import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

class HomePromoSlider extends StatefulWidget {
  const HomePromoSlider({required this.onExplore, super.key});
  final ValueChanged<String> onExplore;

  @override
  State<HomePromoSlider> createState() => _HomePromoSliderState();
}

class _HomePromoSliderState extends State<HomePromoSlider> {
  int _page = 0;

  void _go(int index) {
    setState(() => _page = index);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          key: const ValueKey('home-promo-swipe'),
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() > 100) {
              _go((_page + (velocity < 0 ? 1 : -1) + 3) % 3);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: IndexedStack(
              sizing: StackFit.passthrough,
              index: _page,
              children: [
                _PromoSlide(
                  eyebrow: 'EL ANTOJO DE HOY',
                  title: 'Una de queso.\nO mejor, dos.',
                  description: 'Encontrá tus pupusas favoritas.',
                  action: 'Se me antojaron',
                  image: 'assets/home-pupusas.webp',
                  onTap: () => widget.onExplore('pupusas'),
                ),
                _PromoSlide(
                  eyebrow: 'DALE GUSTO AL ANTOJO',
                  title: 'Hoy toca\nalgo diferente.',
                  description: 'Descubrí qué hay cerca de vos.',
                  action: 'Voy a ver',
                  image: 'assets/login.jpg',
                  onTap: () => widget.onExplore('burgers'),
                ),
                _PromoSlide(
                  eyebrow: 'DE AQUÍ. PARA VOS.',
                  title: 'El sabor\nde estar en casa.',
                  description: 'Los típicos que siempre se antojan.',
                  action: 'Ver los típicos',
                  image: 'assets/home-pupusas.webp',
                  onTap: () => widget.onExplore('tipicos'),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            for (var index = 0; index < 3; index++)
              Semantics(
                selected: _page == index,
                child: IconButton(
                  tooltip: 'Ver banner ${index + 1}',
                  onPressed: () => _go(index),
                  icon: Container(
                    width: _page == index ? 18 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _page == index
                          ? AppTheme.discoveryAccent
                          : AppTheme.discoveryMuted.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            const Spacer(),
            Semantics(
              liveRegion: true,
              child: Text(
                '${_page + 1} / 3',
                style: const TextStyle(
                  color: AppTheme.discoveryMuted,
                  fontSize: 11,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Siguiente banner',
              onPressed: () => _go((_page + 1) % 3),
              icon: const Icon(
                Icons.arrow_forward,
                color: AppTheme.discoveryPaper,
                size: 18,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PromoSlide extends StatelessWidget {
  const _PromoSlide({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.action,
    required this.image,
    required this.onTap,
  });
  final String eyebrow;
  final String title;
  final String description;
  final String action;
  final String image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: Image.asset(
          image,
          fit: BoxFit.cover,
          alignment: const Alignment(.3, 0),
          excludeFromSemantics: true,
        ),
      ),
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFA061F29),
                Color(0xE6061F29),
                Color(0x40061F29),
                Color(0x00061F29),
              ],
              stops: [0, .3, .72, 1],
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: const TextStyle(
                color: AppTheme.yellow,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.discoveryPaper,
                fontSize: 27,
                height: 1.05,
                letterSpacing: -.9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                color: AppTheme.discoveryPaper,
                fontSize: 11,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 13),
            FilledButton.icon(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.discoveryAccent,
                foregroundColor: AppTheme.discoveryBackground,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              label: Text(
                action,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: const Icon(Icons.north_east, size: 15),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
      ),
    ],
  );
}

class LocalFoodBanner extends StatelessWidget {
  const LocalFoodBanner({required this.onExplore, super.key});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) => Material(
    color: AppTheme.yellow,
    borderRadius: BorderRadius.circular(17),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onExplore,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/home-pupusas.webp',
              fit: BoxFit.cover,
              alignment: const Alignment(.8, 0),
              excludeFromSemantics: true,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.yellow,
                    AppTheme.yellow,
                    Color(0xC7F5D21F),
                    Color(0x00F5D21F),
                  ],
                  stops: [0, .37, .6, .88],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HECHO CERCA. HECHO CON GANAS.',
                  style: TextStyle(
                    color: AppTheme.discoveryBackground,
                    fontSize: 11,
                    height: 1.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sabores de\nmi tierra.',
                  style: TextStyle(
                    color: AppTheme.discoveryBackground,
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    height: 1.04,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Apoyá lo local,\nun pedido a la vez.',
                  style: TextStyle(
                    color: AppTheme.discoveryBackground,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Conocé los restaurantes',
                        style: TextStyle(
                          color: AppTheme.discoveryBackground,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.north_east,
                      size: 16,
                      color: AppTheme.discoveryBackground,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
