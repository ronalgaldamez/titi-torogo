import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import 'my_orders_content.dart';
import 'order_presentation.dart';
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
  const MyOrdersScreen({this.onDestinationSelected, super.key});

  final ValueChanged<int>? onDestinationSelected;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with WidgetsBindingObserver {
  final Session _session = Session(AuthStorage());

  List<Order> _active = <Order>[];
  List<Order> _history = <Order>[];

  bool _loading = true;
  String? _error;
  int _filter = 0;
  Timer? _refreshTimer;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_active.isNotEmpty &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          ModalRoute.of(context)?.isCurrent == true) {
        unawaited(_load(silent: true));
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _active.isNotEmpty &&
        ModalRoute.of(context)?.isCurrent == true) {
      unawaited(_load(silent: true));
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

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
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      if (silent) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } finally {
      _fetching = false;
    }
  }

  /// Abre el seguimiento y, al volver, recarga: el pedido pudo haber avanzado
  /// mientras el cliente lo miraba.
  Future<void> _openTracking(Order order) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => OrderTrackingScreen(
          orderId: order.id,
          onDestinationSelected: widget.onDestinationSelected,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _load();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: OrderPresentation.theme(context),
    child: Scaffold(
      backgroundColor: OrderPresentation.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const OrderBrandHeader(),
            Expanded(child: _body()),
          ],
        ),
      ),
    ),
  );

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: OrderPresentation.coral,
                size: 40,
              ),
              const SizedBox(height: 16),
              const Text(
                'No pudimos cargar tus pedidos',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    return MyOrdersContent(
      active: _active,
      history: _history,
      filter: _filter,
      onFilter: (index) => setState(() => _filter = index),
      onOpen: _openTracking,
      onRefresh: _load,
    );
  }
}
