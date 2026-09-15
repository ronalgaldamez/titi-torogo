import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../models/delivery_zone.dart';
import 'home_repository.dart';
import 'widgets/restaurant_card.dart';

/// El Home del cliente: los restaurantes que SI entregan donde esta.
///
/// No es "los mas cercanos": es la interseccion entre su ubicacion y las
/// zonas de reparto que dibujamos en Google My Maps.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Ubicacion de prueba: Mall del Sol, Tejutla.
  ///
  /// TODO: reemplazar por el GPS real del telefono. Mientras tanto se usa
  /// esta coordenada, que esta DENTRO de la zona de reparto, para poder ver
  /// el Home con datos reales sin pelear todavia con permisos de Android.
  static const double _latitude = 14.101203787387021;
  static const double _longitude = -89.15061654556241;

  late final HomeRepository _repository;
  late Future<HomeData> _future;

  @override
  void initState() {
    super.initState();
    _repository = HomeRepository(ApiClient());
    _future = _load();
  }

  Future<HomeData> _load() {
    return _repository.load(latitude: _latitude, longitude: _longitude);
  }

  Future<void> _reload() async {
    final Future<HomeData> next = _load();

    setState(() {
      _future = next;
    });

    try {
      // Se espera el resultado para que el indicador de "desliza para
      // actualizar" desaparezca cuando la peticion realmente termino.
      await next;
    } catch (_) {
      // El error ya lo muestra el FutureBuilder. Aqui solo evitamos que
      // la excepcion quede sin manejar.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ToroGo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: FutureBuilder<HomeData>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<HomeData> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.wifi_off,
              title: 'No pudimos cargar los restaurantes',
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }

          final HomeData data = snapshot.data!;

          if (data.isOutsideCoverage) {
            return const _MessageState(
              icon: Icons.location_off,
              title: 'Todavia no llegamos ahi',
              message: 'Estamos empezando en Tejutla. Pronto vamos a cubrir '
                  'mas lugares.',
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: data.restaurants.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return _ZoneBanner(zone: data.zone!);
                }

                return RestaurantCard(restaurant: data.restaurants[index - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

/// Franja superior: en que zona esta el cliente y cuanto cuesta el envio.
class _ZoneBanner extends StatelessWidget {
  const _ZoneBanner({required this.zone});

  final DeliveryZone zone;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.place, size: 18, color: colors.onPrimaryContainer),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Entregamos en ${zone.name}',
                style: text.titleSmall?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // El desglose se muestra a proposito: el cliente ve que el envio
          // va al motorizado y que el servicio es de ToroGo. Es lo que
          // permite subir la tarifa el dia de manana sin que se sienta
          // como un abuso.
          Text(
            'Envio \$${zone.deliveryFee}  '
            '(\$${zone.courierFee} al motorizado + \$${zone.platformFee} de servicio)',
            style: text.bodySmall?.copyWith(color: colors.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

/// Pantalla completa de error o de aviso, con boton para reintentar.
class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 48, color: colors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
