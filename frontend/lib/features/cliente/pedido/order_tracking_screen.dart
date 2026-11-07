import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/realtime.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/torogo_map.dart';
import '../../../models/order.dart';
import '../../../models/courier_location.dart';
import 'order_repository.dart';
import 'order_presentation.dart';
import 'order_tracking_content.dart';

/// El seguimiento de UN pedido.
///
/// Muestra el recorrido con la hora de cada paso. Esas horas las pone el
/// BACKEND cuando el pedido cambia de estado (ver OrderStatus::timestampColumn
/// en el backend), asi que esto es el historial de lo que paso de verdad, no
/// una estimacion.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({
    required this.orderId,
    this.onDestinationSelected,
    super.key,
  });

  final ValueChanged<int>? onDestinationSelected;

  final int orderId;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with WidgetsBindingObserver {
  Order? _gpsOrder;
  CourierLocation? _location;
  Timer? _gpsTimer;
  bool _locating = false;
  bool _gpsError = false;
  bool _cancelling = false;
  int _orderVersion = 0;
  late Future<Order> _future;

  /// El pedido tal como lo conto el tiempo real (WebSocket).
  ///
  /// Manda sobre lo que trajo el HTTP: si ya nos avisaron que el restaurante lo
  /// acepto, mostrar la version vieja mientras la peticion viaja seria mostrar
  /// algo que ya sabemos que es falso.
  Order? _liveOrder;

  /// La escucha del WebSocket de este pedido. Null = no se pudo abrir.
  RealtimeWatch? _watch;

  StreamSubscription<Map<String, dynamic>>? _liveSub;
  StreamSubscription<bool>? _connectedSub;

  /// ¿El WebSocket esta conectado AHORA?
  ///
  /// Se muestra en la barra de arriba. Importa porque, cuando el tiempo real no
  /// anda, no hay ningun sintoma: la pantalla simplemente no se actualiza sola.
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
    _startRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gpsTimer?.cancel();
    _liveSub?.cancel();
    _connectedSub?.cancel();

    // Cerrar la escucha NO es opcional: si no, este telefono quedaria suscrito
    // al canal del pedido y el backend seguiria mandando eventos a una pantalla
    // que ya nadie esta mirando.
    _watch?.close();

    super.dispose();
  }

  /// Prende el tiempo real para este pedido.
  ///
  /// Todo esto es "si se puede": si Reverb no esta disponible, no se rompe
  /// nada y la pantalla queda como estaba, con el boton de actualizar y el
  /// deslizar para refrescar.
  Future<void> _startRealtime() async {
    _connectedSub = Realtime.instance.connected.listen((bool connected) {
      if (mounted) {
        setState(() => _connected = connected);
      }
    });

    // El valor de AHORA, ademas del stream: un stream de broadcast no repite el
    // ultimo valor, y si la conexion ya estaba establecida antes de abrir esta
    // pantalla, el listener de arriba no recibiria nada.
    if (mounted) {
      setState(() => _connected = Realtime.instance.isConnected);
    }

    final RealtimeWatch watch;
    try {
      watch = await Realtime.instance.watchOrder(widget.orderId);
    } catch (error) {
      // El tiempo real es OPCIONAL: si no se pudo ni abrir el canal, la
      // pantalla sigue como estaba, con el boton de actualizar.
      //
      // Se deja escrito en la consola para poder diagnosticarlo, y NO se le
      // muestra nada al cliente: un pedido que se puede actualizar a mano no es
      // un problema que el tenga que resolver.
      //
      // OJO al diagnosticar: si el token venciera, el error va a aparecer como
      // "Unhandled Exception ... Failed to get authorization data", porque el
      // paquete hace la autorizacion por dentro y no la devuelve. Ese mensaje
      // significa que /api/broadcasting/auth rechazo el token.
      debugPrint('Tiempo real: no se pudo escuchar el pedido ($error)');

      return;
    }

    if (!mounted) {
      // La pantalla se cerro mientras se conectaba. Se suelta el canal para no
      // dejarlo abierto.
      await watch.close();

      return;
    }

    _watch = watch;
    _liveSub = watch.messages.listen(_onLiveUpdate);
  }

  // Consultar por HTTP aplica los permisos actuales, aunque el canal siga abierto.
  void _onLiveUpdate(Map<String, dynamic> payload) {
    if (payload['order_id'] == widget.orderId) {
      _reload();
    }
  }

  Future<Order> _load() async {
    final version = ++_orderVersion;
    final ApiClient api = await Session(AuthStorage()).client();

    // Se pide de nuevo en vez de recibirlo de la pantalla anterior: mientras el
    // cliente venia caminando hasta aca, el restaurante pudo haberlo aceptado.
    final order = await OrderRepository(api).show(widget.orderId);
    if (mounted && version == _orderVersion) {
      _syncLocation(order);
    }
    return order;
  }

  void _syncLocation(Order order) {
    if (_gpsOrder?.courier?.id != order.courier?.id || !order.isActive) {
      _location = null;
    }
    _gpsOrder = order;
    if (!order.isActive || order.courier == null) {
      _gpsTimer?.cancel();
      _gpsTimer = null;
      return;
    }
    _gpsTimer ??= Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          ModalRoute.of(context)?.isCurrent == true) {
        unawaited(_loadLocation());
      }
    });
    unawaited(_loadLocation());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _gpsOrder?.isActive == true) {
      _reload();
    }
  }

  Future<void> _loadLocation() async {
    final order = _gpsOrder;
    if (_locating ||
        order == null ||
        !order.isActive ||
        order.courier == null) {
      return;
    }
    _locating = true;
    final version = _orderVersion;
    try {
      final api = await Session(AuthStorage()).client();
      final data = await OrderRepository(api).courierLocation(order.id);
      if (!mounted || version != _orderVersion) {
        return;
      }
      if (data['courier_id'] != order.courier!.id ||
          data['status'] != order.status) {
        setState(() => _location = null);
        _reload();
        return;
      }
      final raw = data['location'];
      setState(() {
        _location = raw is Map<String, dynamic>
            ? CourierLocation.fromJson(raw)
            : null;
        _gpsError = false;
      });
    } on ApiException {
      if (mounted && version == _orderVersion) {
        setState(() => _gpsError = true);
      }
    } finally {
      _locating = false;
    }
  }

  void _reload() {
    // La pantalla pudo haberse cerrado mientras el aviso venia en camino:
    // setState sobre una pantalla que ya no existe es un error de verdad, no un
    // aviso.
    if (!mounted) {
      return;
    }

    setState(() {
      // Lo que llega por HTTP manda: se tira lo que habia pintado el tiempo
      // real, para no mezclar dos versiones del mismo pedido.
      _liveOrder = null;
      _future = _load();
    });
  }

  Future<void> _cancel() async {
    if (_cancelling) {
      return;
    }
    setState(() => _cancelling = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('¿Cancelar el pedido #${widget.orderId}?'),
          content: const Text(
            'Podés cancelar mientras el restaurante no lo haya aceptado. '
            'Si se cancela, no tenés que pagar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir esperando'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, cancelar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      final api = await Session(AuthStorage()).client();
      final order = await OrderRepository(api).cancel(widget.orderId);
      if (!mounted) {
        return;
      }
      _orderVersion++;
      _syncLocation(order);
      setState(() => _liveOrder = order);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      // Ante un fallo de red, consultar el estado antes de dar por fallida la cancelación.
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.statusCode == null
                ? 'No pudimos confirmar la cancelación. Revisá el estado del pedido antes de reintentar.'
                : error.message,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: OrderPresentation.theme(context),
    child: Scaffold(
      backgroundColor: OrderPresentation.background,
      bottomNavigationBar: widget.onDestinationSelected == null
          ? null
          : OrderBottomNavigation(
              onSelected: (index) {
                Navigator.of(context).pop();
                widget.onDestinationSelected!(index);
              },
            ),
      body: SafeArea(
        bottom: widget.onDestinationSelected == null,
        child: Column(
          children: [
            const OrderBrandHeader(),
            Expanded(
              child: FutureBuilder<Order>(
                future: _future,
                builder: (context, snapshot) {
                  final order = _liveOrder ?? snapshot.data;
                  if (order == null &&
                      snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (order == null) {
                    final error = snapshot.error;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              size: 40,
                              color: OrderPresentation.coral,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              error is ApiException
                                  ? error.message
                                  : 'No pudimos cargar el pedido.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _reload,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return OrderTrackingContent(
                    order: order,
                    connected: _connected,
                    cancelling: _cancelling,
                    onCancel: _cancel,
                    onRefresh: _reload,
                    map: _OrderMap(order: order, location: _location),
                    location: _location,
                    gpsError: _gpsError,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OrderMap extends StatefulWidget {
  const _OrderMap({required this.order, this.location});
  final Order order;
  final CourierLocation? location;
  @override
  State<_OrderMap> createState() => _OrderMapState();
}

class _OrderMapState extends State<_OrderMap> {
  final _controller = MapController();
  Order get order => widget.order;
  CourierLocation? get location =>
      widget.location?.isFresh == true ? widget.location : null;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      TorogoMap(
        controller: _controller,
        points: <MapPoint>[
          if (location != null)
            MapPoint(
              latitude: location!.latitude,
              longitude: location!.longitude,
              icon: Icons.delivery_dining_rounded,
              color: OrderPresentation.yellow,
            ),
          MapPoint(
            latitude: order.restaurant.latitude,
            longitude: order.restaurant.longitude,
            icon: Icons.storefront_rounded,
            color: OrderPresentation.yellow,
          ),
          if (order.delivery != null)
            MapPoint(
              latitude: order.delivery!.latitude,
              longitude: order.delivery!.longitude,
              icon: Icons.home_rounded,
              color: OrderPresentation.coral,
            ),
        ],
      ),
      if (location != null)
        TextButton.icon(
          onPressed: () => _controller.move(
            LatLng(location!.latitude, location!.longitude),
            15,
          ),
          icon: const Icon(Icons.my_location_rounded),
          label: const Text('Ver motorista en el mapa'),
        ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: <Widget>[
          Expanded(
            child: _MapLegend(
              color: OrderPresentation.yellow,
              icon: Icons.storefront_rounded,
              label: order.restaurant.name,
            ),
          ),
          if (order.delivery != null)
            const Expanded(
              child: _MapLegend(
                color: OrderPresentation.coral,
                icon: Icons.home_rounded,
                label: 'Tu dirección',
              ),
            ),
        ],
      ),
    ],
  );
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Row(
      children: <Widget>[
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 12, color: OrderPresentation.background),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              color: OrderPresentation.muted,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
