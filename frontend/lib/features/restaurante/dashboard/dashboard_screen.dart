import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../models/restaurant.dart';
import 'restaurant_status_repository.dart';
import 'restaurant_categories_screen.dart';

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
      final Restaurant restaurant = await RestaurantStatusRepository(
        api,
      ).load();

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
  Future<void> _save({
    bool? isOpen,
    bool? isBusy,
    int? preparationMinimum,
    int? preparationMaximum,
  }) async {
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
        preparationMinimum: preparationMinimum,
        preparationMaximum: preparationMaximum,
      );

      if (!mounted) {
        return;
      }

      setState(() => _restaurant = saved);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            preparationMinimum == null
                ? _confirmation(saved)
                : 'Tiempo de preparación actualizado.',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      // No se toca el estado que se ve: si el backend rechazo el cambio, lo que
      // esta en pantalla sigue siendo lo que dice la base. Nada de mentirle al
      // dueno con un interruptor que quedo al reves.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _editPreparation() async {
    final restaurant = _restaurant;
    if (restaurant == null || _saving) {
      return;
    }
    final range = await showDialog<(int, int)>(
      context: context,
      builder: (_) => _PreparationDialog(
        minimum: restaurant.preparationMinimum,
        maximum: restaurant.preparationMaximum,
      ),
    );
    if (!mounted || range == null) {
      return;
    }
    await _save(preparationMinimum: range.$1, preparationMaximum: range.$2);
  }

  /// Lo que se le dice al dueno despues de guardar.
  String _confirmation(Restaurant restaurant) {
    if (!restaurant.isOpen) {
      return 'Tu local quedó cerrado: no aparecés en la app y no te llegan '
          'pedidos nuevos.';
    }

    if (restaurant.isBusy) {
      return 'Estás abierto y muy ocupado: preparación estimada de ${restaurant.preparationTimeLabel}.';
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
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.coral,
                    borderRadius: BorderRadius.circular(AppRadius.image),
                  ),
                  child: Text(
                    restaurant.name.trim().isEmpty
                        ? 'L'
                        : restaurant.name.trim().characters.first.toUpperCase(),
                    style: text.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        style: text.titleMedium?.copyWith(
                          color: AppTheme.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (restaurant.description?.isNotEmpty ?? false) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          restaurant.description!,
                          style: text.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _StatusHeader(restaurant: restaurant),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            key: const ValueKey('local-categories'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.category_outlined,
              color: AppTheme.tealDeep,
            ),
            title: const Text('Categorías de mi local'),
            subtitle: Text(
              restaurant.foodCategories.isEmpty
                  ? 'Elegí los tipos de comida que ofrecés'
                  : restaurant.foodCategories.map((c) => c.name).join(' · '),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _saving
                ? null
                : () async {
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const RestaurantCategoriesScreen(),
                      ),
                    );
                    if (mounted) await _load();
                  },
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Disponibilidad del local',
            style: text.titleMedium?.copyWith(
              color: AppTheme.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  key: const ValueKey('local-open'),
                  secondary: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.tealSoft,
                      borderRadius: BorderRadius.circular(AppRadius.image),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: AppTheme.tealDeep,
                    ),
                  ),
                  value: restaurant.isOpen,
                  onChanged: _saving ? null : (value) => _save(isOpen: value),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(
                    'Local abierto',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Permití que los clientes encuentren tu local y hagan pedidos.',
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  key: const ValueKey('local-busy'),
                  secondary: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.tealSoft,
                      borderRadius: BorderRadius.circular(AppRadius.image),
                    ),
                    child: const Icon(
                      Icons.soup_kitchen_outlined,
                      color: AppTheme.tealDeep,
                    ),
                  ),
                  value: restaurant.isBusy,
                  onChanged: _saving || !restaurant.isOpen
                      ? null
                      : (value) => _save(isBusy: value),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                  ),
                  title: Text(
                    'Muy ocupado',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    restaurant.isOpen
                        ? 'Activá este modo si tu cocina necesita más tiempo.'
                        : 'Abrí el local para activar este modo.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heading = Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: AppTheme.tealDeep,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurant.isOpen
                                ? 'Tiempo de preparación'
                                : 'Pedidos nuevos pausados',
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            restaurant.isOpen
                                ? 'Estimación que ve el cliente'
                                : 'Tu local está cerrado',
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final estimate = Text(
                  restaurant.preparationTimeLabel,
                  key: const ValueKey('local-delivery-time'),
                  style: text.headlineSmall?.copyWith(
                    color: AppTheme.tealDeep,
                    fontWeight: FontWeight.w800,
                  ),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (restaurant.isOpen && constraints.maxWidth >= 300)
                      Row(
                        children: [
                          Expanded(child: heading),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(child: estimate),
                        ],
                      )
                    else ...[
                      heading,
                      if (restaurant.isOpen) ...[
                        const SizedBox(height: AppSpacing.sm),
                        estimate,
                      ],
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      restaurant.isOpen
                          ? '«Muy ocupado» aumenta un 50%, hasta un máximo de 45 minutos.'
                          : 'Volvé a abrir cuando estés listo para recibir pedidos.',
                      style: text.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const ValueKey('edit-preparation'),
            onPressed: _saving ? null : _editPreparation,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar tiempo de preparación'),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_saving) const LinearProgressIndicator(),
          Text(
            'Al cerrar, tu local deja de aparecer en la app y no recibe pedidos nuevos.',
            style: text.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final title = !restaurant.isOpen
        ? 'Local cerrado'
        : restaurant.isBusy
        ? 'Abierto y muy ocupado'
        : 'Recibiendo pedidos';
    final message = !restaurant.isOpen
        ? 'No aparecés en la app ni recibís pedidos nuevos.'
        : restaurant.isBusy
        ? 'Seguís recibiendo pedidos con más tiempo para la cocina.'
        : 'Tu local está abierto y visible para los clientes.';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.tealSoft,
        borderRadius: BorderRadius.circular(AppRadius.image),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: !restaurant.isOpen
                      ? AppTheme.coral
                      : restaurant.isBusy
                      ? AppTheme.yellow
                      : AppTheme.mint,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: text.titleSmall?.copyWith(
                    color: AppTheme.tealDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: text.bodySmall?.copyWith(color: AppTheme.navy)),
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
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _PreparationDialog extends StatefulWidget {
  const _PreparationDialog({required this.minimum, required this.maximum});
  final int minimum;
  final int maximum;
  @override
  State<_PreparationDialog> createState() => _PreparationDialogState();
}

class _PreparationDialogState extends State<_PreparationDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _minimum;
  late final TextEditingController _maximum;
  @override
  void initState() {
    super.initState();
    _minimum = TextEditingController(text: widget.minimum.toString());
    _maximum = TextEditingController(text: widget.maximum.toString());
  }

  @override
  void dispose() {
    _minimum.dispose();
    _maximum.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final minutes = int.tryParse(value?.trim() ?? '');
    return minutes == null || minutes < 10 || minutes > 45
        ? 'Usá entre 10 y 45 minutos.'
        : null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tiempo de preparación'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Indicá cuánto necesita tu cocina. El recorrido de entrega no está incluido. Usá entre 10 y 45 minutos. «Muy ocupado» agrega un 50%, sin superar 45 minutos.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('prep-minimum'),
              controller: _minimum,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Mínimo (minutos)'),
              validator: _validate,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const ValueKey('prep-maximum'),
              controller: _maximum,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Máximo (minutos)'),
              validator: (value) {
                final error = _validate(value);
                if (error != null) {
                  return error;
                }
                final minimum = int.tryParse(_minimum.text.trim());
                if (minimum != null && int.parse(value!.trim()) < minimum) {
                  return 'El máximo debe ser igual o mayor al mínimo.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.of(context).pop((
              int.parse(_minimum.text.trim()),
              int.parse(_maximum.text.trim()),
            ));
          }
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
