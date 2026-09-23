import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cart.dart';

/// Guarda el carrito en el telefono.
///
/// La biblia lo pide textual: *"Carrito: Persistente (si cierra app, sigue
/// ahi)"*. El cliente arma el pedido pensandolo, cierra la app, y al volver
/// sus platos siguen donde los dejo.
///
/// Se guarda como un JSON en texto, con las MISMAS claves que usa la API, para
/// que un plato guardado se pueda volver a leer con el mismo `fromJson`.
class CartStorage {
  static const String _key = 'torogo_cart';

  Future<void> save(Cart cart) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // Un carrito vacio no se guarda: se BORRA. Si guardaramos "{}", al abrir
    // la app habria que distinguir "no hay nada" de "hay un carrito vacio".
    if (cart.isEmpty) {
      await prefs.remove(_key);
      return;
    }

    await prefs.setString(_key, jsonEncode(cart.toJson()));
  }

  Future<Cart> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key);

    if (raw == null || raw.isEmpty) {
      return Cart.empty;
    }

    try {
      return Cart.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Si lo guardado no se puede leer (una version vieja, un archivo a
      // medias), se devuelve un carrito vacio en vez de reventar al abrir la
      // app. Perder un carrito es molesto; que la app no abra es peor.
      return Cart.empty;
    }
  }
}
