import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../models/restaurant.dart';
import 'restaurant_status_repository.dart';

/// El dashboard del restaurante: el estado de su local.
///
/// Es lo que la biblia pide para este perfil ("Estado del restaurante
/// (abierto/cerrado)" y "Modo Muy ocupado"), y no es un adorno: hoy es lo UNICO
/// que hace que un local pueda cerrar de verdad.
///
/// QUE HACE CERRAR (lo hace el backend, no esta pantalla):
///
///   - el local deja de aparecer en el Home del cliente,
///   - y si igual llega un pedido, se rechaza con un mensaje claro.
///
///   Sin esto, un restaurante que se quedo sin ingredientes seguia recibiendo
///   pedidos que no podia preparar, y el cliente esperando.
///
/// QUE HACE "MUY OCUPADO":
///
///   No cierra nada. Alarga el tiempo de entrega un 50% (15 minutos pasan a 23)
///   para no prometer lo que la cocina no puede cumplir.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Session _session = Session(AuthStorage());

  /// El estado que devolvio el servidor. Null mientras carga.
  Restaurant? _restaurant;

  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ApiClient api = await _session.client();
      final Restaurant restaurant =
          await RestaurantStatusRepository(api).load();

      if (!mounted) {
        return;
      }

      setState(() {
        _restaurant = restaurant;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  /// Manda el estado nuevo, cambiando solo el interruptor que se toco.
  ///
  /// Los dos valores viajan siempre porque el backend los exige juntos: asi un
  /// toque en "abierto" no puede borrar el "muy ocupado" sin querer.
  Future<void> _save({bool? isOpen, bool? isBusy}) async {
    final Restaurant? current = _restaurant;

    // Sin estado cargado no hay nada que cambiar, y con un guardado en vuelo
    // tampoco: dos toques rapidos mandarian dos peticiones y la segunda
    // pisaria a la primera con datos viejos.
    if (current == null || _saving) {
      return;
    }

    setState(() => _saving = true);

    try {
      final ApiClient api = await _session.client();
      final Restaurant saved = await RestaurantStatusRepository(api).save(
        isOpen: isOpen ?? current.isOpen,
        isBusy: isBusy ?? current.isBusy,
      );

      if (!mounted) {
        return;
      }

      setState(() => _restaurant = saved);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_confirmation(saved))),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      // No se toca el estado que se ve: si el backend rechazo el cambio, lo que
      // esta en pantalla sigue siendo lo que dice la base. Nada de mentirle al
      // dueno con un interruptor que quedo al reves.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Lo que se le dice al dueno despues de guardar.
  String _confirmation(Restaurant restaurant) {
    if (!restaurant.isOpen) {
      return 'Tu local quedó cerrado: no aparecés en la app y no te llegan '
          'pedidos nuevos.';
    }

    if (restaurant.isBusy) {
      return 'Estás abierto y muy ocupado: el envío se calcula en '
          '${restaurant.estimatedDeliveryMinutes} minutos.';
    }

    return 'Estás abierto y recibiendo pedidos.';
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
          'Mi local',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _saving ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
            color: AppTheme.navy,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final Restaurant? restaurant = _restaurant;

    if (restaurant == null) {
      return _ErrorBox(
        message: _error ?? 'No pudimos cargar el estado de tu local.',
        onRetry: _load,
      );
    }

    final TextTheme text = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.teal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: <Widget>[
          _StatusHeader(restaurant: restaurant),
          const SizedBox(height: AppSpacing.lg),

          SwitchListTile(
            value: restaurant.isOpen,
            onChanged: _saving
                ? null
                : (bool value) => _save(isOpen: value),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.teal,
            title: Text(
              'Abierto',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
            subtitle: Text(
              'Con el local cerrado no aparecés en la app y no te llegan '
              'pedidos nuevos. Es lo que se usa cuando te quedaste sin algo o '
              'ya cerraste por hoy.',
              style: text.bodySmall?.copyWith(color: AppTheme.navy),
            ),
          ),

          const Divider(height: AppSpacing.lg),

          SwitchListTile(
            value: restaurant.isBusy,
            // Con el local cerrado, "muy ocupado" no significa nada: no hay
            // pedidos que puedan llegar más lento porque no llega ninguno.
            onChanged: (_saving || !restaurant.isOpen)
                ? null
                : (bool value) => _save(isBusy: value),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppTheme.yellow,
            title: Text(
              'Muy ocupado',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
            subtitle: Text(
              restaurant.isOpen
                  ? 'Alarga el tiempo de entrega a '
                      '${restaurant.estimatedDeliveryMinutes} minutos. Usalo '
                      'cuando hay mucha cola: es mejor avisar que prometer y '
                      'no cumplir.'
                  : 'Primero abrí el local. Cerrado no hay tiempo que alargar.',
              style: text.bodySmall?.copyWith(color: AppTheme.navy),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppTheme.tealSoft,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: AppTheme.tealDeep,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'El cliente ve que su pedido llega en unos '
                    '${restaurant.estimatedDeliveryMinutes} minutos.',
                    style: text.bodySmall?.copyWith(color: AppTheme.tealDeep),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// El encabezado: como esta el local, en grande.
class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    // Un color por estado, para que se entienda de un vistazo desde lejos:
    // verde cuando recibe pedidos, amarillo cuando esta saturado, y coral
    // cuando esta cerrado (lo que hay que arreglar si no fue a proposito).
    final Color background = !restaurant.isOpen
        ? AppTheme.coral
        : restaurant.isBusy
            ? AppTheme.yellow
            : AppTheme.mint;

    final Color foreground = background == AppTheme.mint
        ? Colors.white
        : restaurant.isBusy
            ? AppTheme.navy
            : Colors.white;

    final String title = !restaurant.isOpen
        ? 'Cerrado'
        : restaurant.isBusy
            ? 'Abierto y muy ocupado'
            : 'Abierto';

    final String message = !restaurant.isOpen
        ? 'No aparecés en la app y no te llegan pedidos nuevos.'
        : restaurant.isBusy
            ? 'Estás recibiendo pedidos, con el tiempo de entrega alargado.'
            : 'Estás recibiendo pedidos con normalidad.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            restaurant.name,
            style: text.labelLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: text.bodySmall?.copyWith(color: foreground),
          ),
        ],
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
