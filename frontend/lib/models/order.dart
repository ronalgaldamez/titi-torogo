import 'order_item.dart';

/// El restaurante de un pedido, resumido.
///
/// NO es el modelo Restaurant completo: la API manda solo estos datos dentro
/// del pedido, porque son los que se necesitan para mostrarlo. Pedir el resto
/// seria traer el menu entero para pintar un nombre.
class OrderRestaurant {
  const OrderRestaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final int id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  factory OrderRestaurant.fromJson(Map<String, dynamic> json) {
    return OrderRestaurant(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

/// A donde se entrega.
///
/// Es la COPIA que quedo dentro del pedido, no la direccion que el cliente
/// tenga hoy guardada: si la edita despues, el pedido sigue diciendo a donde
/// se entrego de verdad.
class OrderDelivery {
  const OrderDelivery({
    required this.address,
    required this.latitude,
    required this.longitude,
    this.reference,
  });

  final String address;
  final String? reference;
  final double latitude;
  final double longitude;

  factory OrderDelivery.fromJson(Map<String, dynamic> json) {
    return OrderDelivery(
      address: json['address'] as String,
      reference: json['reference'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

/// El motorizado, cuando ya tomo el pedido.
class OrderCourier {
  const OrderCourier({required this.id, required this.name});

  final int id;
  final String name;

  factory OrderCourier.fromJson(Map<String, dynamic> json) {
    return OrderCourier(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

/// Un pedido, tal como lo devuelve la API.
///
/// Espeja `backend/app/Http/Resources/OrderResource.php`. Lo usan las tres
/// apps (cliente, restaurante y motorizado): es el mismo pedido visto desde
/// distinto lado.
class Order {
  const Order({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.isActive,
    required this.restaurant,
    required this.delivery,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.courierFee,
    required this.platformFee,
    required this.total,
    required this.paymentMethod,
    this.courier,
    this.notes,
    this.createdAt,
    this.acceptedAt,
    this.readyAt,
    this.pickedUpAt,
    this.deliveredAt,
    this.cancelledAt,
    this.distanceKm,
  });

  final int id;

  /// Valor tecnico: 'pending', 'accepted', 'preparing', 'ready', 'picked_up',
  /// 'delivered', 'rejected' o 'cancelled'. Con esto se DECIDE.
  final String status;

  /// Etiqueta en espanol: 'Pendiente', 'En preparación'. Con esto se MUESTRA.
  final String statusLabel;

  final bool isActive;

  final OrderRestaurant restaurant;
  final OrderDelivery delivery;
  final OrderCourier? courier;
  final List<OrderItem> items;

  final String subtotal;
  final String deliveryFee;
  final String courierFee;
  final String platformFee;
  final String total;

  final String paymentMethod;
  final String? notes;

  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? readyAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;

  /// Distancia del motorizado al restaurante. null salvo cuando la pide el
  /// motorizado.
  final double? distanceKm;

  /// Cuantas unidades lleva el pedido, sumando todas las lineas.
  int get totalUnits =>
      items.fold(0, (int sum, OrderItem item) => sum + item.quantity);

  /*
   * Los proximos estados que le tocan al RESTAURANTE.
   *
   * Son solo para MOSTRAR el boton que corresponde: la guarda de verdad esta
   * en el backend, en la maquina de estados del enum OrderStatus. Si uno de
   * estos getters se equivocara, el backend rechazaria el cambio con un 422
   * igual — la pantalla no puede romper nada.
   */

  bool get canBeAccepted => status == 'pending';
  bool get canBeRejected => status == 'pending';
  bool get canBePreparing => status == 'accepted';
  bool get canBeReady => status == 'preparing';

  /// ¿Todavia hay algo que hacer con este pedido?
  bool get isWaitingForCourier => status == 'ready';
  bool get isOnTheWay => status == 'picked_up';

  /// Convierte una fecha de la API a la hora DEL TELEFONO.
  ///
  /// La API manda las fechas con su zona ("...-06:00") y DateTime.parse las
  /// guarda en UTC. Sin el toLocal(), un pedido de las 22:12 se mostraria como
  /// las 04:12 del dia siguiente.
  static DateTime? _date(dynamic value) {
    if (value is! String) {
      return null;
    }

    return DateTime.tryParse(value)?.toLocal();
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawItems =
        (json['items'] as List<dynamic>?) ?? <dynamic>[];

    final dynamic rawCourier = json['courier'];

    return Order(
      id: json['id'] as int,
      status: json['status'] as String,
      statusLabel: json['status_label'] as String,
      isActive: json['is_active'] as bool,
      restaurant: OrderRestaurant.fromJson(
        json['restaurant'] as Map<String, dynamic>,
      ),
      delivery: OrderDelivery.fromJson(
        json['delivery'] as Map<String, dynamic>,
      ),
      courier: rawCourier is Map<String, dynamic>
          ? OrderCourier.fromJson(rawCourier)
          : null,
      items: rawItems
          .cast<Map<String, dynamic>>()
          .map(OrderItem.fromJson)
          .toList(),
      subtotal: '${json['subtotal']}',
      deliveryFee: '${json['delivery_fee']}',
      courierFee: '${json['courier_fee']}',
      platformFee: '${json['platform_fee']}',
      total: '${json['total']}',
      paymentMethod: json['payment_method'] as String,
      notes: json['notes'] as String?,
      createdAt: _date(json['created_at']),
      acceptedAt: _date(json['accepted_at']),
      readyAt: _date(json['ready_at']),
      pickedUpAt: _date(json['picked_up_at']),
      deliveredAt: _date(json['delivered_at']),
      cancelledAt: _date(json['cancelled_at']),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
    );
  }
}
