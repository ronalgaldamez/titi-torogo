import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/notifications.dart';
import '../../../core/realtime.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/live_chip.dart';
import '../../../models/order.dart';
import '../../../models/order_item.dart';
import 'restaurant_order_repository.dart';

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

  /// Ids de los pedidos con una peticion en vuelo.
  ///
  /// Mientras uno esta aca, sus botones quedan bloqueados. Sin esto, tocar
  /// "Aceptar" dos veces manda dos peticiones y la segunda da 422 — un error
  /// que el restaurante no cometio.
  final Set<int> _saving = <int>{};

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
      final RestaurantOrders data =
          await RestaurantOrderRepository(api).load();

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
      return const _Action(status: 'accepted', label: 'Aceptar');
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
    setState(() => _saving.add(order.id));

    try {
      final ApiClient api = await _session.client();
      await RestaurantOrderRepository(api).setStatus(order.id, status);

      if (!mounted) {
        return;
      }

      // Se recarga en vez de parchear la fila: la lista esta filtrada por
      // "en curso", asi que un pedido entregado tiene que DESAPARECER de aca.
      await _load();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _saving.remove(order.id));
      }
    }
  }

  /// Rechazar es la unica accion que no se puede deshacer, asi que se pregunta.
  Future<void> _reject(Order order) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('¿Rechazar el pedido #${order.id}?'),
            content: const Text(
              'El cliente va a ver que no lo aceptaste, y no se puede '
              'deshacer. Si el problema es que no te da el tiempo, es mejor '
              'aceptarlo y marcarlo "muy ocupado".',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
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
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('¿Cerrar sesión?'),
            content: const Text('Vas a tener que volver a entrar con tu correo.'),
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
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Pedidos',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        actions: <Widget>[
          if (_connected) const LiveChip(),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            color: AppTheme.navy,
            tooltip: 'Actualizar',
          ),
          if (widget.onLogout != null)
            IconButton(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded),
              color: AppTheme.navy,
              tooltip: 'Cerrar sesión',
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: 'No pudimos cargar los pedidos',
        message: _error!,
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    }

    if (_orders.isEmpty) {
      return _Message(
        icon: Icons.receipt_long_rounded,
        title: 'No hay pedidos en curso',
        message: 'Cuando entre uno, va a aparecer acá. Deslizá hacia abajo '
            'para actualizar.',
        actionLabel: 'Actualizar',
        onAction: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.teal,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        itemCount: _orders.length,
        itemBuilder: (BuildContext context, int index) {
          final Order order = _orders[index];

          return _OrderCard(
            order: order,
            action: _actionFor(order),
            saving: _saving.contains(order.id),
            onMove: (String status) => _move(order, status),
            onReject: () => _reject(order),
          );
        },
      ),
    );
  }
}

/// Una tarjeta de pedido, con lo que el restaurante necesita para trabajarlo.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.action,
    required this.saving,
    required this.onMove,
    required this.onReject,
  });

  final Order order;
  final _Action? action;
  final bool saving;
  final ValueChanged<String> onMove;
  final VoidCallback onReject;

  /// La hora en que entro el pedido, en la hora del telefono.
  String get _time {
    final DateTime? created = order.createdAt;

    if (created == null) {
      return '';
    }

    final String hour = created.hour.toString().padLeft(2, '0');
    final String minute = created.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String? notes = order.notes;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '#${order.id}',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusPill(order: order),
              const Spacer(),
              Text(
                _time,
                style: text.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final OrderItem item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: <Widget>[
                  Text(
                    '${item.quantity}×',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.teal,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      item.name,
                      style: text.bodyMedium?.copyWith(color: AppTheme.navy),
                    ),
                  ),
                  Text(
                    '\$${item.subtotal}',
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
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
                color: AppTheme.yellow,
                borderRadius: BorderRadius.circular(AppRadius.image),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.sticky_note_2_rounded,
                    size: 16,
                    color: AppTheme.navy,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      notes,
                      style: text.bodySmall?.copyWith(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Icon(
                Icons.place_outlined,
                size: 14,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.delivery.address,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '\$${order.total}',
                style: text.titleSmall?.copyWith(
                  color: AppTheme.coral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (order.isWaitingForCourier || order.isOnTheWay) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              order.isWaitingForCourier
                  ? 'Esperando un motorizado.'
                  : 'El motorizado ya lo recogió.',
              style: text.bodySmall?.copyWith(color: AppTheme.tealDeep),
            ),
          ],
          if (action != null || order.canBeRejected) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                if (order.canBeRejected) ...<Widget>[
                  OutlinedButton(
                    onPressed: saving ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.coral,
                      side: const BorderSide(color: AppTheme.coral),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    child: const Text('Rechazar'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                if (action != null)
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: saving ? null : () => onMove(action!.status),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.coral,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                action!.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
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

/// La etiqueta del estado, con su color.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final Color background;

    switch (order.status) {
      case 'pending':
        background = AppTheme.coral;
      case 'accepted':
      case 'preparing':
        background = AppTheme.yellow;
      case 'ready':
        background = AppTheme.mint;
      default:
        background = AppTheme.tealSoft;
    }

    final Color foreground = background == AppTheme.yellow
        ? AppTheme.navy
        : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        order.statusLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
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
            Icon(icon, size: 48, color: AppTheme.teal),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppTheme.navy),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
