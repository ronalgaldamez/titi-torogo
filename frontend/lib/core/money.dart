/// Las cuentas de dinero, en un solo lugar.
///
/// Regla de todo el proyecto: el dinero NUNCA pasa por double. En Dart,
/// 0.1 + 0.2 da 0.30000000000000004, y ese centavo fantasma termina en la
/// cuenta de alguien.
///
/// La solucion es la que usa cualquier sistema de facturacion: se trabaja en
/// CENTAVOS (numeros enteros) y se convierte a texto solo para mostrar. Asi
/// 150 + 100 es 250, exacto, sin importar cuantas veces se sume.
///
/// El backend hace exactamente lo mismo con bcmath (ver App\Support\Money).
/// Los dos lados tienen que redondear igual, porque es lo unico que impide que
/// la pantalla muestre un total y el servidor cobre otro.
class Money {
  /// "1.50" -> 150.
  ///
  /// Devuelve 0 si el texto no es un numero valido. La app nunca deberia
  /// mandar basura, pero un carrito que revienta por eso es peor que un
  /// carrito que muestra 0.
  static int toCents(String amount) {
    final String clean = amount.trim();

    if (clean.isEmpty) {
      return 0;
    }

    final List<String> parts = clean.split('.');

    final int? whole = int.tryParse(parts[0]);
    if (whole == null) {
      return 0;
    }

    // OJO: "1.5" son 50 centavos, no 5. Hay que rellenar a la derecha antes
    // de cortar, o el precio se cae a la decima parte.
    String decimals = parts.length > 1 ? parts[1] : '';
    decimals = decimals.padRight(2, '0').substring(0, 2);

    final int? cents = int.tryParse(decimals);
    if (cents == null) {
      return 0;
    }

    return whole * 100 + cents;
  }

  /// 150 -> "1.50".
  static String fromCents(int cents) {
    final int whole = cents ~/ 100;
    final int rest = cents % 100;

    return '$whole.${rest.toString().padLeft(2, '0')}';
  }

  /// Suma montos en texto: `add(['1.50', '2.00'])` -> "3.50".
  static String add(Iterable<String> amounts) {
    int total = 0;

    for (final String amount in amounts) {
      total += toCents(amount);
    }

    return fromCents(total);
  }

  /// Precio por cantidad: `multiply('1.25', 3)` -> "3.75".
  static String multiply(String amount, int quantity) {
    return fromCents(toCents(amount) * quantity);
  }
}
