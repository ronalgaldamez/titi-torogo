import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/auth_storage.dart';
import '../../core/location.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import 'pedidos/courier_order_repository.dart';

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

  bool _available = false;
  List<Order> _nearby = <Order>[];
  List<Order> _mine = <Order>[];

  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
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
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

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

      if (!mounted) {
        return;
      }

      setState(() {
        _available = available;
        _nearby = nearby;
        _mine = mine;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  /// Envuelve una accion: bloquea, avisa si falla, y recarga.
  ///
  /// Las tres acciones (disponibilidad, tomar, avanzar) comparten esto para no
  /// repetir el mismo try/catch tres veces.
  Future<void> _run(
    Future<void> Function() action, {
    String? okMessage,
  }) async {
    setState(() => _busy = true);

    try {
      await action();

      if (!mounted) {
        return;
      }

      if (okMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(okMessage)),
        );
      }

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
      message: 'Te comprometés a recogerlo en ${order.restaurant.name} y '
          'llevarlo a ${order.delivery.address}.',
      actionLabel: 'Tomar',
    );

    if (!confirmed || !mounted) {
      return;
    }

    await _run(
      () async {
        final ApiClient api = await _session.client();
        await CourierOrderRepository(api).take(order.id);
      },
      okMessage: 'Pedido #${order.id} tomado.',
    );
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
      return const _Step(status: 'delivered', label: 'Entregado');
    }

    return null;
  }

  Future<void> _advance(Order order, _Step step) async {
    // Entregar es el final del viaje y mueve plata, asi que se pregunta.
    if (step.status == 'delivered') {
      final bool confirmed = await _confirm(
        title: '¿Marcar el pedido #${order.id} como entregado?',
        message: 'Se cobra \$${order.total} en efectivo al cliente. '
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
    final bool confirmed = await showDialog<bool>(
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
                  backgroundColor: AppTheme.coral,
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

  Future<void> _confirmLogout() async {
    final bool confirmed = await showDialog<bool>(
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
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Mi día',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _busy ? null : _load,
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
          const SizedBox(height: AppSpacing.lg),

          if (_mine.isNotEmpty) ...<Widget>[
            const _SectionTitle('MI PEDIDO'),
            for (final Order order in _mine)
              _MyOrderCard(
                order: order,
                step: _stepFor(order),
                busy: _busy,
                onAdvance: (_Step step) => _advance(order, step),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],

          const _SectionTitle('PEDIDOS CERCA'),
          if (!_available)
            const _Hint(
              'Ponete disponible para ver los pedidos que hay cerca.',
            )
          else if (_nearby.isEmpty)
            const _Hint(
              'No hay pedidos listos para recoger cerca tuyo. Deslizá hacia '
              'abajo para actualizar.',
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
        borderRadius: BorderRadius.circular(AppRadius.card),
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
                    color: available ? Colors.white : AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  available
                      ? 'Te van a aparecer los pedidos a menos de 5 km.'
                      : 'Ponete disponible cuando salgas a repartir.',
                  style: text.bodySmall?.copyWith(
                    color: available ? Colors.white : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: available,
            onChanged: busy ? null : onChanged,
          ),
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
                    '${order.distanceKm} km',
                    style: text.labelSmall?.copyWith(
                      color: AppTheme.tealDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                '\$${order.courierFee}',
                style: text.titleSmall?.copyWith(
                  color: AppTheme.coral,
                  fontWeight: FontWeight.w800,
                ),
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
          _Place(
            icon: Icons.place_rounded,
            title: 'Entregar en',
            value: order.delivery.address,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${order.totalUnits} ${order.totalUnits == 1 ? 'plato' : 'platos'}'
            ' · \$${order.total} a cobrar',
            style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onTake,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.coral,
                foregroundColor: Colors.white,
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
    required this.step,
    required this.busy,
    required this.onAdvance,
  });

  final Order order;
  final _Step? step;
  final bool busy;
  final ValueChanged<_Step> onAdvance;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTheme.teal, width: 2),
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.teal,
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
            value: order.delivery.address,
          ),
          if (order.delivery.reference != null &&
              order.delivery.reference!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            _Place(
              icon: Icons.info_outline_rounded,
              title: 'Referencia',
              value: order.delivery.reference!,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cobrás \$${order.total} en efectivo',
            style: text.bodyMedium?.copyWith(
              color: AppTheme.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (step != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : () => onAdvance(step!),
                style: FilledButton.styleFrom(
                  backgroundColor: step!.status == 'delivered'
                      ? AppTheme.mint
                      : AppTheme.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        step!.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Una linea con icono: "Recoger en Los Tres Cerditos".
class _Place extends StatelessWidget {
  const _Place({
    required this.icon,
    required this.title,
    required this.value,
  });

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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.tealSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(
        message,
        style: text.bodySmall?.copyWith(color: AppTheme.tealDeep),
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
