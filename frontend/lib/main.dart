import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/api_client.dart';
import 'core/auth_storage.dart';
import 'core/theme.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/cliente/home/home_screen.dart';
import 'features/restaurante/restaurante_shell.dart';
import 'models/user.dart';

void main() {
  // ProviderScope es lo que hace funcionar a Riverpod: guarda el estado
  // compartido (el carrito) por encima de todas las pantallas. Sin esto, cada
  // pantalla que pidiera el carrito recibiria uno nuevo y vacio.
  runApp(const ProviderScope(child: ToroGoApp()));
}

class ToroGoApp extends StatelessWidget {
  const ToroGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToroGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const _Startup(),
    );
  }
}

/// Con que pantalla arranca la app.
enum _Start { loading, login, home, restaurantMenu }

/// Decide la pantalla inicial y controla la sesion.
///
///   Con token guardado -> la pantalla de SU perfil
///   Sin token          -> Login (y desde ahi se puede explorar sin cuenta)
///
/// El PERFIL manda: un cliente entra al catalogo y un restaurante a su menu.
/// Motorizado y admin todavia no tienen pantalla propia, asi que por ahora
/// caen en el Home, que es publico y no rompe nada.
class _Startup extends StatefulWidget {
  const _Startup();

  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  _Start _start = _Start.loading;

  /// Distinto de "hay token": alguien puede estar en el Home SIN cuenta,
  /// porque entro con "Explorar sin cuenta". En ese caso no hay sesion
  /// que cerrar y el boton de salir no debe aparecer.
  bool _authenticated = false;

  /// El valor 'restaurant' es el mismo que manda la API en `user.role`
  /// (UserRole::Restaurant en el backend). Si alla cambia, cambia aqui.
  static const String _restaurantRole = 'restaurant';

  /// A que pantalla entra una sesion ya iniciada.
  static _Start _startFor(String? role) {
    return role == _restaurantRole ? _Start.restaurantMenu : _Start.home;
  }

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final AuthStorage storage = AuthStorage();
    final String? token = await storage.readToken();
    final String? role = await storage.readRole();

    if (!mounted) {
      return;
    }

    final bool hasSession = token != null && token.isNotEmpty;

    setState(() {
      _authenticated = hasSession;
      _start = hasSession ? _startFor(role) : _Start.login;
    });
  }

  /// Cierra la sesion: revoca el token en el backend y borra el local.
  Future<void> _logout() async {
    await AuthRepository(ApiClient(), AuthStorage()).logout();

    if (!mounted) {
      return;
    }

    setState(() {
      _authenticated = false;
      _start = _Start.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_start) {
      case _Start.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );

      case _Start.home:
        return HomeScreen(
          onLogout: _authenticated ? _logout : null,
        );

      case _Start.restaurantMenu:
        // La app del restaurante ahora tiene pestanas (Pedidos / Mi menu):
        // antes caia directo en el menu y no habia de donde salir.
        return RestauranteShell(
          onLogout: _authenticated ? _logout : null,
        );

      case _Start.login:
        return LoginScreen(
          onAuthenticated: (User user) => setState(() {
            _authenticated = true;
            _start = _startFor(user.role);
          }),
          onSkip: () => setState(() {
            _authenticated = false;
            _start = _Start.home;
          }),
        );
    }
  }
}
