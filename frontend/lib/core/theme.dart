import 'package:flutter/material.dart';

/// Identidad visual de ToroGo.
///
/// La paleta sale DIRECTAMENTE del logo de la marca, no de la imaginacion:
///
///   Teal ....... el fondo del logo        -> color principal
///   Amarillo ... el pajarito              -> acento y avisos
///   Rojo ....... la gorra y la bolsa "GO" -> alertas y promociones
///   Menta ...... las alas                 -> detalles suaves
///   Azul marino   los contornos           -> TEXTOS (en vez de negro puro)
///
/// Son 5 colores y ninguno mas. Eso es lo que pide el AGENDS: "paleta
/// limitada y consistente". Todo lo demas (tonos claros, bordes, fondos)
/// lo deriva Material 3 a partir de estos.
class AppTheme {
  // ------------------------ Paleta de marca ------------------------

  /// Teal del fondo del logo. Es EL color de ToroGo.
  static const Color teal = Color(0xFF1290A5);

  /// Teal mas oscuro, para cuando hace falta mas contraste.
  static const Color tealDeep = Color(0xFF0A6C7D);

  /// Amarillo del pajarito.
  static const Color yellow = Color(0xFFF5D21F);

  /// Coral de la gorra y de la bolsa "GO".
  ///
  /// Es el color de ACCION: botones, precios, promociones. Las apps de
  /// delivery siempre reservan un tono calido para el boton principal,
  /// aunque su marca sea de otro color (mira el naranja del "Add to cart"
  /// en tus dos referencias).
  static const Color coral = Color(0xFFE64A2E);

  /// Verde menta de las alas.
  static const Color mint = Color(0xFF4EC3AE);

  /// Azul marino de los contornos: el color de TODOS los textos.
  /// Usar marino en vez de negro es lo que hace que la app se sienta
  /// de la misma familia que el logo.
  static const Color navy = Color(0xFF14395C);

  /// Fondo de las pantallas.
  ///
  /// Es un blanco CALIDO, con un dejo rosado, y no un gris frio. Ese detalle
  /// es el que hacia que la referencia 1 se viera acogedora: el blanco puro
  /// se siente a hospital, el calido se siente a comida.
  static const Color background = Color(0xFFFCF6F4);

  /// Fondo claro de marca, para paneles suaves (avisos, estados vacios).
  static const Color tealSoft = Color(0xFFE0F2F5);

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: teal,
      brightness: Brightness.light,
    ).copyWith(
      primary: teal,
      onPrimary: Colors.white,
      secondary: yellow,
      onSecondary: navy,
      tertiary: mint,
      onTertiary: navy,
      error: coral,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: navy,
      surfaceContainerHighest: const Color(0xFFE3EBEF),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Fondo gris muy claro + tarjetas blancas: las tarjetas se separan
      // solas, sin sombras fuertes ni bordes marcados.
      scaffoldBackgroundColor: background,
    );
  }
}

/// Escala de espaciado.
///
/// Usar SIEMPRE estos valores en vez de numeros sueltos. Es lo que hace que
/// todas las pantallas se sientan de la misma familia, aunque las escriba
/// alguien distinto meses despues.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// Radios de las esquinas.
class AppRadius {
  static const double card = 20;
  static const double image = 16;
  static const double pill = 100;
}
