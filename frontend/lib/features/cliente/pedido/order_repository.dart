import 'dart:math';

import '../../../core/api_client.dart';
import '../../../models/address.dart';
import '../../../models/order.dart';
import '../carrito/cart.dart';
import 'pending_order_storage.dart';

/// La capa de datos de los pedidos del cliente.
class OrderRepository {
  OrderRepository(this._api);

  final ApiClient _api;
  final PendingOrderStorage _storage = PendingOrderStorage();
  int? _userId;

  Future<int> _owner() async {
    if (_userId != null) {
      return _userId!;
    }
    final Map<String, dynamic> me = await _api.get('/me');
    // AppServiceProvider desactiva el envoltorio "data" de los resources.
    final dynamic id = me['id'];
    if (id is! int) {
      throw ApiException('No pudimos identificar tu cuenta. Volvé a entrar.');
    }
    _userId = id;
    return _userId!;
  }

  Future<PendingOrder?> loadPending() async => _storage.load(await _owner());

  /// Se llama despues de actualizar el carrito, antes de mostrar el exito.
  Future<void> complete() async => _storage.clear(await _owner());

  Future<Order?> recoverPending() async {
    final PendingOrder? pending = await loadPending();
    if (pending == null) {
      throw ApiException('No hay un pedido pendiente para recuperar.');
    }
    final Map<String, dynamic> json = await _api.post('/orders/recover',
        body: <String, dynamic>{'idempotency_key': pending.key});
    if (!json.containsKey('order')) {
      throw ApiException('No pudimos verificar el pedido. Volvé a recuperarlo.');
    }
    final dynamic order = json['order'];
    return order == null ? null : Order.fromJson(order as Map<String, dynamic>);
  }

  /// POST /api/orders
  ///
  /// Del carrito solo se manda QUE plato y CUANTAS unidades. Los precios y el
  /// total los calcula el backend leyendo su catalogo: si los mandaramos
  /// nosotros, cualquiera podria pedir una pupusa a un centavo.
  ///
  /// La clave y el contenido se guardan ANTES del envio. Tras un corte o un
  /// reinicio, se recupera el intento original en lugar de crear otro pedido.
  ///
  /// Generar una clave nueva en un reintento es justo lo que crearia el
  /// segundo pedido.
  ///
  /// Devuelve el pedido confirmado por el servidor, sea nuevo o repetido.
  Future<Order> create({
    required Cart cart,
    required Address address,
    required String deliveryFee,
    String? notes,
  }) async {
    final int owner = await _owner();
    if (await _storage.load(owner) != null) {
      throw ApiException('Tenés un pedido pendiente. Recuperalo antes de crear otro.');
    }
    final PendingOrder pending = PendingOrder(
      key: newIdempotencyKey(),
      cart: cart,
      address: address,
      deliveryFee: deliveryFee,
      notes: notes,
    );
    await _storage.save(owner, pending);
    return _submit(pending);
  }

  Future<Order> _submit(PendingOrder pending) async {
    try {
      final Map<String, dynamic> json = await _api.post('/orders', body: pending.body);
      return Order.fromJson(json['order'] as Map<String, dynamic>);
    } on ApiException catch (error) {
      // Estas respuestas rechazan el pedido antes de guardarlo. Un fallo de
      // red, timeout o 500 es incierto: conserva SIEMPRE la clave original.
      if (error.statusCode == 422 || error.statusCode == 404) {
        await complete();
      }
      rethrow;
    }
  }

  /// GET /api/orders
  ///
  /// Los pedidos EN CURSO del cliente: los que todavia no terminaron. Es lo
  /// que el cliente quiere ver mientras espera la comida.
  Future<List<Order>> loadActive() async {
    return _list(await _api.get('/orders'));
  }

  /// GET /api/orders?scope=history
  ///
  /// Los TERMINADOS: entregados, rechazados y cancelados. La pantalla
  /// "Mis pedidos".
  Future<List<Order>> loadHistory() async {
    return _list(await _api.get(
      '/orders',
      query: <String, dynamic>{'scope': 'history'},
    ));
  }

  /// GET /api/orders/{id}
  ///
  /// El detalle de UNO, para el seguimiento. Se pide de nuevo en vez de usar el
  /// que ya teniamos: mientras el cliente mira la pantalla, el restaurante
  /// puede haberlo aceptado.
  Future<Order> show(int orderId) async {
    final Map<String, dynamic> json = await _api.get('/orders/$orderId');

    return Order.fromJson(json['order'] as Map<String, dynamic>);
  }

  List<Order> _list(Map<String, dynamic> json) {
    final List<dynamic> raw = (json['orders'] as List<dynamic>?) ?? <dynamic>[];

    return raw.cast<Map<String, dynamic>>().map(Order.fromJson).toList();
  }

  /// Una clave nueva, solo para el primer envio de un pedido.
  ///
  /// Junta la marca del tiempo en microsegundos con un numero al azar: dos
  /// toques en el mismo microsegundo no van a sacar el mismo azar.
  ///
  /// OJO CON EL NUMERO DE ARRIBA: `Random().nextInt(n)` no acepta cualquier n.
  ///
  /// Lo natural seria escribir `1 << 32` para pedir "un entero de 32 bits al
  /// azar", pero EN LA WEB ESO NO FUNCIONA: los enteros de Dart son numeros de
  /// JavaScript, y las operaciones de bits ahi son de 32 bits. `1 << 32` no da
  /// 4294967296, da 0 — y `nextInt(0)` lanza un RangeError que revienta la
  /// pantalla al abrir el checkout.
  ///
  /// En el celular (Android/iOS) no pasaba: ahi los enteros son de verdad.
  /// Un bug que solo aparece en una de las plataformas.
  ///
  /// Con mil millones al azar alcanza y sobra para que dos checkouts no
  /// choquen: la clave tambien lleva la marca del tiempo en microsegundos.
  static String newIdempotencyKey() {
    final int stamp = DateTime.now().microsecondsSinceEpoch;
    final int random = Random().nextInt(1000000000);

    return 'app-$stamp-$random';
  }
}
