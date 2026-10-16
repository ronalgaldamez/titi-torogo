import 'package:flutter_test/flutter_test.dart';
import 'package:torogo/models/order.dart';

void main() {
  test('Lee vencimiento y motivo sin exigir campos en pedidos antiguos', () {
    final json = <String, dynamic>{
      'id': 1,
      'status': 'pending',
      'status_label': 'Pendiente',
      'is_active': true,
      'restaurant': {
        'id': 1,
        'name': 'Local',
        'address': 'Centro',
        'latitude': 14.1,
        'longitude': -89.1,
      },
      'subtotal': '3.00',
      'delivery_fee': '2.00',
      'courier_fee': '1.50',
      'platform_fee': '0.50',
      'total': '5.00',
      'payment_method': 'cash',
    };
    expect(Order.fromJson(json).acceptanceDeadlineLabel, isNull);
    expect(Order.fromJson(json).cancellationReason, isNull);
    json['acceptance_expires_at'] = '2026-10-15T18:05:00-06:00';
    final pending = Order.fromJson(json);
    expect(
      pending.acceptanceExpiresAt!.toUtc(),
      DateTime.utc(2026, 10, 16, 0, 5),
    );
    expect(pending.acceptanceDeadlineLabel, contains('(5 minutos)'));
    json['status'] = 'cancelled';
    json['is_active'] = false;
    json['cancellation_reason'] = 'El restaurante no respondió a tiempo.';
    final cancelled = Order.fromJson(json);
    expect(cancelled.acceptanceDeadlineLabel, isNull);
    expect(
      cancelled.cancellationReason,
      'El restaurante no respondió a tiempo.',
    );
    expect(cancelled.canBeAccepted, isFalse);
  });
}
