import 'package:flutter/material.dart';

import '../../cliente/pedido/order_presentation.dart';
import '../courier_presentation.dart';

class CourierHistoryHeader extends StatelessWidget {
  const CourierHistoryHeader({
    required this.period,
    required this.status,
    required this.summary,
    required this.range,
    required this.onPeriod,
    required this.onStatus,
    super.key,
  });
  final String period;
  final String status;
  final Map<String, dynamic>? summary;
  final String? range;
  final ValueChanged<String> onPeriod;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const CourierHeading(
        eyebrow: 'EL CAMINO QUE LLEVÁS',
        title: 'Tus entregas',
        subtitle: 'Cada recorrido suma.',
      ),
      const SizedBox(height: 27),
      const CourierEyebrow('PERÍODO'),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        initialValue: period,
        isExpanded: true,
        dropdownColor: OrderPresentation.surface,
        decoration: InputDecoration(
          filled: true,
          fillColor: OrderPresentation.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: OrderPresentation.line),
          ),
        ),
        style: const TextStyle(fontSize: 12, color: OrderPresentation.ink),
        items: const [
          DropdownMenuItem(value: 'today', child: Text('Hoy')),
          DropdownMenuItem(value: 'week', child: Text('Últimos 7 días')),
          DropdownMenuItem(value: 'month', child: Text('Este mes')),
        ],
        onChanged: (value) {
          if (value != null && value != period) {
            onPeriod(value);
          }
        },
      ),
      const SizedBox(height: 28),
      if (summary != null) ...[
        CourierEarnings(
          eyebrow: 'TUS GANANCIAS DEL PERÍODO',
          earnings: summary!['earnings'].toString(),
          deliveries: summary!['deliveries'] as int,
        ),
        if (period != 'today' && range != null) ...[
          const SizedBox(height: 8),
          Text(
            range!,
            style: const TextStyle(
              fontSize: 11,
              color: OrderPresentation.muted,
            ),
          ),
        ],
      ],
      const SizedBox(height: 25),
      DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: OrderPresentation.line)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 18,
            children: [
              for (final filter in const {
                'all': 'Todos',
                'delivered': 'Entregados',
                'cancelled': 'Cancelados',
              }.entries)
                Semantics(
                  selected: status == filter.key,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: status == filter.key
                              ? OrderPresentation.coral
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        minimumSize: const Size(0, 48),
                        foregroundColor: status == filter.key
                            ? OrderPresentation.ink
                            : OrderPresentation.muted,
                      ),
                      onPressed: () {
                        if (status != filter.key) {
                          onStatus(filter.key);
                        }
                      },
                      child: Text(
                        filter.value,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 25),
    ],
  );
}
