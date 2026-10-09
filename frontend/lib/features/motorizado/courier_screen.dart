import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/location.dart';
import '../../core/notifications.dart';
import '../../core/realtime.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/widgets/live_chip.dart';
import '../../core/widgets/torogo_map.dart';
import '../../models/order.dart';
import 'courier_profile.dart';
import 'pedidos/courier_order_repository.dart';
import 'pedidos/courier_history_screen.dart';

/// Destino del siguiente tramo de la entrega.
Uri courierDirectionsUri(Order order) {
  final bool delivering = order.status == 'picked_up';
  final double latitude = delivering
      ? order.delivery!.latitude
      : order.restaurant.latitude;
  final double longitude = delivering
      ? order.delivery!.longitude
      : order.restaurant.longitude;
  return Uri.https('www.google.com', '/maps/dir/', <String, String>{
    'api': '1',
    'destination': '$latitude,$longitude',
    'travelmode': 'driving',
  });
}

/// La app del motorizado.
///
/// Es el "Home / Disponibilidad" que pide la biblia, y es la ULTIMA pieza del
/// flujo: aca el pedido que el restaurante dejo listo por fin tiene quien lo
/// lleve.
class CourierScreen extends StatefulWidget {
  const CourierScreen({required this.onLogout, super.key});

  final VoidCallback? onLogout;

  @override
  State<CourierScreen> createState() => _CourierScreenState();
}

/// El paso que le toca al motorizado: a que estado va y como se llama el boton.
class _Step {
  const _Step({required this.status, required this.label});

  final String status;
  final String label;
}

class _CourierScreenState extends State<CourierScreen> {
  /// Donde esta el motorizado.
  ///
  /// Arranca en la ubicacion de respaldo (Mall del Sol) y se reemplaza por la
  /// del telefono en cuanto llega. El backend la usa para el radio de 5 km.
  Place _place = LocationService.fallback;

  final Session _session = Session(AuthStorage());

  int _tab = 0;

  bool _available = false;
  List<Order> _nearby = <Order>[];
  List<Order> _mine = <Order>[];

  Map<String, dynamic>? _summary;
  String? _summaryError;

  bool _loading = true;
  bool _busy = false;
  String? _error;
  int _loadVersion = 0;

  /// La escucha del tiempo real de los pedidos disponibles. Null = no se pudo
  /// abrir.
  RealtimeWatch? _watch;

  StreamSubscription<Map<String, dynamic>>? _liveSub;
  StreamSubscription<bool>? _connectedSub;

  /// Se muestra la chapita En vivo en la barra de arriba.
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _connectedSub?.cancel();

    // Cerrar la escucha NO es opcional: si no, este telefono quedaria suscrito
    // al canal de los disponibles y el backend seguiria mandando eventos a una
    // pantalla que ya nadie esta mirando.
    _watch?.close();

    super.dispose();
  }

  /// Pide la ubicacion UNA vez y despues carga.
  ///
  /// A diferencia del Home del cliente, aca NO se vuelve a preguntar en cada
  /// actualizacion: el motorizado se mueve todo el dia, pero preguntarle al GPS
  /// en cada refresco lo haria lento sin ganar nada.
  Future<void> _start() async {
    final Place place = await LocationService().current();

    if (mounted) {
      setState(() => _place = place);
    }

    await _load();

    _startRealtime();
  }

  /// Carga todo: disponibilidad, cercanos y los mios.
  ///
  /// [silent] es para cuando la recarga la PIDIO el tiempo real: ahi no se
  /// muestra el circulito ni se borra lo que ya estaba en pantalla. Si el aviso
  /// llega y el telefono justo se quedo sin datos, el motorizado se queda con
  /// lo que ya tenia: algo viejo a la vista es mejor que una pantalla vacia
  /// cuando esta arriba de la moto.
  Future<void> _load({bool silent = false}) async {
    final int version = ++_loadVersion;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final ApiClient api = await _session.client();
      final CourierOrderRepository repository = CourierOrderRepository(api);

      final bool available = await repository.loadAvailability();

      // Los cercanos solo se piden si esta disponible. Si no lo esta, no hay
      // nada que mostrar y seria una peticion de mas.
      final List<Order> nearby = available
          ? await repository.loadAvailable(
              latitude: _place.latitude,
              longitude: _place.longitude,
            )
          : <Order>[];

      final List<Order> mine = await repository.loadMine();
      Map<String, dynamic>? summary;
      String? summaryError;
      try {
        summary = await repository.loadSummary();
      } on ApiException {
        summaryError =
            'No pudimos actualizar el resumen. Tocá Actualizar para reintentar.';
      }

      if (!mounted || version != _loadVersion) {
        return;
      }

      setState(() {
        _available = available;
        _nearby = nearby;
        _mine = mine;
        _summary = summary;
        _summaryError = summaryError;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted || version != _loadVersion) {
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

  /// Prende el tiempo real de los pedidos disponibles.
  ///
  /// Todo esto es 'si se puede': si Reverb no esta disponible, la pantalla
  /// sigue andando con el boton de arriba o deslizando hacia abajo.
  Future<void> _startRealtime() async {
    // Ya hay una escucha abierta.
    if (_watch != null) {
      return;
    }

    // El canal de notificaciones y el permiso de Android 13+. Este telefono es
    // el del MOTORIZADO, asi que aca se usa su canal (ver notifications.dart).
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
      watch = await Realtime.instance.watchCouriers();
    } catch (error) {
      // El tiempo real es OPCIONAL: si no se pudo abrir el canal, la lista
      // sigue andando como antes. Se deja en la consola para poder
      // diagnosticarlo.
      debugPrint('Tiempo real: no se pudo escuchar los disponibles ($error)');

      return;
    }

    if (!mounted) {
      await watch.close();

      return;
    }

    _watch = watch;
    _liveSub = watch.messages.listen(_onLiveMessage);
  }

  /// Llego un aviso sobre los pedidos disponibles.
  ///
  /// Dos cosas, en este orden: primero se fija si hay que SONAR, y despues
  /// recarga. El orden importa: para saber si el pedido le sirve a este
  /// motorizado hay que preguntarle a la API, que filtra por el radio.
  void _onLiveMessage(Map<String, dynamic> payload) {
    _ringIfNewAvailable(payload);

    _load(silent: true);
  }

  /// Suena SOLO cuando un pedido ENTRA a la lista de disponibles.
  ///
  /// El aviso solo trae el id. La API confirma si sigue libre y esta cerca.
  void _ringIfNewAvailable(Map<String, dynamic> payload) {
    final dynamic orderId = payload['order_id'];

    if (!_available || orderId is! int) {
      return;
    }

    // Ya estaba en la lista: no suena dos veces por el mismo pedido.
    if (_nearby.any((Order other) => other.id == orderId)) {
      return;
    }

    unawaited(_ringWhenConfirmed(orderId));
  }

  /// Pregunta si el pedido esta entre los disponibles DE ESTE motorizado.
  ///
  /// Es el mismo filtro que usa la pantalla para pintar la lista (el radio de
  /// 5 km lo aplica el backend), asi que no puede pasar que suene un pedido que
  /// despues no aparece en ningun lado.
  Future<void> _ringWhenConfirmed(int orderId) async {
    try {
      final ApiClient api = await _session.client();
      final CourierOrderRepository repository = CourierOrderRepository(api);
      final List<Order> nearby = await repository.loadAvailable(
        latitude: _place.latitude,
        longitude: _place.longitude,
      );

      final int index = nearby.indexWhere((Order order) => order.id == orderId);

      if (index < 0) {
        return;
      }

      final Order order = nearby[index];
      final String distance = order.distanceKm == null
          ? 'Sin distancia'
          : 'a ${order.distanceKm!.toStringAsFixed(1)} km';

      await Notifications.instance.availableOrder(
        orderId: orderId,
        detail: '$distance · ${order.restaurant.name} · \$${order.total}',
      );
    } on ApiException catch (error) {
      // No suena si no se pudo confirmar. Es a proposito: un aviso por un
      // pedido que no se puede tomar es peor que no avisar.
      debugPrint('Notificaciones: no se pudo confirmar el pedido ($error)');
    }
  }

  /// Envuelve una accion: bloquea, avisa si falla, y recarga.
  ///
  /// Las tres acciones (disponibilidad, tomar, avanzar) comparten esto para no
  /// repetir el mismo try/catch tres veces.
  Future<void> _run(Future<void> Function() action, {String? okMessage}) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);

    try {
      await action();

      if (!mounted) {
        return;
      }

      if (okMessage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(okMessage)));
      }

      await _load();
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
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _setAvailability(bool value) {
    return _run(
      () async {
        final ApiClient api = await _session.client();
        await CourierOrderRepository(api).setAvailability(isAvailable: value);
      },
      okMessage: value
          ? 'Estás disponible. Te van a aparecer pedidos cerca.'
          : 'Quedaste como no disponible.',
    );
  }

  /// Toma un pedido.
  ///
  /// Se pregunta antes porque tomar un pedido es un COMPROMISO: el restaurante
  /// lo ve asignado y el cliente espera. Un toque sin querer no se deshace.
  ///
  /// (La biblia habla de 30 segundos para aceptar, que tiene sentido cuando
  /// hay notificaciones en tiempo real. Eso llega con Reverb, en el paso 6.)
  Future<void> _take(Order order) async {
    final bool confirmed = await _confirm(
      title: '¿Tomar el pedido #${order.id}?',
      message:
          'Te comprometés a recogerlo en ${order.restaurant.name}. '
          'La dirección de entrega aparece después de tomar el pedido.',
      actionLabel: 'Tomar',
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _run(() async {
      final ApiClient api = await _session.client();
      await CourierOrderRepository(api).take(order.id);
    }, okMessage: 'Pedido #${order.id} tomado.');
  }

  /// El boton que le toca a este pedido, o null si no le toca ninguno.
  ///
  /// Es solo para MOSTRAR: la guarda de verdad esta en el backend, en la
  /// maquina de estados del enum OrderStatus.
  _Step? _stepFor(Order order) {
    if (order.status == 'ready') {
      return const _Step(status: 'picked_up', label: 'Recogí el pedido');
    }

    if (order.status == 'picked_up') {
      return const _Step(status: 'delivered', label: 'Confirmar entrega');
    }

    return null;
  }

  Future<void> _advance(Order order, _Step step) async {
    // Entregar es el final del viaje y mueve plata, asi que se pregunta.
    if (step.status == 'delivered') {
      final bool confirmed = await _confirm(
        title: '¿Marcar el pedido #${order.id} como entregado?',
        message:
            'Se cobra \$${order.total} en efectivo al cliente. '
            'Después no se puede deshacer.',
        actionLabel: 'Entregado',
      );

      if (!confirmed || !mounted) {
        return;
      }
    }

    await _run(
      () async {
        final ApiClient api = await _session.client();
        await CourierOrderRepository(api).setStatus(order.id, step.status);
      },
      okMessage: step.status == 'delivered'
          ? 'Pedido #${order.id} entregado. ¡Buen trabajo!'
          : 'Pedido #${order.id} recogido.',
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coralDeep,
                  foregroundColor: Colors.white,
                ),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;

    return confirmed;
  }

  Future<void> _navigate(Order order) async {
    try {
      if (await launchUrl(
        courierDirectionsUri(order),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (error) {
      debugPrint('No se pudo abrir la navegación: $error');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No pudimos abrir Google Maps. Intentá de nuevo.'),
      ),
    );
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

  void _selectTab(int index) {
    setState(() {
      _tab = index;
    });
    if (index == 0) {
      _load(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String? date = _summary?['date'] as String?;
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _selectTab(0);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _tab == 1
            ? null
            : AppBar(
                backgroundColor: AppTheme.background,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _tab == 0 ? 'Mi día' : 'Perfil',
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                    ),
                    if (_tab == 0 && date != null)
                      Text(
                        historyDate(DateTime.parse(date)),
                        style: text.bodySmall,
                      ),
                  ],
                ),
                actions: _tab == 0
                    ? <Widget>[
                        if (_connected) const LiveChip(),
                        IconButton(
                          onPressed: _busy ? null : _load,
                          icon: const Icon(Icons.refresh_rounded),
                          color: AppTheme.navy,
                          tooltip: 'Actualizar',
                        ),
                      ]
                    : null,
              ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: <Widget>[
                  _body(),
                  _tab == 1
                      ? const CourierHistoryScreen(embedded: true)
                      : const SizedBox.shrink(),
                  _tab == 2
                      ? CourierProfile(
                          onLogout: widget.onLogout != null && !_busy
                              ? _confirmLogout
                              : null,
                        )
                      : const SizedBox.shrink(),
                ],
              ),
            ),
            if (_tab == 0 && !_loading && _error == null) _orderActions(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _selectTab,
          backgroundColor: Colors.white,
          indicatorColor: AppTheme.tealSoft,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppTheme.tealDeep),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(
                Icons.history_rounded,
                color: AppTheme.tealDeep,
              ),
              label: 'Historial',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(
                Icons.person_rounded,
                color: AppTheme.tealDeep,
              ),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: 'No pudimos cargar tus pedidos',
        message: _error!,
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.teal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: <Widget>[
          _AvailabilityCard(
            available: _available,
            busy: _busy,
            onChanged: _setAvailability,
          ),
          const SizedBox(height: AppSpacing.md),
          _DaySummary(
            summary: _summary,
            error: _summaryError,
            onHistory: () => _selectTab(1),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_mine.isNotEmpty) ...<Widget>[
            for (final Order order in _mine)
              _MyOrderCard(
                order: order,
                busy: _busy,
                onNavigate: () => _navigate(order),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],

          const _SectionTitle('PEDIDOS CERCA'),
          if (!_available)
            const _Hint('Ponete disponible para ver los pedidos que hay cerca.')
          else if (_nearby.isEmpty)
            const _Hint(
              'No hay pedidos cerca por ahora. Deslizá para actualizar.',
            )
          else
            for (final Order order in _nearby)
              _AvailableCard(
                order: order,
                busy: _busy,
                onTake: () => _take(order),
              ),
        ],
      ),
    );
  }

  Widget _orderActions() {
    final orders = _mine.where((order) => _stepFor(order) != null).toList();
    if (orders.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        bottom: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.3,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final order in orders)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: order == orders.last ? 0 : AppSpacing.sm,
                    ),
                    child: FilledButton(
                      key: ValueKey('courier-action-${order.id}'),
                      onPressed: _busy
                          ? null
                          : () => _advance(order, _stepFor(order)!),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.tealDeep,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              '${_stepFor(order)!.label} · #${order.id}',
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ganancias del día, incluidas propinas; no representa todo el efectivo cobrado.
class _DaySummary extends StatelessWidget {
  const _DaySummary({
    required this.summary,
    required this.error,
    required this.onHistory,
  });
  final Map<String, dynamic>? summary;
  final String? error;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.image),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Tus ganancias de hoy',
                  style: text.titleSmall?.copyWith(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (error != null)
                  Text(
                    error!,
                    style: text.bodyMedium?.copyWith(color: AppTheme.navy),
                  )
                else ...<Widget>[
                  Text(
                    '\$${summary?['earnings'] ?? '0.00'}',
                    style: text.headlineLarge?.copyWith(
                      color: AppTheme.tealDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.check_rounded,
                        color: AppTheme.tealDeep,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          summary?['deliveries'] == 1
                              ? '1 entrega completada'
                              : '${summary?['deliveries'] ?? 0} entregas completadas',
                          style: text.bodyMedium?.copyWith(
                            color: AppTheme.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Entregas y propinas, no el efectivo cobrado.',
                    style: text.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: onHistory,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Ver historial de entregas',
                      style: text.labelLarge?.copyWith(
                        color: AppTheme.tealDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 20,
                    color: AppTheme.tealDeep,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El interruptor de Disponible / No disponible.
class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.available,
    required this.busy,
    required this.onChanged,
  });

  final bool available;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: available ? AppTheme.mint : colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.image),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  available ? 'Estás disponible' : 'No estás disponible',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  available
                      ? 'Recibiendo pedidos cercanos'
                      : 'Ponete disponible cuando salgas a repartir.',
                  style: text.bodySmall?.copyWith(
                    color: available ? AppTheme.navy : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: available, onChanged: busy ? null : onChanged),
        ],
      ),
    );
  }
}

/// Un pedido disponible: donde se recoge, a donde va y cuanto se gana.
class _AvailableCard extends StatelessWidget {
  const _AvailableCard({
    required this.order,
    required this.busy,
    required this.onTake,
  });

  final Order order;
  final bool busy;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.image),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                '#${order.id}',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              if (order.distanceKm != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.tealSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${order.distanceKm!.toStringAsFixed(1)} km al restaurante',
                    style: text.labelSmall?.copyWith(
                      color: AppTheme.tealDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Tu ganancia', style: text.labelSmall),
                  Text(
                    '\$${order.courierEarnings}',
                    style: text.titleLarge?.copyWith(
                      color: AppTheme.tealDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Place(
            icon: Icons.storefront_rounded,
            title: 'Recoger en',
            value: order.restaurant.name,
          ),
          const SizedBox(height: 4),
          Text(
            'Dirección de entrega disponible al tomar el pedido',
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${order.totalUnits} ${order.totalUnits == 1 ? 'plato' : 'platos'}'
            ' · \$${order.total} a cobrar',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onTake,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.coralDeep,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: const Text(
                'Tomar el pedido',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El pedido que el motorizado ya tiene encima.
class _MyOrderCard extends StatelessWidget {
  const _MyOrderCard({
    required this.order,
    required this.busy,
    required this.onNavigate,
  });

  final Order order;
  final bool busy;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool delivering = order.status == 'picked_up';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.image),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionTitle('MI PEDIDO'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                '#${order.id}',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.tealDeep,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  order.statusLabel,
                  style: text.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            delivering
                ? 'Llevá el pedido al cliente'
                : 'Andá al restaurante a recoger',
            style: text.titleMedium?.copyWith(
              color: AppTheme.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _Place(
            icon: Icons.storefront_rounded,
            title: 'Recoger en',
            value: order.restaurant.name,
          ),
          const SizedBox(height: 4),
          _Place(
            icon: Icons.place_rounded,
            title: 'Entregar en',
            value: order.delivery!.address,
          ),
          if (order.delivery!.reference != null &&
              order.delivery!.reference!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            _Place(
              icon: Icons.info_outline_rounded,
              title: 'Referencia',
              value: order.delivery!.reference!,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppTheme.tealSoft,
              borderRadius: BorderRadius.circular(AppRadius.image),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Cobrar al cliente · efectivo', style: text.bodySmall),
                Text(
                  '\$${order.total}',
                  style: text.titleLarge?.copyWith(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Tu ganancia: \$${order.courierEarnings}',
                  style: text.titleSmall?.copyWith(
                    color: AppTheme.tealDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Entrega: \$${order.courierFee} · Propina: \$${order.tipAmount}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // El mapa del pedido: donde recoger y donde entregar.
          //
          // Mas bajo que en el seguimiento del cliente (160 y no 220): aca es
          // una ayuda para ubicarse, no la pantalla principal, y el motorizado
          // puede tener dos o tres pedidos seguidos en la lista.
          TorogoMap(
            points: <MapPoint>[
              MapPoint(
                latitude: order.restaurant.latitude,
                longitude: order.restaurant.longitude,
                icon: Icons.storefront_rounded,
                color: AppTheme.teal,
              ),
              MapPoint(
                latitude: order.delivery!.latitude,
                longitude: order.delivery!.longitude,
                icon: Icons.place_rounded,
                color: AppTheme.coral,
              ),
            ],
            center: MapPoint(
              latitude: delivering
                  ? order.delivery!.latitude
                  : order.restaurant.latitude,
              longitude: delivering
                  ? order.delivery!.longitude
                  : order.restaurant.longitude,
              icon: delivering ? Icons.place_rounded : Icons.storefront_rounded,
              color: AppTheme.tealDeep,
            ),
            key: ValueKey('${order.id}-${order.status}'),
            height: 160,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onNavigate,
              icon: const Icon(Icons.directions_rounded),
              label: Text(
                delivering
                    ? 'Cómo llegar al cliente'
                    : 'Cómo llegar al restaurante',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.tealDeep,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una linea con icono: "Recoger en Los Tres Cerditos".
class _Place extends StatelessWidget {
  const _Place({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: AppTheme.teal),
        const SizedBox(width: 6),
        Text(
          '$title ',
          style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        Expanded(
          child: Text(
            value,
            style: text.bodySmall?.copyWith(
              color: AppTheme.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// El titulo de una seccion.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: text.labelMedium?.copyWith(
          color: AppTheme.teal,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Una linea de explicacion, cuando no hay nada que mostrar.
class _Hint extends StatelessWidget {
  const _Hint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.delivery_dining_outlined,
            color: AppTheme.tealDeep,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: text.bodyMedium?.copyWith(color: AppTheme.navy),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla de aviso: error de red.
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
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
