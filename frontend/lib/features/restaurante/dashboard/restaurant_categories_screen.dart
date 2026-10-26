import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/food_category_icon.dart';
import '../../../models/food_category.dart';
import 'restaurant_categories_repository.dart';

class RestaurantCategoriesScreen extends StatefulWidget {
  const RestaurantCategoriesScreen({this.asDialog = false, super.key});

  final bool asDialog;

  @override
  State<RestaurantCategoriesScreen> createState() =>
      _RestaurantCategoriesScreenState();
}

class _RestaurantCategoriesScreenState
    extends State<RestaurantCategoriesScreen> {
  final _session = Session(AuthStorage());
  List<FoodCategory> _categories = [];
  Set<int> _selected = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _saveError;

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
      final data = await RestaurantCategoriesRepository(
        await _session.client(),
      ).load();
      if (!mounted) {
        return;
      }
      setState(() {
        _categories = data.categories;
        _selected = data.selectedIds.intersection(
          data.categories.map((c) => c.id).toSet(),
        );
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await RestaurantCategoriesRepository(
        await _session.client(),
      ).save(_selected);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      if (widget.asDialog) {
        setState(() => _saveError = error.message);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asDialog) {
      return _dialog();
    }
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Categorías de mi local')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  const Text(
                    'Elegí los tipos de comida que ofrecés. Los clientes podrán encontrar tu restaurante con estos filtros.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_categories.isEmpty)
                    const Text('Todavía no hay categorías disponibles.'),
                  for (final category in _categories)
                    CheckboxListTile(
                      key: ValueKey('local-category-${category.id}'),
                      title: Text(category.name),
                      secondary: FoodCategoryIcon(category: category, size: 32),
                      value: _selected.contains(category.id),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              if (value == true) {
                                _selected.add(category.id);
                              } else {
                                _selected.remove(category.id);
                              }
                            }),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    '¿Te falta una categoría? Contactá al administrador para que la agregue.',
                  ),
                ],
              ),
        bottomNavigationBar: _loading || _error != null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando…' : 'Guardar categorías'),
                  ),
                ),
              ),
      ),
    );
  }

  void _toggleCategory(int id) {
    if (_saving) {
      return;
    }
    setState(() {
      if (!_selected.add(id)) {
        _selected.remove(id);
      }
    });
  }

  Widget _categoryOption(FoodCategory category) {
    final selected = _selected.contains(category.id);
    return Semantics(
      key: ValueKey('local-category-${category.id}'),
      label: category.name,
      checked: selected,
      enabled: !_saving,
      excludeSemantics: true,
      onTap: _saving ? null : () => _toggleCategory(category.id),
      child: Material(
        color: selected ? const Color(0xFF2B4149) : const Color(0xFF21414F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: BorderSide(
            color: selected ? const Color(0x80FF825E) : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: _saving ? null : () => _toggleCategory(category.id),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 57),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: FoodCategoryIcon(
                        category: category,
                        size: 20,
                        color: selected
                            ? AppTheme.discoveryAccent
                            : AppTheme.discoveryMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.discoveryPaper,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IgnorePointer(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: selected,
                        onChanged: _saving
                            ? null
                            : (_) => _toggleCategory(category.id),
                        shape: const CircleBorder(),
                        side: const BorderSide(color: Color(0xFF718B95)),
                        activeColor: AppTheme.discoveryAccent,
                        checkColor: AppTheme.discoveryBackground,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialog() => PopScope(
    canPop: !_saving,
    child: Dialog(
      backgroundColor: const Color(0xFF183744),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0x1FFFFFFF)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 370,
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'LO QUE OFRECÉS',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.7,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.discoveryMuted,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cerrar',
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close,
                              size: 20,
                              color: AppTheme.discoveryMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text.rich(
                        const TextSpan(
                          children: [
                            TextSpan(text: 'El sabor de\n'),
                            TextSpan(
                              text: 'tu negocio.',
                              style: TextStyle(color: AppTheme.discoveryAccent),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: MediaQuery.sizeOf(context).width <= 350
                              ? 31
                              : 34,
                          fontWeight: FontWeight.w800,
                          height: 1.08,
                          letterSpacing: -1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Elegí las categorías de tu local.\nPodés marcar más de una.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.7,
                          color: AppTheme.discoveryMuted,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_error != null) ...[
                        Text(_error!),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ] else ...[
                        if (_categories.isEmpty)
                          const Text('Todavía no hay categorías disponibles.'),
                        for (final category in _categories) ...[
                          _categoryOption(category),
                          if (category != _categories.last)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _saveError!,
                    style: const TextStyle(
                      color: AppTheme.discoveryAccent,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 5,
                    color: _selected.isEmpty
                        ? AppTheme.discoveryMuted
                        : AppTheme.discoveryAccent,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _selected.isEmpty
                          ? 'Elegí lo que preparás.'
                          : _selected.length == 1
                          ? 'Una categoría seleccionada'
                          : '${_selected.length} categorías seleccionadas',
                      key: const ValueKey('category-selection-count'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.discoveryMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_loading && _error == null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.discoveryAccent,
                      foregroundColor: AppTheme.discoveryBackground,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      minimumSize: const Size(0, 49),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _saving ? 'Guardando…' : 'Guardar selección',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ),
              Center(
                child: TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Volver sin guardar',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.discoveryMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
