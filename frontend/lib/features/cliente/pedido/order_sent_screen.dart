import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../checkout_appearance.dart';
import 'order_tracking_screen.dart';

/// Confirma el envío recibido por el servidor, no la aceptación del restaurante.
class OrderSentScreen extends StatefulWidget {
  const OrderSentScreen({
    required this.orderId,
    required this.restaurantName,
    required this.total,
    this.alreadySent = false,
    this.tipAmount = '0.00',
    super.key,
  });

  final int orderId;
  final String restaurantName;
  final String total;
  final bool alreadySent;
  final String tipAmount;

  @override
  State<OrderSentScreen> createState() => _OrderSentScreenState();
}

class _OrderSentScreenState extends State<OrderSentScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final CurvedAnimation _check = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.4, curve: Curves.easeOutCubic),
  );
  late final CurvedAnimation _heading = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.24, 0.55, curve: Curves.easeOut),
  );
  late final CurvedAnimation _details = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.65, 1, curve: Curves.easeOutCubic),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations || widget.alreadySent) {
      _controller.value = 1;
      _started = true;
    } else if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _check.dispose();
    _heading.dispose();
    _details.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = checkoutTheme(context);
    final text = theme.textTheme;
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: AppTheme.discoveryBackground,
        appBar: checkoutAppBar(back: false),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 17, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FadeTransition(
                  opacity: _check,
                  child: ScaleTransition(
                    alignment: Alignment.centerLeft,
                    scale: Tween<double>(begin: 0.65, end: 1).animate(_check),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: flowMint.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 29,
                          color: flowMint,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                FadeTransition(
                  opacity: _heading,
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedido #${widget.orderId}',
                          style: const TextStyle(
                            color: flowMint,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        CheckoutHeading(
                          widget.alreadySent
                              ? 'Pedido recuperado'
                              : '¡Pedido enviado!',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          widget.alreadySent
                              ? 'Este pedido ya se había enviado. No se creó otro pedido.'
                              : 'Estamos esperando la confirmación del restaurante.',
                          style: text.bodyMedium?.copyWith(
                            color: AppTheme.discoveryMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 17),
                AnimatedBuilder(
                  animation: _details,
                  builder: (context, child) => IgnorePointer(
                    ignoring: _details.value == 0,
                    child: ExcludeSemantics(
                      excluding: _details.value == 0,
                      child: FadeTransition(
                        opacity: _details,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.025),
                            end: Offset.zero,
                          ).animate(_details),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Text(
                        widget.restaurantName,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      OverflowBar(
                        alignment: MainAxisAlignment.spaceBetween,
                        spacing: AppSpacing.sm,
                        overflowSpacing: AppSpacing.xs,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total a pagar al recibir',
                                style: TextStyle(
                                  color: AppTheme.discoveryMuted,
                                ),
                              ),
                              Text(
                                'En efectivo',
                                style: TextStyle(
                                  color: AppTheme.discoveryMuted,
                                ),
                              ),
                            ],
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              '\$${widget.total}',
                              maxLines: 1,
                              style: const TextStyle(
                                color: AppTheme.discoveryAccent,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.tipAmount != '0.00')
                        Text(
                          'Incluye \$${widget.tipAmount} de propina para el motorista',
                          style: text.bodySmall?.copyWith(
                            color: AppTheme.discoveryMuted,
                          ),
                        ),
                      const SizedBox(height: 17),
                      CheckoutAction(
                        'Ver seguimiento',
                        onPressed: () =>
                            Navigator.of(context).pushReplacement<void, void>(
                              MaterialPageRoute<void>(
                                builder: (_) => OrderTrackingScreen(
                                  orderId: widget.orderId,
                                ),
                              ),
                            ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst),
                          child: const Text('Volver al inicio'),
                        ),
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
}
