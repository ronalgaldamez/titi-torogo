import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/auth_storage.dart';
import 'core/theme.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/cliente/home/home_screen.dart';

void main() {
  runApp(const ToroGoApp());
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
enum _Start { loading, login, home }

/// Decide la pantalla inicial y controla la sesion.
///
///   Con token guardado -> Home   (la sesion sigue viva)
///   Sin token          -> Login  (y desde ahi se puede explorar sin cuenta)
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

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final String? token = await AuthStorage().readToken();
    final bool hasSession = token != null && token.isNotEmpty;

    if (!mounted) {
      return;
    }

    setState(() {
      _authenticated = hasSession;
      _start = hasSession ? _Start.home : _Start.login;
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

      case _Start.login:
        return LoginScreen(
          onAuthenticated: () => setState(() {
            _authenticated = true;
            _start = _Start.home;
          }),
          onSkip: () => setState(() {
            _authenticated = false;
            _start = _Start.home;
          }),
        );
    }
  }
}
