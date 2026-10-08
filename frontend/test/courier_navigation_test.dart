import 'package:flutter_test/flutter_test.dart';
import 'package:torogo/features/motorizado/courier_screen.dart';
import 'package:torogo/models/order.dart';

void main() {
  test('La navegación cambia del restaurante al cliente al recoger', () {
    final Map<String, dynamic> data = <String, dynamic>{
      'id': 20,
      'status': 'ready',
      'status_label': 'Listo para recoger',
      'is_active': true,
      'restaurant': <String, dynamic>{
        'id': 7,
        'name': 'Restaurante',
        'address': 'Centro',
        'latitude': 14.1,
        'longitude': -89.1,
      },
      'delivery': <String, dynamic>{
        'address': 'Casa',
        'latitude': 14.2,
        'longitude': -89.2,
      },
      'items': <dynamic>[],
      'subtotal': '4.00',
      'delivery_fee': '2.00',
      'courier_fee': '1.50',
      'platform_fee': '0.50',
      'total': '6.00',
      'payment_method': 'cash',
    };
    final Uri pickup = courierDirectionsUri(Order.fromJson(data));
    expect(pickup.host, 'www.google.com');
    expect(pickup.path, '/maps/dir/');
    expect(pickup.queryParameters['api'], '1');
    expect(pickup.queryParameters['destination'], '14.1,-89.1');
    data['status'] = 'picked_up';
    final Uri delivery = courierDirectionsUri(Order.fromJson(data));
    expect(delivery.queryParameters['destination'], '14.2,-89.2');
  });
}
