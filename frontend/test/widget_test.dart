// Test del modelo: verifica que Restaurant entiende el JSON que manda la API.
//
// El archivo se llama widget_test.dart porque lo genero `flutter create`.
// Cuando sumemos tests de verdad lo movemos a test/models/restaurant_test.dart.
//
// Es una prueba pura de Dart: no dibuja nada ni llama a la red, asi que
// corre en milisegundos y nunca falla por el entorno.

import 'package:flutter_test/flutter_test.dart';
import 'package:torogo/models/restaurant.dart';

void main() {
  test('Restaurant.fromJson lee la respuesta real del Home', () {
    // Es el JSON exacto que devolvio el endpoint, copiado del test 3.
    final Restaurant restaurant = Restaurant.fromJson(<String, dynamic>{
      'id': 1,
      'name': 'Los Tres Cerditos',
      'description': 'Carnes, parrilladas y tipicos.',
      'address': 'Mall del Sol, km 51 carretera Troncal del Norte, Tejutla',
      'phone': '+503 2300 1001',
      'logo_url': null,
      'latitude': 14.101203787387021,
      'longitude': -89.15061654556241,
      'is_open': true,
      'is_busy': false,
      'prep_time_minutes': 30,
      'estimated_delivery_minutes': 30,
      'distance_km': 0.0,
      'delivery_fee': '2.00',
    });

    expect(restaurant.name, 'Los Tres Cerditos');
    expect(restaurant.isOpen, isTrue);
    expect(restaurant.isBusy, isFalse);
    expect(restaurant.estimatedDeliveryMinutes, 30);
    expect(restaurant.distanceKm, 0.0);

    // El dinero se guarda como TEXTO, no como double: si esto falla,
    // alguien convirtio los precios a float y van a aparecer centavos
    // fantasma al sumar el carrito.
    expect(restaurant.deliveryFee, '2.00');
  });
}
