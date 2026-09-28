import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'dashboard/dashboard_screen.dart';
import 'menu/restaurant_menu_screen.dart';
import 'pedidos/orders_screen.dart';

/// La app del restaurante: pedidos, menu y el estado del local.
///
/// La biblia le da 10 pantallas al restaurante, y la barra de abajo es lo que
/// las va a ordenar a medida que se agreguen (historial, perfil).
class RestauranteShell extends StatefulWidget {
  const RestauranteShell({required this.onLogout, super.key});

  final VoidCallback? onLogout;

  @override
  State<RestauranteShell> createState() => _RestauranteShellState();
}

class _RestauranteShellState extends State<RestauranteShell> {
  /// Arranca en PEDIDOS y no en el menu, a proposito: lo que el restaurante
  /// viene a mirar todo el dia es si entro algo, no su propia carta.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // IndexedStack y no un switch: asi cada pestana conserva su scroll y su
      // estado cuando el restaurante va y vuelve.
      body: IndexedStack(
        index: _tab,
        children: <Widget>[
          OrdersScreen(onLogout: widget.onLogout),
          RestaurantMenuScreen(onLogout: widget.onLogout),
          const DashboardScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (int index) => setState(() => _tab = index),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.tealSoft,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(
              Icons.receipt_long_rounded,
              color: AppTheme.tealDeep,
            ),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(
              Icons.restaurant_menu_rounded,
              color: AppTheme.tealDeep,
            ),
            label: 'Mi menú',
          ),
          // El estado del local va ULTIMO y no primero: lo que el restaurante
          // mira todo el dia son los pedidos. Esto se toca dos veces al dia
          // (al abrir y al cerrar), no cada cinco minutos.
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(
              Icons.storefront_rounded,
              color: AppTheme.tealDeep,
            ),
            label: 'Mi local',
          ),
        ],
      ),
    );
  }
}
