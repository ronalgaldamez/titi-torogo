import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../models/order.dart';
import '../../../models/order_item.dart';
import 'restaurant_order_repository.dart';

/// Los pedidos del restaurante.
///
/// Es la pantalla de "Gestion de Pedidos" del AGENDS. Muestra los que estan EN
/// CURSO, del mas nuevo al mas viejo — el ultimo es el que acaba de entrar — y
/// da los botones para avanzarlos.
///
/// NOTA HONESTA: la biblia pide un sonido fuerte cuando entra un pedido. Eso
/// necesita notificaciones en tiempo real (Laravel Reverb), que es el paso 6.
/// Por ahora la lista se actualiza deslizando hacia abajo.
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ApiClient api = await _session.client();
      final List<Order> orders = await RestaurantOrderRepository(api).load();

      if (!mounted) {
        return;
      }

      setState(() {
        _orders = orders;
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
