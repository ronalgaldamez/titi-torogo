import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_client.dart';
import '../../../models/address.dart';
import '../carrito/cart.dart';

/// Conserva exactamente lo que se confirmo antes de enviar el pedido.
class PendingOrder {
  const PendingOrder({
    required this.key,
    required this.cart,
    required this.address,
    required this.deliveryFee,
    this.notes,
  });

  final String key;
  final Cart cart;
  final Address address;
  final String deliveryFee;
  final String? notes;

  Map<String, dynamic> get body => <String, dynamic>{
        'restaurant_id': cart.restaurantId,
        'address_id': address.id,
        'idempotency_key': key,
        'notes': notes,
        'items': cart.items
            .map((CartItem item) => <String, int>{
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                })
            .toList(),
      };

  bool matchesCart(Cart current) =>
      jsonEncode(cart.toJson()) == jsonEncode(current.toJson());

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'cart': cart.toJson(),
        'address': <String, dynamic>{
          'id': address.id,
          'label': address.label,
          'address': address.address,
          'reference': address.reference,
          'latitude': address.latitude,
          'longitude': address.longitude,
          'is_default': address.isDefault,
        },
        'delivery_fee': deliveryFee,
        'notes': notes,
      };

  factory PendingOrder.fromJson(Map<String, dynamic> json) => PendingOrder(
        key: json['key'] as String,
        cart: Cart.fromJson(json['cart'] as Map<String, dynamic>),
        address: Address.fromJson(json['address'] as Map<String, dynamic>),
        deliveryFee: json['delivery_fee'] as String,
        notes: json['notes'] as String?,
      );
}

/// Un intento pendiente por cuenta en este dispositivo; no se borra al salir.
class PendingOrderStorage {
  String _key(int userId) => 'torogo_pending_order_$userId';

  Future<PendingOrder?> load(int userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_key(userId));
    if (raw == null) {
      return null;
    }
    try {
      return PendingOrder.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // No generar una clave nueva si no podemos leer un intento anterior.
      throw ApiException('No pudimos leer el pedido pendiente. Contactá a soporte antes de volver a pedir.');
    }
  }

  Future<void> save(int userId, PendingOrder pending) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key(userId), jsonEncode(pending.toJson()))) {
      throw ApiException('No pudimos guardar el intento de pedido. Volvé a intentar.');
    }
  }

  Future<void> clear(int userId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_key(userId))) {
      throw ApiException('No pudimos finalizar el pedido en este dispositivo. Reintentá para recuperar el mismo pedido.');
    }
  }
}
