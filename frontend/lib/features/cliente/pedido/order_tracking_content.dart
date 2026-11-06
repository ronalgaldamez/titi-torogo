import 'package:flutter/material.dart';

import '../../../models/courier_location.dart';
import '../../../models/order.dart';
import 'order_presentation.dart';

class OrderTrackingContent extends StatelessWidget {
  const OrderTrackingContent({
    required this.order,
    required this.connected,
    required this.cancelling,
    required this.onCancel,
    required this.onRefresh,
    required this.map,
    required this.location,
    required this.gpsError,
    super.key,
  });

  final Order order;
  final bool connected;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onRefresh;
  final Widget map;
  final CourierLocation? location;
  final bool gpsError;

  @override
  Widget build(BuildContext context) {
    final closed = order.status == 'cancelled' || order.status == 'rejected';
    final date = order.createdAt;
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text(
                        'Mis pedidos',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: OrderPresentation.muted,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                if (!order.isActive)
                  const Flexible(
                    child: Text(
                      'PEDIDO CERRADO',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.4,
                        color: OrderPresentation.muted,
                      ),
                    ),
                  )
                else if (connected)
                  const OrderLiveLabel(),
                IconButton(
                  onPressed: onRefresh,
                  tooltip: 'Actualizar',
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'PEDIDO #${order.id}${date == null ? '' : ' · ${_shortDate(date)}'}',
              style: const TextStyle(
                fontSize: 9,
                letterSpacing: 1.6,
                color: OrderPresentation.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 13),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: closed ? 'Este antojo\n' : 'Tu antojo,\n'),
                  TextSpan(
                    text: _headline(order),
                    style: const TextStyle(color: OrderPresentation.coral),
                  ),
                ],
              ),
              style: const TextStyle(
                fontSize: 34,
                height: 1.12,
                letterSpacing: -1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(order.restaurant.name, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              _stateLine(order),
              key: const ValueKey('order-current-status'),
              style: const TextStyle(
                fontSize: 12,
                height: 1.6,
                color: OrderPresentation.muted,
              ),
            ),
            if (!closed) ...[
              const SizedBox(height: 23),
              _StageProgress(order: order),
            ],
            if (order.acceptanceDeadlineLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  order.acceptanceDeadlineLabel!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: OrderPresentation.yellow,
                  ),
                ),
              ),
            if (order.status == 'pending' && order.acceptedAt == null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: OutlinedButton.icon(
                  onPressed: cancelling ? null : onCancel,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: Text(cancelling ? 'Procesando…' : 'Cancelar pedido'),
                ),
              )
            else if (order.isActive)
              const _Notice(
                'El restaurante ya aceptó tu pedido. Ya no podés cancelarlo desde la app.',
              ),
            if (closed) ...[
              _Notice(
                order.status == 'rejected'
                    ? 'El restaurante no pudo con este pedido.'
                    : order.cancellationReason ?? 'Este pedido se canceló.',
                icon: Icons.cancel_outlined,
              ),
              if (order.paymentMethod == 'cash')
                const Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: OrderPresentation.mint,
                      size: 18,
                    ),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'No tenés que pagar este pedido.',
                        style: TextStyle(
                          fontSize: 12,
                          color: OrderPresentation.mint,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
            if (order.status == 'ready')
              const _Notice('Está listo. Falta que un motorizado lo recoja.'),
            if (order.status == 'picked_up')
              const _Notice('Va en camino hacia tu dirección.'),
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.only(top: 24, bottom: 22),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: OrderPresentation.line),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          closed ? 'Total original' : 'Total del pedido',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          closed
                              ? 'Conservado en tu historial'
                              : order.paymentMethod == 'cash'
                              ? 'Pagás en efectivo al recibir'
                              : 'Pago: ${order.paymentMethod}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: OrderPresentation.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      '\$${order.total}',
                      style: const TextStyle(
                        fontSize: 32,
                        letterSpacing: -1,
                        color: OrderPresentation.coral,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (order.isActive) ...[
              _MapDisclosure(orderId: order.id, map: map),
              if (order.courier != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Tu motorizado: ${order.courier!.name}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  location?.isFresh == true
                      ? gpsError
                            ? 'Última ubicación recibida · Sin conexión GPS actualizada'
                            : 'GPS actualizado · Precisión ±${location!.accuracy.round()} m'
                      : 'Esperando una ubicación reciente del motorista.',
                  key: const ValueKey('courier-gps-status'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: OrderPresentation.muted,
                  ),
                ),
              ],
            ],
            _Disclosure(
              title: 'Tu pedido',
              initiallyExpanded: true,
              children: [
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 21),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity}×',
                          style: const TextStyle(
                            fontSize: 12,
                            color: OrderPresentation.coral,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '\$${item.subtotal}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                _SummaryRow('Productos', order.subtotal),
                _SummaryRow('Envío', order.deliveryFee),
                _SummaryRow('Propina', order.tipAmount),
              ],
            ),
            _Disclosure(
              title: 'Entrega',
              children: [
                if (order.delivery != null) ...[
                  Text(
                    order.delivery!.address,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                  if (order.delivery!.reference?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        order.delivery!.reference!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: OrderPresentation.muted,
                          height: 1.6,
                        ),
                      ),
                    ),
                ],
                if (!order.isActive && order.courier != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Tu motorizado: ${order.courier!.name}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (!order.isActive)
                  _MapDisclosure(orderId: order.id, map: map, closed: true),
              ],
            ),
            _Disclosure(
              title: 'Recorrido del pedido',
              children: [_Timeline(order: order)],
            ),
          ],
        ),
      ),
    );
  }

  String _stateLine(Order order) {
    final date = switch (order.status) {
      'pending' => order.createdAt,
      'accepted' => order.acceptedAt,
      'ready' => order.readyAt,
      'picked_up' => order.pickedUpAt,
      'delivered' => order.deliveredAt,
      'cancelled' || 'rejected' => order.cancelledAt,
      _ => null,
    };
    return '${order.statusLabel}${date == null ? '' : ' · ${OrderPresentation.date(date)}'}';
  }

  String _shortDate(DateTime date) {
    const months = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _headline(Order order) => switch (order.status) {
    'pending' => 'recién pedido.',
    'accepted' || 'preparing' => 'en preparación.',
    'ready' => 'listo para recoger.',
    'picked_up' => 'en camino.',
    'delivered' => 'entregado.',
    'cancelled' || 'rejected' => 'no pudo ser.',
    _ => order.statusLabel,
  };
}

class _Notice extends StatelessWidget {
  const _Notice(this.message, {this.icon});
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 22),
    padding: const EdgeInsets.only(left: 12, top: 3, bottom: 3),
    decoration: const BoxDecoration(
      border: Border(
        left: BorderSide(color: OrderPresentation.coral, width: 2),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 10)],
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 11,
              height: 1.7,
              color: OrderPresentation.muted,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StageProgress extends StatelessWidget {
  const _StageProgress({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final stage = switch (order.status) {
      'pending' => 1,
      'accepted' || 'preparing' => 2,
      'ready' => 3,
      'picked_up' => 4,
      'delivered' => 5,
      _ => 0,
    };
    return Semantics(
      label: '$stage de 5 etapas completadas',
      child: Column(
        children: [
          Row(
            children: List.generate(
              5,
              (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index == 4 ? 0 : 5),
                  decoration: BoxDecoration(
                    color: index < stage
                        ? OrderPresentation.coral
                        : OrderPresentation.line,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Recibido',
                  style: TextStyle(fontSize: 9, color: OrderPresentation.muted),
                ),
              ),
              Expanded(
                child: Text(
                  'Preparando',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: OrderPresentation.muted),
                ),
              ),
              Expanded(
                child: Text(
                  'Entregado',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 9, color: OrderPresentation.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapDisclosure extends StatelessWidget {
  const _MapDisclosure({
    required this.orderId,
    required this.map,
    this.closed = false,
  });
  final int orderId;
  final Widget map;
  final bool closed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: OrderPresentation.surface,
        child: ExpansionTile(
          key: PageStorageKey('customer-order-map-$orderId'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 15),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: OrderPresentation.ink,
          collapsedIconColor: OrderPresentation.ink,
          leading: const Icon(
            Icons.map_outlined,
            size: 18,
            color: OrderPresentation.ink,
          ),
          title: Text(
            closed ? 'Ver ubicación en el mapa' : 'Dónde va tu pedido',
            style: const TextStyle(fontSize: 12, color: OrderPresentation.ink),
          ),
          children: [map],
        ),
      ),
    ),
  );
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: OrderPresentation.line)),
    ),
    child: ExpansionTile(
      key: PageStorageKey('customer-order-section-$title'),
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(vertical: 7),
      childrenPadding: const EdgeInsets.only(top: 8, bottom: 19),
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: OrderPresentation.ink,
      collapsedIconColor: OrderPresentation.ink,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: OrderPresentation.ink,
        ),
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ],
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: OrderPresentation.muted,
            ),
          ),
        ),
        Text(
          '\$$value',
          style: const TextStyle(fontSize: 12, color: OrderPresentation.muted),
        ),
      ],
    ),
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final closed = order.status == 'cancelled' || order.status == 'rejected';
    final steps = <({String label, DateTime? date})>[
      (label: 'Pedido hecho', date: order.createdAt),
      if (!closed || order.acceptedAt != null)
        (label: 'El restaurante lo aceptó', date: order.acceptedAt),
      if (!closed || order.readyAt != null)
        (label: 'Listo para recoger', date: order.readyAt),
      if (!closed || order.pickedUpAt != null)
        (label: 'En camino', date: order.pickedUpAt),
      if (!closed) (label: 'Entregado', date: order.deliveredAt),
      if (closed) (label: order.statusLabel, date: order.cancelledAt),
    ];
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color:
                            steps[i].date != null ||
                                closed && i == steps.length - 1
                            ? OrderPresentation.coral
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: OrderPresentation.line),
                      ),
                      child:
                          steps[i].date != null ||
                              closed && i == steps.length - 1
                          ? Icon(
                              closed && i == steps.length - 1
                                  ? Icons.close_rounded
                                  : Icons.check_rounded,
                              size: 12,
                              color: OrderPresentation.background,
                            )
                          : null,
                    ),
                    if (i < steps.length - 1)
                      Expanded(
                        child: Container(
                          width: 1,
                          color: OrderPresentation.line,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == steps.length - 1 ? 0 : 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[i].label,
                          key: ValueKey('order-milestone-$i'),
                          style: TextStyle(
                            fontSize: 12,
                            color: steps[i].date != null
                                ? OrderPresentation.ink
                                : OrderPresentation.muted,
                          ),
                        ),
                        if (steps[i].date != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              OrderPresentation.date(steps[i].date!),
                              style: const TextStyle(
                                fontSize: 10,
                                color: OrderPresentation.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
