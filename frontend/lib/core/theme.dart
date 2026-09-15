import 'package:flutter/material.dart';

/// Tema de ToroGo.
///
/// El AGENDS pide Material 3 Expressive, paleta limitada y consistente, y
/// cero degradados exagerados. Todo eso sale de un solo color semilla:
/// Material 3 deriva la paleta completa a partir de el.
///
/// El MVP es solo modo claro; el modo oscuro es Fase 2 ("Titi").
class AppTheme {
  /// Color semilla de ToroGo.
  ///
  /// PLACEHOLDER: es una propuesta, no la identidad final. Cambiar esta
  /// linea cambia TODA la app (botones, acentos, estados), porque Material 3
  /// calcula los demas tonos desde aca.
  static const Color seed = Color(0xFFC62828);

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Un gris muy suave en vez de blanco puro: las tarjetas resaltan
      // sin necesidad de sombras fuertes.
      scaffoldBackgroundColor: const Color(0xFFF6F6F7),
    );
  }
}

/// Espaciados del proyecto, para no repetir numeros sueltos por las pantallas.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
}
