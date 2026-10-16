import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/food_category_icon.dart';
import '../../../models/food_category.dart';
import 'restaurant_categories_repository.dart';

class RestaurantCategoriesScreen extends StatefulWidget {
  const RestaurantCategoriesScreen({super.key});

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
      if (!mounted) return;
      setState(() {
        _categories = data.categories;
        _selected = data.selectedIds.intersection(
          data.categories.map((c) => c.id).toSet(),
        );
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await RestaurantCategoriesRepository(
        await _session.client(),
      ).save(_selected);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
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
