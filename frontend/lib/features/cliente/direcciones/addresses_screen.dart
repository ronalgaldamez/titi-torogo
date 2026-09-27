import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../models/address.dart';
import 'address_form_screen.dart';
import 'address_repository.dart';

/// "Mis direcciones": la lista, con la predeterminada marcada.
///
/// Es la pantalla que pide la biblia en el perfil del cliente. Desde aca se
/// crea, se edita y se borra.
///
/// El checkout NO usa esta pantalla para elegir: tiene su propio selector
/// rapido, porque ahi el cliente quiere elegir y seguir, no administrar.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final Session _session = Session(AuthStorage());

  List<Address> _addresses = <Address>[];
  bool _loading = true;
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
      final ApiClient api = await _session.client();
      final List<Address> addresses = await AddressRepository(api).load();

      if (!mounted) {
        return;
      }

      setState(() {
        _addresses = addresses;
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

  /// Abre el formulario y recarga la lista al volver.
  ///
  /// Se recarga SIEMPRE, aunque no sepa si guardo o borro: una peticion de mas
  /// es mas barata que una lista mostrando algo que ya no existe.
  Future<void> _openForm({Address? address}) async {
    await Navigator.of(context).push<Address>(
      MaterialPageRoute<Address>(
        builder: (BuildContext context) => AddressFormScreen(address: address),
      ),
    );

    if (!mounted) {
      return;
    }

    await _load();
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
          'Mis direcciones',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppTheme.coral,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva dirección'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: 'No pudimos cargar tus direcciones',
        message: _error!,
        actionLabel: 'Reintentar',
        onAction: _load,
      );
    }

    if (_addresses.isEmpty) {
      return _Message(
        icon: Icons.place_outlined,
        title: 'Todavía no tenés direcciones',
        message: 'Agregá una para poder pedir. La primera queda como '
            'predeterminada sola.',
        actionLabel: 'Agregar dirección',
        onAction: () => _openForm(),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.teal,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl * 3,
        ),
        children: <Widget>[
          for (final Address address in _addresses)
            _AddressRow(
              address: address,
              onTap: () => _openForm(address: address),
            ),
        ],
      ),
    );
  }
}

/// Una direccion de la lista. Se toca para editarla.
class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.onTap});

  final Address address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            address.label,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navy,
                            ),
                          ),
                          if (address.isDefault) ...<Widget>[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.tealSoft,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                'Predeterminada',
                                style: text.labelSmall?.copyWith(
                                  color: AppTheme.tealDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        address.address,
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (address.reference != null &&
                          address.reference!.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          address.reference!,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppTheme.navy),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla de aviso: error de red o lista vacia.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: AppTheme.teal),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppTheme.navy),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
