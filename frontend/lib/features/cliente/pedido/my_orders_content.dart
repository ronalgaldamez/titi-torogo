import 'package:flutter/material.dart';

import '../../../models/order.dart';
import 'order_presentation.dart';

class MyOrdersContent extends StatelessWidget {
  const MyOrdersContent({
    required this.active,
    required this.history,
    required this.filter,
    required this.onFilter,
    required this.onOpen,
    required this.onRefresh,
    super.key,
  });

  final List<Order> active;
  final List<Order> history;
  final int filter;
  final ValueChanged<int> onFilter;
  final ValueChanged<Order> onOpen;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final visibleActive = filter == 0 || filter == 1 ? active : <Order>[];
    final visibleHistory = filter == 1
        ? <Order>[]
        : history
              .where(
                (order) => switch (filter) {
                  2 => order.status == 'delivered',
                  3 =>
                    order.status == 'cancelled' || order.status == 'rejected',
                  _ => true,
                },
              )
              .toList();
    final counts = [
      active.length + history.length,
      active.length,
      history.where((order) => order.status == 'delivered').length,
      history
          .where(
            (order) =>
                order.status == 'cancelled' || order.status == 'rejected',
          )
          .length,
    ];
    final empty = active.isEmpty && history.isEmpty;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const ValueKey('customer-orders-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Mis pedidos'),
                      TextSpan(
                        text: '.',
                        style: TextStyle(color: OrderPresentation.coral),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 30,
                    height: 1.1,
                    letterSpacing: -1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                tooltip: 'Actualizar',
                icon: const Icon(Icons.refresh_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Lo que se viene. Lo que ya disfrutaste.',
            style: TextStyle(
              fontSize: 12,
              color: OrderPresentation.muted,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              const labels = ['Todos', 'En curso', 'Completados', 'Cancelados'];
              final textStyle = DefaultTextStyle.of(context).style;
              final inlineWidth = labels.asMap().entries.fold<double>(60, (
                width,
                entry,
              ) {
                final label = TextPainter(
                  text: TextSpan(
                    text: entry.value,
                    style: textStyle.copyWith(
                      fontSize: 11,
                      fontWeight: filter == entry.key
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                final count = TextPainter(
                  text: TextSpan(
                    text: '${counts[entry.key]}',
                    style: textStyle.copyWith(fontSize: 11),
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                final measured = label.width + 4 + count.width;
                label.dispose();
                count.dispose();
                return width + (measured < 48 ? 48 : measured);
              });
              final wrap = inlineWidth > constraints.maxWidth;
              final controls = List.generate(
                4,
                (index) => Semantics(
                  selected: filter == index,
                  button: true,
                  child: InkWell(
                    key: ValueKey('order-filter-$index'),
                    onTap: () => onFilter(index),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 3,
                            color: filter == index
                                ? OrderPresentation.coral
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            labels[index],
                            style: TextStyle(
                              fontSize: 11,
                              color: filter == index
                                  ? OrderPresentation.ink
                                  : OrderPresentation.muted,
                              fontWeight: filter == index
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${counts[index]}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: OrderPresentation.coral,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              return Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: OrderPresentation.line),
                  ),
                ),
                child: wrap
                    ? Wrap(spacing: 20, children: controls)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: controls,
                      ),
              );
            },
          ),
          if (visibleActive.isNotEmpty) ...[
            const _SectionLabel('TU ANTOJO SIGUE EN MARCHA'),
            for (final order in visibleActive)
              _ActiveOrder(order: order, onTap: () => onOpen(order)),
          ],
          if (visibleHistory.isNotEmpty) ...[
            _SectionLabel(
              'LOS ANTOJOS ANTERIORES',
              count: visibleHistory.length,
            ),
            for (final order in visibleHistory)
              _HistoryOrder(order: order, onTap: () => onOpen(order)),
          ],
          if (visibleActive.isEmpty && visibleHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    empty
                        ? 'Todavía no pediste nada'
                        : 'No hay pedidos en este filtro',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    empty
                        ? 'Tus pedidos aparecerán acá cuando hagás el primero.'
                        : 'Probá otra opción para consultar tus pedidos.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: OrderPresentation.muted,
                    ),
                  ),
                  TextButton(
                    onPressed: empty ? onRefresh : () => onFilter(0),
                    child: Text(empty ? 'Actualizar' : 'Ver todos'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 32),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.favorite_border_rounded,
                color: OrderPresentation.coral,
                size: 18,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Menos vueltas.\nMás de lo que te gusta.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.7,
                    color: OrderPresentation.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.count});
  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 1.6,
              color: OrderPresentation.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(
            '$count ${count == 1 ? 'PEDIDO' : 'PEDIDOS'}',
            style: const TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              color: OrderPresentation.muted,
            ),
          ),
        ],
      ],
    ),
  );
}

class _ActiveOrder extends StatelessWidget {
  const _ActiveOrder({required this.order, required this.onTap});
  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Material(
      color: OrderPresentation.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Pedido #${order.id}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: OrderPresentation.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (order.createdAt != null)
                    Flexible(
                      child: Text(
                        OrderPresentation.date(order.createdAt!),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontSize: 10,
                          color: OrderPresentation.muted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 19),
              Row(
                children: [
                  Icon(
                    OrderPresentation.statusIcon(order),
                    color: OrderPresentation.yellow,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      order.statusLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: OrderPresentation.yellow,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  order.restaurant.name,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _itemsLabel(order),
                style: const TextStyle(
                  fontSize: 11,
                  color: OrderPresentation.muted,
                ),
              ),
              const SizedBox(height: 22),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '\$${order.total}',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.7,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: _OpenOrder(label: 'Ver seguimiento', onTap: onTap),
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

class _HistoryOrder extends StatelessWidget {
  const _HistoryOrder({required this.order, required this.onTap});
  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = order.deliveredAt ?? order.cancelledAt ?? order.createdAt;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 18, bottom: 22),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: OrderPresentation.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido #${order.id}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: OrderPresentation.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      OrderPresentation.statusIcon(order),
                      size: 15,
                      color: OrderPresentation.coral,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      order.statusLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: OrderPresentation.coral,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (date != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  OrderPresentation.date(date),
                  style: const TextStyle(
                    fontSize: 10,
                    color: OrderPresentation.muted,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              order.restaurant.name,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _itemsLabel(order),
              style: const TextStyle(
                fontSize: 11,
                color: OrderPresentation.muted,
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '\$${order.total}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _OpenOrder(label: 'Ver detalle', onTap: onTap),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _itemsLabel(Order order) {
  final units =
      '${order.totalUnits} ${order.totalUnits == 1 ? 'producto' : 'productos'}';
  return order.items.length == 1
      ? '${order.items.first.quantity} ${order.items.first.name} · $units'
      : units;
}

class _OpenOrder extends StatelessWidget {
  const _OpenOrder({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: const Size(48, 44),
      foregroundColor: OrderPresentation.coral,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 9),
        const Icon(Icons.north_east_rounded, size: 17),
      ],
    ),
  );
}
