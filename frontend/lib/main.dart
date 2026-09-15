import 'package:flutter/material.dart';

import 'core/theme.dart';
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
      // Quita la cinta de "debug" de la esquina.
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // Por ahora el Home es la unica pantalla.
      // El login y el enrutado por perfil van en el siguiente paso.
      home: const HomeScreen(),
    );
  }
}
