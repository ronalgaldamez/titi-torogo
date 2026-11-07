import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../models/order.dart';

/// Estilo compartido por la lista y el seguimiento del canvas aprobado.
class OrderPresentation {
  static const background = Color(0xFF102F3B);
  static const surface = Color(0xFF193D49);
  static const ink = Color(0xFFFFF9ED);
  static const muted = Color(0xFFB0C4CC);
  static const coral = Color(0xFFFF805B);
  static const yellow = Color(0xFFFFCF16);
  static const line = Color(0x24FFFFFF);
  static const mint = Color(0xFF57C4AC);

  static ThemeData theme(BuildContext context) => Theme.of(context).copyWith(
    scaffoldBackgroundColor: background,
    textTheme: Theme.of(
      context,
    ).textTheme.apply(bodyColor: ink, displayColor: ink),
    colorScheme: const ColorScheme.dark(
      primary: coral,
      onPrimary: background,
      surface: background,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: muted,
      outlineVariant: line,
      surfaceContainerHighest: surface,
      error: coral,
    ),
    dividerColor: line,
    iconTheme: const IconThemeData(color: muted, size: 18),
  );

  static String date(DateTime value) {
    String two(int value) => value.toString().padLeft(2, '0');
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '${two(value.day)}/${two(value.month)}/${value.year} · '
        '$hour:${two(value.minute)} ${value.hour < 12 ? 'AM' : 'PM'}';
  }

  static IconData statusIcon(Order order) => switch (order.status) {
    'pending' => Icons.schedule_outlined,
    'accepted' || 'preparing' => Icons.soup_kitchen_outlined,
    'ready' => Icons.shopping_bag_outlined,
    'picked_up' => Icons.delivery_dining_outlined,
    'delivered' => Icons.check_circle_outline,
    _ => Icons.cancel_outlined,
  };
}

class OrderBrandHeader extends StatelessWidget {
  const OrderBrandHeader({super.key});

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.only(top: 26, bottom: 23),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: OrderPresentation.line)),
        ),
        child: Row(
          children: [
            Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'toro'),
                  TextSpan(
                    text: 'go',
                    style: TextStyle(color: OrderPresentation.yellow),
                  ),
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: OrderPresentation.coral),
                  ),
                ],
              ),
              style: const TextStyle(
                color: OrderPresentation.ink,
                fontSize: 29,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Text(
                'HECHO PARA ESTAR CERCA',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 1.5,
                  color: OrderPresentation.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class OrderLiveLabel extends StatelessWidget {
  const OrderLiveLabel({super.key});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: OrderPresentation.mint,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 5),
      const Text(
        'En vivo',
        style: TextStyle(fontSize: 10, color: OrderPresentation.mint),
      ),
    ],
  );
}

class OrderBottomNavigation extends StatelessWidget {
  const OrderBottomNavigation({
    required this.onSelected,
    this.selectedIndex = 1,
    super.key,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: OrderPresentation.line)),
    ),
    child: NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 76,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 20,
            color: states.contains(WidgetState.selected)
                ? OrderPresentation.background
                : OrderPresentation.muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? OrderPresentation.ink
                : OrderPresentation.muted,
          ),
        ),
      ),
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        backgroundColor: OrderPresentation.background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: OrderPresentation.coral,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    ),
  );
}
