import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/food_category_icon.dart';
import '../../../models/restaurant.dart';
import 'restaurant_images_editor.dart';

class RestaurantLocalContent extends StatelessWidget {
  const RestaurantLocalContent({
    required this.restaurant,
    required this.saving,
    required this.onOpen,
    required this.onBusy,
    required this.onPreparation,
    required this.onCategories,
    required this.onImagesSaved,
    required this.onImagesSaving,
    this.onMenu,
    super.key,
  });

  final Restaurant restaurant;
  final bool saving;
  final ValueChanged<bool> onOpen;
  final ValueChanged<bool> onBusy;
  final VoidCallback onPreparation;
  final VoidCallback onCategories;
  final VoidCallback? onMenu;
  final ValueChanged<Restaurant> onImagesSaved;
  final ValueChanged<bool> onImagesSaving;

  Widget _categorySummary() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EL SABOR DE TU NEGOCIO',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.discoveryMuted,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Lo que se cocina aquí'),
                        TextSpan(
                          text: '.',
                          style: TextStyle(color: AppTheme.discoveryAccent),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 20,
                      height: 1.25,
                      letterSpacing: -.6,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.discoveryPaper,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            TextButton.icon(
              key: const ValueKey('local-categories'),
              onPressed: saving ? null : onCategories,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.discoveryAccent,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 44),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.tune, size: 15),
              label: const Text('Editar'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (restaurant.foodCategories.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF21414F),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Elegí tus categorías',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.discoveryPaper,
                  ),
                ),
              ),
            for (final category in restaurant.foodCategories)
              Container(
                key: ValueKey('local-category-tag-${category.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF21414F),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FoodCategoryIcon(
                      category: category,
                      size: 17,
                      color: AppTheme.discoveryAccent,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.discoveryPaper,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'Así te encuentran quienes tienen un antojo.',
          style: TextStyle(fontSize: 11, color: AppTheme.discoveryMuted),
        ),
      ],
    ),
  );

  Widget _availability({
    required String key,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) => MergeSemantics(
    child: InkWell(
      key: ValueKey(key),
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 17),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Icon(icon, size: 20, color: AppTheme.discoveryAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.discoveryMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 43,
              height: 44,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RestaurantImagesEditor(
          restaurant: restaurant,
          disabled: saving,
          onSaved: onImagesSaved,
          onSaving: onImagesSaving,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (restaurant.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 21, bottom: 24),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 17,
                        color: AppTheme.discoveryAccent,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          restaurant.address,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.discoveryMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: const BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(color: Color(0x28FFFFFF)),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: !restaurant.isOpen
                            ? AppTheme.discoveryAccent
                            : restaurant.isBusy
                            ? AppTheme.yellow
                            : AppTheme.mint,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            !restaurant.isOpen
                                ? 'Tu cocina toma una pausa.'
                                : restaurant.isBusy
                                ? 'A todo fuego, con más tiempo.'
                                : 'Listos para el próximo antojo.',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            !restaurant.isOpen
                                ? 'No recibís pedidos nuevos mientras estás cerrado.'
                                : restaurant.isBusy
                                ? 'Seguís abierto. La preparación aumenta un 50%.'
                                : 'Tu local está abierto y recibe pedidos.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.discoveryMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.storefront_outlined,
                      size: 20,
                      color: AppTheme.mint,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 29),
              const _Eyebrow('AL FRENTE DE TU COCINA'),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Vos marcás el ritmo.',
                style: TextStyle(
                  fontSize: 23,
                  height: 1.25,
                  letterSpacing: -.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _availability(
                key: 'local-open',
                icon: Icons.storefront_outlined,
                title: 'Local abierto',
                subtitle: 'Recibí pedidos nuevos.',
                value: restaurant.isOpen,
                onChanged: saving ? null : onOpen,
              ),
              const Divider(height: 1),
              _availability(
                key: 'local-busy',
                icon: Icons.local_fire_department_outlined,
                title: 'Muy ocupado',
                subtitle: restaurant.isOpen
                    ? 'Dale más tiempo a tu cocina.'
                    : 'Abrí el local para activar este modo.',
                value: restaurant.isBusy,
                onChanged: saving || !restaurant.isOpen ? null : onBusy,
              ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B3B49),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: AppTheme.discoveryMuted,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Expanded(child: _Eyebrow('PREPARACIÓN')),
                        TextButton(
                          key: const ValueKey('edit-preparation'),
                          onPressed: saving ? null : onPreparation,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.all(4),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Editar'),
                              SizedBox(width: 3),
                              Icon(Icons.north_east, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (restaurant.isOpen) ...[
                      const SizedBox(height: 14),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: restaurant.preparationTimeLabel
                                  .replaceFirst(RegExp(r' min$'), ''),
                              style: const TextStyle(
                                color: AppTheme.yellow,
                                fontSize: 45,
                                height: 1.3,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -2,
                              ),
                            ),
                            const TextSpan(
                              text: '  minutos',
                              style: TextStyle(
                                color: AppTheme.discoveryMuted,
                                fontSize: 12,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                        semanticsLabel: restaurant.preparationTimeLabel,
                        key: const ValueKey('local-delivery-time'),
                      ),
                      const Text(
                        'El tiempo que ve tu cliente.',
                        style: TextStyle(
                          color: AppTheme.discoveryMuted,
                          fontSize: 11,
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Pedidos nuevos pausados',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        'Tu local está cerrado',
                        style: TextStyle(color: AppTheme.discoveryMuted),
                      ),
                    ],
                    const Divider(height: AppSpacing.xl),
                    const Text(
                      'La preparación no incluye el recorrido de entrega.',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.discoveryMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _categorySummary(),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'DE TU COCINA AL ANTOJO.',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.discoveryMuted,
                      ),
                    ),
                  ),
                  Transform.rotate(
                    angle: -.175,
                    child: const SizedBox(
                      width: 38,
                      height: 38,
                      child: Center(
                        child: Icon(
                          Icons.restaurant_menu,
                          size: 25,
                          color: AppTheme.yellow,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text.rich(
                const TextSpan(
                  children: [
                    TextSpan(text: 'Tu menú,\n'),
                    TextSpan(
                      text: 'con tu sello.',
                      style: TextStyle(color: AppTheme.discoveryAccent),
                    ),
                  ],
                ),
                style: TextStyle(
                  fontSize: MediaQuery.sizeOf(context).width <= 350 ? 30 : 32,
                  height: 1.1,
                  letterSpacing: -1,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.discoveryPaper,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Los platos que preparás.\nLos precios y la disponibilidad, en tus manos.',
                style: TextStyle(
                  color: AppTheme.discoveryMuted,
                  fontSize: 12,
                  height: 1.75,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('manage-local-menu'),
                onPressed: saving ? null : onMenu,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.discoveryAccent,
                  foregroundColor: AppTheme.discoveryBackground,
                  padding: const EdgeInsets.fromLTRB(15, 10, 10, 10),
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.menu_book_outlined, size: 18),
                    SizedBox(width: 9),
                    Expanded(child: Text('Administrar mi menú')),
                    SizedBox(width: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.discoveryBackground,
                        borderRadius: BorderRadius.all(Radius.circular(9)),
                      ),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: Icon(
                            Icons.north_east,
                            size: 20,
                            color: AppTheme.discoveryPaper,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (saving) const LinearProgressIndicator(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      color: AppTheme.discoveryAccent,
                    ),
                    SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: Text(
                        'Hecho con ganas.\nAdministrado por vos.',
                        style: TextStyle(
                          color: AppTheme.discoveryMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppTheme.discoveryMuted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );
}
