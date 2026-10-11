import 'package:flutter/material.dart';

import '../../../core/theme.dart';
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
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              FadeTransition(
                opacity: _check,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.65, end: 1).animate(_check),
                  child: Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: AppTheme.mint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FadeTransition(
                opacity: _heading,
                child: Column(
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        widget.alreadySent
                            ? 'Pedido recuperado'
                            : '¡Pedido enviado!',
                        textAlign: TextAlign.center,
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Pedido #${widget.orderId}',
                      style: text.bodyMedium?.copyWith(
                        color: AppTheme.tealDeep,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
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
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.storefront_outlined,
                                color: AppTheme.tealDeep,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  widget.restaurantName,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Divider(height: 1),
                          ),
                          Text(
                            'Total a pagar al recibir',
                            textAlign: TextAlign.center,
                            style: text.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            '\$${widget.total}',
                            textAlign: TextAlign.center,
                            style: text.displaySmall?.copyWith(
                              color: AppTheme.coral,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Pagás en efectivo al recibir',
                            textAlign: TextAlign.center,
                            style: text.bodySmall?.copyWith(
                              color: AppTheme.tealDeep,
                            ),
                          ),
                          if (widget.tipAmount != '0.00') ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Incluye \$${widget.tipAmount} de propina para el motorista',
                              textAlign: TextAlign.center,
                              style: text.bodySmall,
                            ),
                          ],
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            child: Divider(height: 1),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: AppTheme.tealDeep,
                                size: 20,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  widget.alreadySent
                                      ? 'Este pedido ya se había enviado. No se creó otro pedido.'
                                      : 'Consultá el seguimiento para ver la confirmación del restaurante y la entrega.',
                                  style: text.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushReplacement<void, void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  OrderTrackingScreen(orderId: widget.orderId),
                            ),
                          ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.coralDeep,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.image),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Ver seguimiento'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst),
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: AppTheme.tealDeep,
                      ),
                      child: const Text('Volver al inicio'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
