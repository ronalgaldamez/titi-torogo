import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// La pantalla que ve el cliente despues de confirmar.
///
/// Es a proposito una pantalla y no un aviso que se va solo: confirmar un
/// pedido es de las acciones mas importantes de la app, y el cliente tiene que
/// poder mirar que quedo hecho.
///
/// El seguimiento en vivo (que el restaurante acepte, que el motorizado lo
/// traiga) viene en el paso siguiente. Por eso aca NO se promete algo que
/// todavia no existe.
class OrderSentScreen extends StatelessWidget {
  const OrderSentScreen({
    required this.orderId,
    required this.restaurantName,
    required this.total,
    super.key,
  });

  final int orderId;
  final String restaurantName;

  /// El total que se paga en efectivo: platos + envio.
  final String total;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: AppTheme.mint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 52,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '¡Pedido enviado!',
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Pedido #$orderId · $restaurantName',
                textAlign: TextAlign.center,
                style: text.titleSmall?.copyWith(color: AppTheme.tealDeep),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppTheme.tealSoft,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      'Pagás en efectivo al recibir',
                      style: text.bodySmall?.copyWith(color: AppTheme.navy),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '\$$total',
                      style: text.headlineSmall?.copyWith(
                        color: AppTheme.coral,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'El restaurante lo va a confirmar en unos minutos.',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: AppTheme.navy),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context)
                      .popUntil((Route<dynamic> route) => route.isFirst),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.coral,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  child: const Text(
                    'Volver al inicio',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
