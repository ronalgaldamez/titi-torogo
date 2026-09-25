import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
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
            onPressed: _load,
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

    if (_active.isEmpty && _history.isEmpty) {
      return _Message(
        icon: Icons.receipt_long_rounded,
        title: 'Todavía no pediste nada',
        message: 'Cuando hagas tu primer pedido, vas a poder seguirle el '
            'rastro desde acá.',
        actionLabel: 'Volver',
        onAction: () => Navigator.of(context).pop(),
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
          if (_active.isNotEmpty) ...<Widget>[
            const _SectionTitle('EN CURSO'),
            for (final Order order in _active)
              _OrderCard(
                order: order,
                live: true,
                onTap: () => _openTracking(order),
              ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (_history.isNotEmpty) ...<Widget>[
            const _SectionTitle('HISTORIAL'),
            for (final Order order in _history)
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

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
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
                    Expanded(
                      child: Text(
                        order.restaurant.name,
                        style: text.bodyMedium?.copyWith(color: AppTheme.navy),
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
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    _StatusPill(order: order),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${order.totalUnits} '
                        '${order.totalUnits == 1 ? 'plato' : 'platos'}',
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (live)
                      Text(
                        'Ver seguimiento',
                        style: text.labelMedium?.copyWith(
                          color: AppTheme.teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
        background == AppTheme.yellow ? AppTheme.navy : Colors.white;

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
