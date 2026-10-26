import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../models/restaurant.dart';
import 'restaurant_status_repository.dart';
import 'restaurant_local_content.dart';
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
  const DashboardScreen({this.onMenu, super.key});

  final VoidCallback? onMenu;

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

  Future<void> _editPreparation(BuildContext dialogContext) async {
    final restaurant = _restaurant;
    if (restaurant == null || _saving) {
      return;
    }
    final range = await showDialog<(int, int)>(
      context: dialogContext,
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
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.discoveryAccent,
          onPrimary: AppTheme.discoveryBackground,
          secondary: AppTheme.yellow,
          surface: AppTheme.discoveryBackground,
          onSurface: AppTheme.discoveryPaper,
          onSurfaceVariant: AppTheme.discoveryMuted,
        ),
        textTheme: theme.textTheme.apply(
          bodyColor: AppTheme.discoveryPaper,
          displayColor: AppTheme.discoveryPaper,
        ),
        dividerColor: Colors.white24,
        switchTheme: SwitchThemeData(
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppTheme.discoveryAccent
                : const Color(0xFF47616C),
          ),
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppTheme.discoveryBackground
                : AppTheme.discoveryPaper,
          ),
        ),
      ),
      child: Builder(builder: (context) => _buildLocal(context)),
    );
  }

  Widget _buildLocal(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.discoveryBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.discoveryBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        titleSpacing: 24,
        title: Text.rich(
          const TextSpan(
            children: [
              TextSpan(text: 'toro'),
              TextSpan(
                text: 'go',
                style: TextStyle(color: AppTheme.yellow),
              ),
              TextSpan(
                text: '.',
                style: TextStyle(color: AppTheme.discoveryAccent),
              ),
            ],
          ),
          style: text.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: AppTheme.discoveryPaper,
            letterSpacing: -1.5,
          ),
        ),
        actions: <Widget>[
          const Padding(
            padding: EdgeInsets.only(right: 24),
            child: Center(
              child: Text(
                'MI NEGOCIO',
                style: TextStyle(
                  color: AppTheme.discoveryMuted,
                  fontSize: 10,
                  letterSpacing: 1.7,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
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

    return RefreshIndicator(
      onRefresh: () async {
        if (!_saving) {
          await _load();
        }
      },
      color: AppTheme.discoveryAccent,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 25),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'MI LOCAL',
                        style: TextStyle(
                          color: AppTheme.discoveryMuted,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : _load,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      color: AppTheme.discoveryPaper,
                      tooltip: 'Actualizar',
                    ),
                  ],
                ),
              ),
            ),
          ),
          RestaurantLocalContent(
            restaurant: restaurant,
            saving: _saving,
            onOpen: (value) => _save(isOpen: value),
            onBusy: (value) => _save(isBusy: value),
            onPreparation: () => _editPreparation(context),
            onMenu: widget.onMenu,
            onImagesSaving: (value) {
              if (mounted) {
                setState(() => _saving = value);
              }
            },
            onImagesSaved: (value) {
              if (mounted) {
                setState(() => _restaurant = value);
              }
            },
            onCategories: () async {
              await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const RestaurantCategoriesScreen(asDialog: true),
              );
              if (mounted) {
                await _load();
              }
            },
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
              style: text.bodyMedium?.copyWith(color: AppTheme.discoveryPaper),
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
    backgroundColor: const Color(0xFF183744),
    insetPadding: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0xFF40606D)),
    ),
    titlePadding: const EdgeInsets.fromLTRB(25, 25, 25, 12),
    contentPadding: const EdgeInsets.symmetric(horizontal: 25),
    actionsPadding: const EdgeInsets.fromLTRB(25, 20, 25, 12),
    title: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EL TIEMPO DE TU COCINA',
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.discoveryMuted,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Sin correr.\nSin hacer esperar de más.',
          style: TextStyle(
            fontSize: 23,
            height: 1.25,
            letterSpacing: -.7,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entre 10 y 45 minutos. Muy ocupado agrega un 50%, sin superar 45 minutos.',
              style: TextStyle(fontSize: 12, color: AppTheme.discoveryMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('prep-minimum'),
                    controller: _minimum,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Mínimo',
                      errorMaxLines: 8,
                      filled: true,
                      fillColor: AppTheme.discoveryBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: _validate,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    key: const ValueKey('prep-maximum'),
                    controller: _maximum,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Máximo',
                      errorMaxLines: 8,
                      filled: true,
                      fillColor: AppTheme.discoveryBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (value) {
                      final error = _validate(value);
                      if (error != null) {
                        return error;
                      }
                      final minimum = int.tryParse(_minimum.text.trim());
                      if (minimum != null &&
                          int.parse(value!.trim()) < minimum) {
                        return 'El máximo debe ser igual o mayor al mínimo.';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.of(context).pop((
                    int.parse(_minimum.text.trim()),
                    int.parse(_maximum.text.trim()),
                  ));
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.discoveryAccent,
                foregroundColor: AppTheme.discoveryBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                children: [
                  Expanded(child: Text('Guardar tiempo')),
                  Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Volver',
              style: TextStyle(color: AppTheme.discoveryMuted),
            ),
          ),
        ],
      ),
    ],
  );
}
