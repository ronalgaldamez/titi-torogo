import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/filter_tabs.dart';
import '../../../models/order.dart';
import 'restaurant_order_repository.dart';

class RestaurantHistoryScreen extends StatefulWidget {
  const RestaurantHistoryScreen({super.key});

  @override
  State<RestaurantHistoryScreen> createState() =>
      _RestaurantHistoryScreenState();
}

class _RestaurantHistoryScreenState extends State<RestaurantHistoryScreen> {
  final _session = Session(AuthStorage());
  static const _statuses = <String?>[
    null,
    'delivered',
    'rejected',
    'cancelled',
  ];
  int _filter = 0;
  String _period = 'week';
  RestaurantHistoryPage? _history;
  String? _error;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({int page = 1}) async {
    final request = ++_request;
    final period = _period;
    final status = _statuses[_filter];
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = await _session.client();
      final result = await RestaurantOrderRepository(
        api,
      ).history(period: period, status: status, page: page);
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        _history = result;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Historial',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Actualizar historial',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: FilterTabs(
              labels: const ['Todos', 'Entregados', 'Rechazados', 'Cancelados'],
              icons: const [
                Icons.schedule_rounded,
                Icons.check_circle_outline_rounded,
                Icons.remove_circle_outline_rounded,
                Icons.cancel_outlined,
              ],
              selectedIndex: _filter,
              keyPrefix: 'restaurant-history-filter',
              onSelected: (index) {
                setState(() => _filter = index);
                _load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppTheme.tealDeep,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButton<String>(
                          key: const ValueKey('restaurant-history-period'),
                          value: _period,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(
                              value: 'today',
                              child: Text('Hoy'),
                            ),
                            DropdownMenuItem(
                              value: 'week',
                              child: Text('Últimos 7 días'),
                            ),
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('Todo el historial'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _period = value);
                            _load();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_loading && _error == null && _history != null)
                  Text(
                    '${_history!.total} ${_history!.total == 1 ? 'pedido' : 'pedidos'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Expanded(child: _body()),
          if (!_loading && _error == null && (_history?.pages ?? 0) > 1)
            SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Página anterior',
                    onPressed: _history!.page <= 1
                        ? null
                        : () => _load(page: _history!.page - 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Flexible(
                    child: Text(
                      'Página ${_history!.page} de ${_history!.pages}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Página siguiente',
                    onPressed: _history!.page >= _history!.pages
                        ? null
                        : () => _load(page: _history!.page + 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppTheme.teal),
              Text(_error!, textAlign: TextAlign.center),
              TextButton(
                onPressed: () => _load(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    final orders = _history!.orders;
    return RefreshIndicator(
      onRefresh: () => _load(page: _history!.page),
      child: ListView(
        key: ValueKey('history-list-$_filter-$_period-${_history!.page}'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: [
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  const Text('No hay pedidos con estos filtros.'),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filter = 0;
                        _period = 'all';
                      });
                      _load();
                    },
                    child: const Text('Ver todo el historial'),
                  ),
                ],
              ),
            ),
          for (var index = 0; index < orders.length; index++) ...[
            if (index == 0 ||
                _date(_closedAt(orders[index])) !=
                    _date(_closedAt(orders[index - 1])))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  _date(_closedAt(orders[index])),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            _HistoryCard(order: orders[index]),
          ],
        ],
      ),
    );
  }
}

DateTime? _closedAt(Order order) =>
    order.deliveredAt ?? order.cancelledAt ?? order.createdAt;
String _date(DateTime? date) => date == null
    ? 'Fecha no disponible'
    : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _time(DateTime? date) => date == null
    ? ''
    : '${date.hour % 12 == 0 ? 12 : date.hour % 12}:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              Text(
                'Pedido #${order.id}',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                '\$${order.total}',
                style: text.titleMedium?.copyWith(
                  color: AppTheme.coral,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            order.items
                .map((item) => '${item.quantity}× ${item.name}')
                .join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: order.status == 'delivered'
                      ? AppTheme.tealSoft
                      : AppTheme.background,
                  borderRadius: BorderRadius.circular(AppRadius.image),
                ),
                child: Text(
                  order.statusLabel,
                  style: text.labelMedium?.copyWith(
                    color: AppTheme.tealDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(_time(_closedAt(order)), style: text.bodySmall),
            ],
          ),
          ExpansionTile(
            key: PageStorageKey('restaurant-history-detail-${order.id}'),
            tilePadding: EdgeInsets.zero,
            title: const Text('Ver detalle del pedido'),
            children: [
              for (final item in order.items)
                _Amount(
                  label: '${item.quantity}× ${item.name}',
                  amount: item.subtotal,
                ),
              if (order.notes?.isNotEmpty ?? false)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Notas: ${order.notes}'),
                ),
              const Divider(),
              _Amount(label: 'Productos', amount: order.subtotal),
              _Amount(label: 'Envío', amount: order.deliveryFee),
              _Amount(label: 'Propina al motorista', amount: order.tipAmount),
              const Divider(),
              _Amount(label: 'Total del pedido', amount: order.total),
              if (order.delivery != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Dirección: ${order.delivery!.address}'),
                  ),
                ),
              if (order.delivery?.reference?.isNotEmpty ?? false)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Referencia: ${order.delivery!.reference}'),
                ),
              if (order.status != 'delivered')
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text('Pedido cerrado sin entrega.'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.amount});
  final String label;
  final String amount;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: AppSpacing.sm),
        Flexible(child: Text('\$$amount')),
      ],
    ),
  );
}
