import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../models/address.dart';
import '../checkout_appearance.dart';
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
    return Theme(
      data: checkoutTheme(context),
      child: Scaffold(
        backgroundColor: AppTheme.discoveryBackground,
        appBar: checkoutAppBar(),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
            child: CheckoutAction(
              'Nueva dirección',
              icon: Icons.add_rounded,
              onPressed: () => _openForm(),
            ),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 6, 22, 12),
              child: CheckoutHeading('Mis direcciones', caption: 'Entrega'),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
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
        message:
            'Agregá una para poder pedir. La primera queda como '
            'predeterminada sola.',
        actionLabel: 'Agregar dirección',
        onAction: () => _openForm(),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: flowMint,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 0, 22, AppSpacing.md),
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
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          address.isDefault
              ? Icons.check_circle_outline_rounded
              : Icons.place_outlined,
          color: address.isDefault ? flowMint : AppTheme.discoveryMuted,
        ),
        title: Text(
          address.label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: address.isDefault ? flowMint : AppTheme.discoveryPaper,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(address.address),
            if (address.reference case final reference?
                when reference.isNotEmpty)
              Text(reference),
            if (address.isDefault) const Text('Predeterminada'),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
      const Divider(height: 1),
    ],
  );
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
            Icon(icon, size: 48, color: flowMint),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppTheme.discoveryPaper,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: AppTheme.discoveryPaper),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
