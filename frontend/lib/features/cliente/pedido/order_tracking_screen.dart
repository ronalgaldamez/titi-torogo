import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../models/order.dart';
import '../../../models/order_item.dart';
import 'order_repository.dart';

/// El seguimiento de UN pedido.
///
/// Muestra el recorrido con la hora de cada paso. Esas horas las pone el
/// BACKEND cuando el pedido cambia de estado (ver OrderStatus::timestampColumn
/// en el backend), asi que esto es el historial de lo que paso de verdad, no
/// una estimacion.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({required this.orderId, super.key});

  final int orderId;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

/// Un paso del recorrido. Sin hora = todavia no paso por ahi.
class _Milestone {
  const _Milestone({required this.label, required this.at});

  final String label;
  final DateTime? at;

  bool get done => at != null;
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  late Future<Order> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Order> _load() async {
    final ApiClient api = await Session(AuthStorage()).client();

    // Se pide de nuevo en vez de recibirlo de la pantalla anterior: mientras el
    // cliente venia caminando hasta aca, el restaurante pudo haberlo aceptado.
    return OrderRepository(api).show(widget.orderId);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  String _format(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month $hour:$minute';
  }

  List<_Milestone> _milestones(Order order) {
    return <_Milestone>[
      _Milestone(label: 'Pedido hecho', at: order.createdAt),
      _Milestone(label: 'El restaurante lo aceptó', at: order.acceptedAt),
      _Milestone(label: 'Listo para recoger', at: order.readyAt),
      _Milestone(label: 'En camino', at: order.pickedUpAt),
      _Milestone(label: 'Entregado', at: order.deliveredAt),
    ];
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
          'Pedido #${widget.orderId}',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
            color: AppTheme.navy,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: FutureBuilder<Order>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<Order> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            final Object? error = snapshot.error;

            return _ErrorBox(
              message: error is ApiException
                  ? error.message
                  : 'No pudimos cargar el pedido.',
              onRetry: _reload,
            );
          }

          final Order order = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            color: AppTheme.teal,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              children: <Widget>[
                _Header(order: order),
                if (order.status == 'rejected')
                  const _Notice(
                    message: 'El restaurante no pudo con este pedido.',
                    color: AppTheme.coral,
                  ),
                if (order.status == 'cancelled')
                  const _Notice(
                    message: 'Este pedido se canceló.',
                    color: AppTheme.coral,
                  ),
                if (order.status == 'ready')
                  const _Notice(
                    message: 'Está listo. Falta que un motorizado lo recoja.',
                    color: AppTheme.yellow,
                  ),
                if (order.status == 'picked_up')
                  const _Notice(
                    message: 'Va en camino hacia tu dirección.',
                    color: AppTheme.mint,
                  ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle('EL RECORRIDO'),
                for (int i = 0; i < _milestones(order).length; i++)
                  _TimelineRow(
                    milestone: _milestones(order)[i],
                    isLast: i == _milestones(order).length - 1,
                    format: _format,
                  ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle('TU PEDIDO'),
                for (final OrderItem item in order.items)
                  _ItemLine(item: item),
                const Divider(height: AppSpacing.lg),
                _SummaryRow(label: 'Platos', value: '\$${order.subtotal}'),
                _SummaryRow(label: 'Envío', value: '\$${order.deliveryFee}'),
                _SummaryRow(
                  label: 'Total',
                  value: '\$${order.total}',
                  strong: true,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  order.paymentMethod == 'cash'
                      ? 'Pagás en efectivo al recibir'
                      : 'Pago: ${order.paymentMethod}',
                  style: text.bodySmall?.copyWith(color: AppTheme.navy),
                ),
                const SizedBox(height: AppSpacing.lg),
                const _SectionTitle('ENTREGA'),
                Text(
                  order.delivery.address,
                  style: text.bodyMedium?.copyWith(color: AppTheme.navy),
                ),
                if (order.delivery.reference != null &&
                    order.delivery.reference!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    order.delivery.reference!,
                    style: text.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (order.courier != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.delivery_dining_rounded,
                        size: 18,
                        color: AppTheme.teal,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tu motorizado: ${order.courier!.name}',
                        style: text.bodyMedium?.copyWith(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// El encabezado: el estado grande y de que restaurante es.
class _Header extends StatelessWidget {
  const _Header({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.tealSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            order.statusLabel,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.tealDeep,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            order.restaurant.name,
            style: text.titleSmall?.copyWith(color: AppTheme.navy),
          ),
        ],
      ),
    );
  }
}

/// Una franja de aviso.
class _Notice extends StatelessWidget {
  const _Notice({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color foreground =
        color == AppTheme.yellow ? AppTheme.navy : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          message,
          style: text.bodySmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Una fila del recorrido: el punto, la linea, el paso y su hora.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.milestone,
    required this.isLast,
    required this.format,
  });

  final _Milestone milestone;
  final bool isLast;
  final String Function(DateTime) format;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool done = milestone.done;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Column(
          children: <Widget>[
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: done ? AppTheme.teal : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done ? AppTheme.teal : const Color(0xFFC9D2D8),
                  width: 2,
                ),
              ),
            ),
            // La linea que une un paso con el siguiente. No va en el ultimo,
            // o quedaria un palito suelto colgando.
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: done ? AppTheme.teal : const Color(0xFFE1E7EB),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 0, bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  milestone.label,
                  style: text.titleSmall?.copyWith(
                    fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                    color: done ? AppTheme.navy : colors.onSurfaceVariant,
                  ),
                ),
                if (milestone.at != null)
                  Text(
                    format(milestone.at!),
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Una linea del pedido, sin botones: aca solo se mira.
class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '\$${item.subtotal}',
            style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Una fila del resumen.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: strong
                  ? text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    )
                  : text.bodyMedium?.copyWith(color: AppTheme.navy),
            ),
          ),
          Text(
            value,
            style: strong
                ? text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.coral,
                  )
                : text.bodyMedium?.copyWith(color: AppTheme.navy),
          ),
        ],
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

/// El aviso de error, con boton para reintentar.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppTheme.teal),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppTheme.navy),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
