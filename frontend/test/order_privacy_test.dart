import 'package:flutter_test/flutter_test.dart';
import 'package:torogo/models/order.dart';

void main() {
  Map<String, dynamic> availableOrder() => <String, dynamic>{
        'id': 42,
        'status': 'ready',
        'status_label': 'Listo para recoger',
        'is_active': true,
        'restaurant': <String, dynamic>{
          'id': 7,
          'name': 'Restaurante',
          'address': 'Dirección del restaurante',
          'latitude': 14.1,
          'longitude': -89.1,
        },
        'items': <dynamic>[],
        'subtotal': '10.00',
        'delivery_fee': '2.00',
        'courier_fee': '1.50',
        'platform_fee': '0.50',
        'total': '12.00',
        'payment_method': 'cash',
      };

  test('Un pedido disponible se lee sin datos privados de entrega', () {
    final Order order = Order.fromJson(availableOrder());

    expect(order.id, 42);
    expect(order.delivery, isNull);
    expect(order.notes, isNull);
    expect(order.restaurant.name, 'Restaurante');
    expect(order.total, '12.00');
  });

  test('Un pedido tomado conserva su dirección y referencia', () {
    final Map<String, dynamic> json = availableOrder()
      ..['delivery'] = <String, dynamic>{
        'address': 'Dirección del cliente',
        'reference': 'Portón azul',
        'latitude': 14.2,
        'longitude': -89.2,
      }
      ..['notes'] = 'Nota del cliente';
    final Order order = Order.fromJson(json);

    expect(order.delivery!.address, 'Dirección del cliente');
    expect(order.delivery!.reference, 'Portón azul');
    expect(order.delivery!.latitude, 14.2);
    expect(order.notes, 'Nota del cliente');
  });
}
