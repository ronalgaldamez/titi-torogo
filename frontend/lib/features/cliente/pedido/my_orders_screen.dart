import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/filter_tabs.dart';
import '../../../models/order.dart';
import 'order_repository.dart';
import 'order_tracking_screen.dart';

/// "Mis pedidos": lo que esta en curso arriba, y el historial abajo.
///
/// La biblia separa las dos cosas — "Tracking en tiempo real" y "Mis pedidos
/// (historial)" — pero en la practica el cliente las busca en el mismo lugar:
/// entra a ver como va lo suyo. Por eso van en una sola pantalla, con lo que
/// esta vivo primero.
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final Session _session = Session(AuthStorage());

  List<Order> _active = <Order>[];
  List<Order> _history = <Order>[];

  bool _loading = true;
  String? _error;
  int _filter = 0;

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
      final OrderRepository repository = OrderRepository(api);

      final List<Order> active = await repository.loadActive();
      final List<Order> history = await repository.loadHistory();

      if (!mounted) {
        return;
      }

      setState(() {
        _active = active;
        _history = history;
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

  /// Abre el seguimiento y, al volver, recarga: el pedido pudo haber avanzado
  /// mientras el cliente lo miraba.
  Future<void> _openTracking(Order order) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            OrderTrackingScreen(orderId: order.id),
      ),
    );

    if (!mounted) {
      return;
    }

    await _load();
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
          'Mis pedidos',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            color: AppTheme.navy,
            tooltip: 'Actualizar',
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

    final active = _filter == 0 || _filter == 1 ? _active : <Order>[];
    final history = _filter == 1
        ? <Order>[]
        : _history
              .where(
                (order) => switch (_filter) {
                  2 => order.status == 'delivered',
                  3 =>
                    order.status == 'cancelled' || order.status == 'rejected',
                  _ => true,
                },
              )
              .toList();
    final noOrders = _active.isEmpty && _history.isEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.teal,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: <Widget>[
          FilterTabs(
            labels: const ['Todos', 'En curso', 'Completados', 'Cancelados'],
            icons: const [
              Icons.schedule_rounded,
              Icons.delivery_dining_rounded,
              Icons.check_circle_outline_rounded,
              Icons.cancel_outlined,
            ],
            selectedIndex: _filter,
            onSelected: (index) => setState(() => _filter = index),
            keyPrefix: 'order-filter',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (active.isEmpty && history.isEmpty)
            _Message(
              icon: Icons.receipt_long_rounded,
              title: noOrders
                  ? 'Todavía no pediste nada'
                  : 'No hay pedidos en este filtro',
              message: noOrders
                  ? 'Tus pedidos aparecerán acá cuando hagás el primero.'
                  : 'Probá otra opción para consultar tus pedidos.',
              actionLabel: noOrders ? 'Actualizar' : 'Ver todos',
              onAction: noOrders ? _load : () => setState(() => _filter = 0),
            ),
          if (active.isNotEmpty) ...<Widget>[
            const _SectionTitle('En curso'),
            for (final Order order in active)
              _OrderCard(
                order: order,
                live: true,
                onTap: () => _openTracking(order),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (history.isNotEmpty) ...<Widget>[
            _SectionTitle(switch (_filter) {
              2 => 'Completados',
              3 => 'Cancelados',
              _ => 'Historial',
            }),
            for (final Order order in history)
              _OrderCard(
                order: order,
                live: false,
                onTap: () => _openTracking(order),
              ),
          ],
        ],
      ),
    );
  }
}

/// Una tarjeta de pedido en la lista.
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.live,
    required this.onTap,
  });

  final Order order;

  /// true = todavia esta en curso.
  final bool live;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final date = order.deliveredAt ?? order.cancelledAt ?? order.createdAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.image),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ExcludeSemantics(
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.tealSoft,
                      borderRadius: BorderRadius.circular(AppRadius.image),
                    ),
                    child: Text(
                      order.restaurant.name.isEmpty
                          ? '?'
                          : order.restaurant.name.characters.first
                                .toUpperCase(),
                      style: text.titleMedium?.copyWith(
                        color: AppTheme.tealDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  order.restaurant.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.titleSmall?.copyWith(
                                    color: AppTheme.navy,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Pedido #${order.id}',
                                  style: text.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '\$${order.total}',
                            style: text.titleMedium?.copyWith(
                              color: AppTheme.coralDeep,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${order.totalUnits} ${order.totalUnits == 1 ? 'producto' : 'productos'}',
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (!live && date != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _dateLabel(date),
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          _StatusPill(order: order),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  live ? 'Ver seguimiento' : 'Ver detalles',
                                  style: text.labelSmall?.copyWith(
                                    color: AppTheme.tealDeep,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: AppTheme.tealDeep,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '${two(date.day)}/${two(date.month)}/${date.year} · '
        '$hour:${two(date.minute)} ${date.hour < 12 ? 'AM' : 'PM'}';
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
        background = AppTheme.yellow;
      case 'accepted':
      case 'preparing':
        background = AppTheme.teal;
      case 'ready':
        background = AppTheme.mint;
      case 'picked_up':
        background = AppTheme.tealDeep;
      case 'delivered':
        background = AppTheme.mint;
      default:
        background = AppTheme.coral;
    }

    final Color foreground =
        background == AppTheme.yellow || background == AppTheme.mint
        ? AppTheme.navy
        : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
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

/// El titulo de una seccion.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.teal,
              borderRadius: BorderRadius.circular(AppSpacing.xs),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              style: text.titleMedium?.copyWith(
                color: AppTheme.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
      child: SingleChildScrollView(
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
      ),
    );
  }
}
