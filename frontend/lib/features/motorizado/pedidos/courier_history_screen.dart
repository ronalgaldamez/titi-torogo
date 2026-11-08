import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../cliente/pedido/order_presentation.dart';
import '../courier_presentation.dart';
import 'courier_history_header.dart';
import '../../../models/order.dart';
import 'courier_order_repository.dart';

String historyDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class CourierHistoryScreen extends StatefulWidget {
  const CourierHistoryScreen({this.embedded = false, super.key});

  final bool embedded;

  @override
  State<CourierHistoryScreen> createState() => _CourierHistoryScreenState();
}

class _CourierHistoryScreenState extends State<CourierHistoryScreen> {
  final Session _session = Session(AuthStorage());
  String _period = 'today';
  String _status = 'all';
  List<Order> _orders = <Order>[];
  Map<String, dynamic>? _summary;
  String? _range;
  int? _next;
  int _version = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _next == null)) {
      return;
    }
    final int version = ++_version;
    final int page = more ? _next! : 1;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _orders = <Order>[];
        _summary = null;
        _range = null;
        _next = null;
      }
    });
    try {
      final ApiClient api = await _session.client();
      final Map<String, dynamic> data = await CourierOrderRepository(
        api,
      ).loadHistory(period: _period, status: _status, page: page);
      if (!mounted || version != _version) {
        return;
      }
      final List<Order> orders = (data['orders'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Order.fromJson)
          .toList();
      setState(() {
        _orders = more ? <Order>[..._orders, ...orders] : orders;
        _summary = data['summary'] as Map<String, dynamic>;
        _range =
            '${historyDate(DateTime.parse(data['from'] as String))} – '
            '${historyDate(DateTime.parse(data['to'] as String))}';
        _next = data['next_page'] as int?;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted || version != _version) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: OrderPresentation.theme(context),
    child: Builder(builder: _buildHistory),
  );

  Widget _buildHistory(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: OrderPresentation.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: OrderPresentation.background,
              foregroundColor: OrderPresentation.ink,
              surfaceTintColor: Colors.transparent,
            ),
      body: SafeArea(
        top: !widget.embedded,
        child: Column(
          children: [
            if (!widget.embedded) const CourierBrandHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 25),
                  itemCount: _orders.length + 2,
                  itemBuilder: (BuildContext context, int index) {
                    if (index == 0) {
                      return CourierHistoryHeader(
                        period: _period,
                        status: _status,
                        summary: _summary,
                        range: _range,
                        onPeriod: (value) {
                          setState(() => _period = value);
                          _load();
                        },
                        onStatus: (value) {
                          setState(() => _status = value);
                          _load();
                        },
                      );
                    }
                    if (index == _orders.length + 1) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.lg,
                        ),
                        child: Column(
                          children: <Widget>[
                            if (_loading)
                              const CircularProgressIndicator()
                            else if (_error != null) ...<Widget>[
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _load(more: _orders.isNotEmpty),
                                child: const Text('Reintentar'),
                              ),
                            ] else if (_orders.isEmpty)
                              CourierEmpty(
                                icon: Icons.route_outlined,
                                title: 'Acá queda tu recorrido.',
                                message: _status == 'cancelled'
                                    ? 'No tenés pedidos cancelados en este período.'
                                    : _status == 'delivered'
                                    ? 'No completaste entregas en este período.'
                                    : 'Todavía no tenés pedidos cerrados en este período.',
                              )
                            else if (_next != null)
                              OutlinedButton(
                                onPressed: () => _load(more: true),
                                child: const Text('Ver más'),
                              ),
                          ],
                        ),
                      );
                    }
                    final Order order = _orders[index - 1];
                    final DateTime? date =
                        order.deliveredAt ?? order.cancelledAt;
                    final DateTime? previous = index > 1
                        ? (_orders[index - 2].deliveredAt ??
                              _orders[index - 2].cancelledAt)
                        : null;
                    final bool group =
                        date != null &&
                        (previous == null ||
                            historyDate(previous) != historyDate(date));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (group)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Text(
                              historyDate(date),
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _HistoryCard(
                            padded: false,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              title: Text(
                                order.restaurant.name,
                                style: text.titleSmall?.copyWith(
                                  color: OrderPresentation.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '#${order.id} · ${order.statusLabel} · '
                                '${date == null ? 'Sin hora registrada' : TimeOfDay.fromDateTime(date).format(context)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    order.status == 'delivered'
                                        ? '\$${order.courierEarnings}'
                                        : 'Sin comisión',
                                    style: text.bodyMedium?.copyWith(
                                      color: OrderPresentation.mint,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: OrderPresentation.ink,
                                  ),
                                ],
                              ),
                              onTap: () => Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => _HistoryDetail(order: order),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryDetail extends StatelessWidget {
  const _HistoryDetail({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) => Theme(
    data: OrderPresentation.theme(context),
    child: Builder(builder: _buildDetail),
  );

  Widget _buildDetail(BuildContext context) {
    final Map<String, DateTime?> times = <String, DateTime?>{
      'Pedido creado': order.createdAt,
      'Aceptado por el restaurante': order.acceptedAt,
      'Listo para recoger': order.readyAt,
      'Recogido': order.pickedUpAt,
      'Entregado': order.deliveredAt,
      'Cancelado': order.cancelledAt,
    };
    final TextTheme text = Theme.of(context).textTheme;
    final events = times.entries.where((entry) => entry.value != null).toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: OrderPresentation.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Pedido #${order.id}',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: <Widget>[
            Text(
              order.restaurant.name,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              order.statusLabel,
              style: text.bodyMedium?.copyWith(
                color: order.status == 'cancelled'
                    ? OrderPresentation.coral
                    : OrderPresentation.mint,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _HistoryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Tu ganancia',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    order.status == 'delivered'
                        ? '\$${order.courierEarnings}'
                        : 'Sin comisión por este pedido',
                    style:
                        (order.status == 'delivered'
                                ? text.headlineLarge
                                : text.titleMedium)
                            ?.copyWith(
                              color: OrderPresentation.mint,
                              fontWeight: FontWeight.w800,
                            ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (order.status == 'delivered')
                    Text(
                      'Entrega: \$${order.courierFee} · Propina: \$${order.tipAmount}',
                      style: text.bodySmall,
                    ),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    order.status == 'delivered'
                        ? 'Total cobrado al cliente: \$${order.total}'
                        : 'Total del pedido: \$${order.total} · Cancelado',
                    style: text.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _HistoryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Productos',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (order.items.isEmpty)
                    const Text('No hay platos registrados.'),
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${item.quantity} × ${item.name}',
                              style: text.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text('\$${item.subtotal}', style: text.bodyMedium),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _HistoryCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Recorrido del pedido',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (int index = 0; index < events.length; index++)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          SizedBox(
                            width: AppSpacing.md,
                            child: Column(
                              children: <Widget>[
                                const SizedBox(height: AppSpacing.xs),
                                Icon(
                                  Icons.circle,
                                  size: AppSpacing.sm,
                                  color: events[index].key == 'Cancelado'
                                      ? OrderPresentation.coral
                                      : OrderPresentation.mint,
                                ),
                                if (index < events.length - 1)
                                  Expanded(
                                    child: Container(
                                      width: 1,
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    events[index].key,
                                    style: text.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    '${historyDate(events[index].value!)} · '
                                    '${TimeOfDay.fromDateTime(events[index].value!).format(context)}',
                                    style: text.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.child, this.padded = true});

  final Widget child;
  final bool padded;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(AppRadius.image),
    clipBehavior: Clip.antiAlias,
    child: padded
        ? Padding(padding: const EdgeInsets.all(AppSpacing.md), child: child)
        : child,
  );
}
