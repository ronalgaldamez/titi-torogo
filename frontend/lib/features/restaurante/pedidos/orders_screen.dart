import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/notifications.dart';
import '../../../core/realtime.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../models/order.dart';
import '../../../models/order_item.dart';
import 'restaurant_order_repository.dart';
import 'restaurant_history_screen.dart';

/// Los pedidos del restaurante.
///
/// Es la pantalla de "Gestion de Pedidos" del AGENDS. Muestra los que estan EN
/// CURSO, del mas nuevo al mas viejo — el ultimo es el que acaba de entrar — y
/// da los botones para avanzarlos.
///
/// La lista se actualiza SOLA cuando entra o se mueve un pedido: el backend
/// avisa por el canal de tiempo real del restaurante (ver core/realtime.dart).
/// Si el tiempo real no esta disponible, se sigue actualizando con el boton de
/// arriba o deslizando hacia abajo.
///
/// FALTA TODAVIA: el sonido fuerte cuando entra un pedido nuevo, que la biblia
/// pide para este perfil. La lista en vivo ya esta; el ruido es el paso que
/// sigue.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({this.onLogout, super.key});

  final VoidCallback? onLogout;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

/// El paso que le toca a un pedido: a que estado va y como se llama el boton.
class _Action {
  const _Action({required this.status, required this.label});

  final String status;
  final String label;
}

class _OrdersScreenState extends State<OrdersScreen> {
  final Session _session = Session(AuthStorage());

  List<Order> _orders = <Order>[];
  int _stage = 0;
  static const _stages = ['Nuevos', 'En preparación', 'Listos'];
  static int _stageOf(Order order) => switch (order.status) {
    'pending' => 0,
    'accepted' || 'preparing' => 1,
    _ => 2,
  };

  String? _error;
  bool _loading = true;

  /// El restaurante de la sesion. Null hasta que la primera carga lo traiga
  /// (viene en la misma respuesta de la lista).
  int? _restaurantId;

  /// La escucha del tiempo real de la cocina. Null = no se pudo abrir.
  RealtimeWatch? _watch;

  StreamSubscription<Map<String, dynamic>>? _liveSub;
  StreamSubscription<bool>? _connectedSub;

  /// Se muestra la chapita En vivo en la barra de arriba.
  bool _connected = false;

  /// Acción que se está guardando para cada pedido.
  ///
  /// Mientras uno esta aca, sus botones quedan bloqueados. Sin esto, tocar
  /// "Aceptar" dos veces manda dos peticiones y la segunda da 422 — un error
  /// que el restaurante no cometio.
  final Map<int, String> _saving = <int, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _connectedSub?.cancel();

    // Cerrar la escucha NO es opcional: si no, el telefono quedaria suscrito al
    // canal del restaurante y el backend seguiria mandando eventos a una
    // pantalla que ya nadie esta mirando.
    _watch?.close();

    super.dispose();
  }

  /// Carga la lista de pedidos.
  ///
  /// [silent] es para cuando la recarga la PIDIO el tiempo real: ahi no se
  /// muestran el circulito ni el cartel de error. Si el aviso llega y el
  /// telefono justo se quedo sin datos, la pantalla se queda con lo que ya
  /// tenia: algo viejo a la vista es mejor que una pantalla vacia.
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final ApiClient api = await _session.client();
      final RestaurantOrders data = await RestaurantOrderRepository(api).load();

      if (!mounted) {
        return;
      }

      setState(() {
        _orders = data.orders;
        _loading = false;
        _error = null;
      });

      // El id del restaurante viene en la misma respuesta, asi que recien
      // ahora se puede escuchar el canal de la cocina.
      _restaurantId = data.restaurantId;
      _startRealtime();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      // Si la que fallo fue una recarga silenciosa, se deja lo que ya estaba.
      if (silent) {
        return;
      }

      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  /// Prende el tiempo real de la cocina.
  ///
  /// Todo esto es 'si se puede': si Reverb no esta disponible, la lista se
  /// sigue actualizando con el boton de arriba o deslizando hacia abajo.
  Future<void> _startRealtime() async {
    final int? restaurantId = _restaurantId;

    // Ya hay una escucha abierta, o todavia no sabemos cual es el restaurante.
    if (_watch != null || restaurantId == null || restaurantId <= 0) {
      return;
    }

    // El canal de notificaciones y el permiso de Android 13+.
    //
    // Va ACA y no en main() porque las notificaciones hoy son del RESTAURANTE
    // (el cliente no las necesita), y esto hace que el cartel de "Permitir
    // notificaciones" salga la primera vez que el restaurante abre sus pedidos.
    unawaited(Notifications.instance.ensureReady());

    _connectedSub ??= Realtime.instance.connected.listen((bool connected) {
      if (mounted) {
        setState(() => _connected = connected);
      }
    });

    // El valor de AHORA ademas del stream: un stream de broadcast no repite el
    // ultimo valor, y esta pantalla puede abrirse con la conexion ya hecha.
    if (mounted) {
      setState(() => _connected = Realtime.instance.isConnected);
    }

    final RealtimeWatch watch;
    try {
      watch = await Realtime.instance.watchRestaurant(restaurantId);
    } catch (error) {
      // El tiempo real es OPCIONAL: si no se pudo abrir el canal, la lista
      // sigue andando como antes. Se deja en la consola para poder
      // diagnosticarlo.
      debugPrint('Tiempo real: no se pudo escuchar el restaurante ($error)');

      return;
    }

    if (!mounted) {
      await watch.close();

      return;
    }

    _watch = watch;
    _liveSub = watch.messages.listen(_onLiveMessage);
  }

  /// Llego un aviso del tiempo real.
  ///
  /// Dos cosas, en este orden: primero se fija si es un PEDIDO NUEVO (para
  /// sonar) y despues recarga la lista.
  void _onLiveMessage(Map<String, dynamic> payload) {
    _ringIfNewOrder(payload);

    // No se usa el pedido que viene adentro para pintar la lista: esta lista
    // esta ordenada y filtrada por 'en curso', asi que un pedido que se entrega
    // tiene que DESAPARECER de aca. Se vuelve a preguntar, en silencio.
    _load(silent: true);
  }

  /// Suena SOLO cuando entra un pedido nuevo de verdad.
  ///
  /// Las condiciones, y por que cada una:
  ///
  ///   - 'previous_status' null: el backend lo manda asi cuando el pedido acaba
  ///     de nacer. En un cambio de estado viene el estado anterior.
  ///   - estado 'pending': es el estado con el que nace un pedido.
  ///   - que NO este ya en la lista: si llegara dos veces el mismo aviso, no
  ///     suena dos veces.
  ///
  /// Los cambios de estado de pedidos que el restaurante YA conoce (aceptado,
  /// en preparacion, en camino) actualizan la lista SIN ruido: si no, el
  /// telefono sonaria todo el dia por cosas que ya vio.
  void _ringIfNewOrder(Map<String, dynamic> payload) {
    final dynamic raw = payload['order'];

    if (raw is! Map<String, dynamic> || payload['previous_status'] != null) {
      return;
    }

    final Order order;
    try {
      order = Order.fromJson(raw);
    } catch (_) {
      // Si el aviso viniera con otra forma no se inventa nada: la lista se
      // recarga igual (ver _onLiveMessage) y el pedido aparece ahi.
      return;
    }

    if (order.status != 'pending' ||
        _orders.any((Order other) => other.id == order.id)) {
      return;
    }

    final int units = order.items.fold<int>(
      0,
      (int sum, OrderItem item) => sum + item.quantity,
    );

    unawaited(
      Notifications.instance.newOrder(
        orderId: order.id,
        units: units,
        total: order.total,
      ),
    );
  }

  /// El boton que le toca a este pedido, o null si no le toca ninguno.
  ///
  /// Es solo para MOSTRAR: la guarda de verdad esta en el backend, en la
  /// maquina de estados del enum OrderStatus. Si esto se equivocara, el
  /// backend rechazaria el cambio igual.
  _Action? _actionFor(Order order) {
    if (order.canBeAccepted) {
      return const _Action(status: 'accepted', label: 'Aceptar pedido');
    }

    if (order.canBePreparing) {
      return const _Action(status: 'preparing', label: 'Empezar a preparar');
    }

    if (order.canBeReady) {
      return const _Action(status: 'ready', label: 'Listo para recoger');
    }

    return null;
  }

  /// Mueve un pedido y recarga la lista.
  Future<void> _move(Order order, String status) async {
    if (_saving.containsKey(order.id)) {
      return;
    }
    setState(() => _saving[order.id] = status);

    try {
      final ApiClient api = await _session.client();
      await RestaurantOrderRepository(api).setStatus(order.id, status);

      if (!mounted) {
        return;
      }

      // Se recarga en vez de parchear la fila: la lista esta filtrada por
      // "en curso", asi que un pedido entregado tiene que DESAPARECER de aca.
      await _load(silent: true);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      // La acción pudo guardarse aunque se perdiera su respuesta.
      await _load(silent: true);
    } finally {
      if (mounted) {
        setState(() => _saving.remove(order.id));
      }
    }
  }

  /// Rechazar es la unica accion que no se puede deshacer, asi que se pregunta.
  Future<void> _reject(Order order) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF183B49),
            titleTextStyle: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: AppTheme.discoveryPaper,
            ),
            contentTextStyle: const TextStyle(
              fontSize: 12,
              color: AppTheme.discoveryMuted,
            ),
            title: Text('¿Rechazar el pedido #${order.id}?'),
            content: const Text(
              'El cliente va a ver que no lo aceptaste, y no se puede '
              'deshacer. Si el problema es que no te da el tiempo, es mejor '
              'aceptarlo y marcarlo "muy ocupado".',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Volver'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Rechazar'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && mounted) {
      await _move(order, 'rejected');
    }
  }

  Future<void> _confirmLogout() async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('¿Cerrar sesión?'),
            content: const Text(
              'Vas a tener que volver a entrar con tu correo.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Salir'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      widget.onLogout?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(
          bodyColor: AppTheme.discoveryPaper,
          displayColor: AppTheme.discoveryPaper,
        ),
        colorScheme: base.colorScheme.copyWith(
          surface: AppTheme.discoveryBackground,
          onSurface: AppTheme.discoveryPaper,
          onSurfaceVariant: AppTheme.discoveryMuted,
          primary: AppTheme.discoveryAccent,
          outlineVariant: Colors.white.withValues(alpha: .13),
        ),
        dividerColor: Colors.white.withValues(alpha: .13),
      ),
      child: Scaffold(
        backgroundColor: AppTheme.discoveryBackground,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
                child: Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          const TextSpan(
                            text: 'toro',
                            children: [
                              TextSpan(
                                text: 'go',
                                style: TextStyle(color: AppTheme.yellow),
                              ),
                              TextSpan(
                                text: '.',
                                style: TextStyle(
                                  color: AppTheme.discoveryAccent,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.6,
                            color: AppTheme.discoveryPaper,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'MI NEGOCIO',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: AppTheme.discoveryMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heading() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(height: 1, color: Color(0x334E6B77)),
      const SizedBox(height: 18),
      Row(
        children: [
          const Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Pedidos',
                children: [
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: AppTheme.discoveryAccent),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.3,
                color: AppTheme.discoveryPaper,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Historial de pedidos',
            icon: const Icon(
              Icons.history_rounded,
              size: 18,
              color: AppTheme.discoveryMuted,
            ),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const RestaurantHistoryScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
              color: AppTheme.discoveryMuted,
            ),
            onPressed: _load,
          ),
          if (widget.onLogout != null)
            PopupMenuButton<String>(
              tooltip: 'Más opciones',
              icon: const Icon(
                Icons.more_vert,
                size: 18,
                color: AppTheme.discoveryMuted,
              ),
              onSelected: (_) => _confirmLogout(),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'logout',
                  child: Text('Cerrar sesión'),
                ),
              ],
            ),
        ],
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Text(
              'Lo bueno ya viene en camino.',
              style: TextStyle(fontSize: 12, color: AppTheme.discoveryMuted),
            ),
          ),
          if (_connected) ...[
            const SizedBox(width: 12),
            const Text(
              '● En vivo',
              key: ValueKey('orders-live-status'),
              style: TextStyle(fontSize: 11, color: AppTheme.mint),
            ),
          ],
        ],
      ),
      const SizedBox(height: 22),
      Container(
        key: const ValueKey('orders-filter-line'),
        width: double.infinity,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < 3; index++)
                Semantics(
                  key: ValueKey('restaurant-stage-$index'),
                  selected: _stage == index,
                  button: true,
                  child: InkWell(
                    onTap: () => setState(() => _stage = index),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      margin: EdgeInsets.only(right: index == 2 ? 0 : 19),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _stage == index
                                ? AppTheme.discoveryAccent
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: _stages[index]),
                            if (index == 0)
                              TextSpan(
                                text:
                                    '  ${_orders.where((order) => _stageOf(order) == index).length}',
                                style: const TextStyle(
                                  color: AppTheme.discoveryAccent,
                                ),
                              ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _stage == index
                              ? AppTheme.discoveryPaper
                              : AppTheme.discoveryMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: Text(
              const [
                'NUEVOS ANTOJOS',
                'MANOS A LA COCINA',
                'RUMBO A LO RICO',
              ][_stage],
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: 1.4,
                color: AppTheme.discoveryMuted,
              ),
            ),
          ),
          Text(
            '${_orders.where((o) => _stageOf(o) == _stage).length} ${const ['por aceptar', 'en cocina', 'para recoger'][_stage]}',
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.discoveryMuted,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ],
  );

  Widget _body() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
      children: [
        _heading(),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          _Message(
            icon: Icons.cloud_off_rounded,
            title: 'No pudimos cargar los pedidos',
            message: _error!,
            actionLabel: 'Reintentar',
            onAction: _load,
          )
        else if (!_orders.any((o) => _stageOf(o) == _stage))
          _Message(
            icon: Icons.receipt_long_outlined,
            title: _orders.isEmpty
                ? 'Todo al día.'
                : 'Sin pedidos en esta etapa.',
            message: 'El próximo antojo aparecerá aquí.',
            actionLabel: 'Actualizar',
            onAction: _load,
          )
        else
          for (final order in _orders.where((o) => _stageOf(o) == _stage))
            _OrderCard(
              key: ValueKey(order.id),
              order: order,
              action: _actionFor(order),
              savingStatus: _saving[order.id],
              onMove: (status) => _move(order, status),
              onReject: () => _reject(order),
            ),
      ],
    ),
  );
}

/// Una tarjeta de pedido, con lo que el restaurante necesita para trabajarlo.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    super.key,
    required this.order,
    required this.action,
    required this.savingStatus,
    required this.onMove,
    required this.onReject,
  });

  final Order order;
  final _Action? action;
  final String? savingStatus;

  bool get saving => savingStatus != null;

  String get savingLabel => switch (savingStatus) {
    'accepted' => 'Aceptando…',
    'preparing' => 'Guardando preparación…',
    'ready' => 'Marcando listo…',
    'rejected' => 'Rechazando…',
    _ => 'Guardando…',
  };
  final ValueChanged<String> onMove;
  final VoidCallback onReject;

  /// La hora en que entro el pedido, en la hora del telefono.
  String get _time {
    final DateTime? created = order.createdAt;

    if (created == null) {
      return '';
    }

    final String hour = (created.hour % 12 == 0 ? 12 : created.hour % 12)
        .toString();
    final String minute = created.minute.toString().padLeft(2, '0');

    final now = DateTime.now();
    final date =
        created.year == now.year &&
            created.month == now.month &&
            created.day == now.day
        ? ''
        : '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year} · ';
    return '$date$hour:$minute ${created.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String? notes = order.notes;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 19),
      decoration: BoxDecoration(
        color: AppTheme.discoveryBackground,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: .13)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Pedido #${order.id}',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.7,
                            color: AppTheme.discoveryPaper,
                          ),
                        ),
                        _StatusPill(order: order),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _time,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.discoveryMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Total del pedido',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.discoveryMuted,
                    ),
                  ),
                  Text(
                    '\$${order.total}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.discoveryAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 17),
          if (order.canBeAccepted && order.acceptanceExpiresAt != null)
            _AcceptanceClock(deadline: order.acceptanceExpiresAt!)
          else if (!order.canBeAccepted)
            Text(switch (order.status) {
              'accepted' => 'Aceptado · pendiente de iniciar',
              'preparing' => 'La cocina está en marcha',
              'ready' => 'Preparado para salir',
              _ => order.statusLabel,
            }, style: const TextStyle(fontSize: 11, color: AppTheme.yellow)),
          const SizedBox(height: 19),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 25,
                    child: Text(
                      '${item.quantity}×',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.discoveryAccent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.discoveryPaper,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '\$${item.subtotal}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.discoveryMuted,
                    ),
                  ),
                ],
              ),
            ),
          // La nota del cliente, destacada: "sin cebolla" es lo que hace que
          // el pedido salga bien o vuelva.
          if (notes != null && notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF183B49),
                border: const Border(
                  left: BorderSide(color: AppTheme.discoveryAccent, width: 2),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: AppTheme.discoveryPaper,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'NOTA DEL CLIENTE',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppTheme.discoveryMuted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          notes,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.discoveryPaper,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          ExpansionTile(
            key: PageStorageKey('restaurant-detail-${order.id}'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              'Ver detalle del pedido',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.discoveryMuted,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Productos',
                  style: text.labelLarge?.copyWith(
                    color: AppTheme.discoveryMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final OrderItem item in order.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.quantity}×',
                        style: text.bodyMedium?.copyWith(
                          color: AppTheme.discoveryMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(item.name, style: text.bodyMedium)),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '\$${item.subtotal}',
                        style: text.bodySmall?.copyWith(
                          color: AppTheme.discoveryMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: .13)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 18,
                          color: AppTheme.discoveryMuted,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Entrega',
                          style: text.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      order.delivery?.address ?? 'Sin dirección disponible',
                      style: text.bodyMedium,
                    ),
                    if (order.delivery?.reference?.isNotEmpty ?? false) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Referencia: ${order.delivery!.reference}',
                        style: text.bodySmall?.copyWith(
                          color: AppTheme.discoveryMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: .13)),
                  ),
                ),
                child: Column(
                  children: [
                    for (final entry in {
                      'Productos': order.subtotal,
                      'Envío': order.deliveryFee,
                      'Propina al motorista': order.tipAmount,
                    }.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(entry.key, style: text.bodySmall),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text('\$${entry.value}', style: text.bodySmall),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (order.isWaitingForCourier || order.isOnTheWay) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              order.isWaitingForCourier
                  ? 'Esperando motorista'
                  : 'El motorizado ya lo recogió.',
              style: text.bodySmall?.copyWith(color: AppTheme.discoveryMuted),
            ),
          ],
          if (action != null || order.canBeRejected || saving) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                if (order.canBeRejected) ...<Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.discoveryMuted,
                        minimumSize: const Size(0, 49),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: .19),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.image),
                        ),
                      ),
                      child: Text(
                        savingStatus == 'rejected' ? 'Rechazando…' : 'Rechazar',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                if (action != null || saving)
                  Expanded(
                    flex: order.canBeRejected ? 2 : 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 49),
                      child: FilledButton(
                        onPressed: saving ? null : () => onMove(action!.status),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.discoveryAccent,
                          foregroundColor: AppTheme.discoveryBackground,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: saving
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Flexible(child: Text(savingLabel)),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      action!.label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.order});
  final Order order;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF183B49),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      switch (order.status) {
        'pending' => 'Nuevo',
        'accepted' => 'Aceptado',
        'preparing' => 'Preparando',
        'ready' => 'Listo',
        _ => order.statusLabel,
      },
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        color: AppTheme.discoveryMuted,
      ),
    ),
  );
}

/// Pantalla de aviso: error de red o lista vacia.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: AppTheme.discoveryAccent),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.discoveryPaper,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppTheme.discoveryPaper),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _AcceptanceClock extends StatefulWidget {
  const _AcceptanceClock({required this.deadline});
  final DateTime deadline;
  @override
  State<_AcceptanceClock> createState() => _AcceptanceClockState();
}

class _AcceptanceClockState extends State<_AcceptanceClock> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.deadline
        .difference(DateTime.now())
        .inSeconds
        .clamp(0, 86400);
    final remaining =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.yellow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer_outlined,
            size: 15,
            color: AppTheme.discoveryBackground,
          ),
          const SizedBox(width: 7),
          const Expanded(
            child: Text(
              'Tiempo para aceptar',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.discoveryBackground,
              ),
            ),
          ),
          Text(
            remaining,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.discoveryBackground,
            ),
          ),
        ],
      ),
    );
  }
}
