import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/theme.dart';
import '../../../models/delivery_zone.dart';
import '../../../models/restaurant.dart';
import '../restaurante/restaurant_detail_screen.dart';
import 'home_repository.dart';
import 'widgets/restaurant_card.dart';

/// El Home del cliente: los restaurantes que SI entregan donde esta.
///
/// No es "los mas cercanos": es la interseccion entre su ubicacion y las
/// zonas de reparto que dibujamos en Google My Maps.
class HomeScreen extends StatefulWidget {
  const HomeScreen({this.onLogout, super.key});

  /// Cerrar sesion. Si viene null, NO se muestra el boton: pasa cuando el
  /// usuario entro con "Explorar sin cuenta" y no tiene sesion que cerrar.
  final Future<void> Function()? onLogout;

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

  /// Abre la carta del restaurante.
  ///
  /// Se le pasa la MISMA ubicacion con la que se cargo el Home: con eso el
  /// backend resuelve la distancia y la tarifa de envio del detalle, y los
  /// numeros que se ven en la carta coinciden con los de la tarjeta.
  void _openRestaurant(Restaurant restaurant) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => RestaurantDetailScreen(
          restaurant: restaurant,
          latitude: _latitude,
          longitude: _longitude,
        ),
      ),
    );
  }

  /// Pide confirmacion antes de cerrar sesion.
  ///
  /// Cerrar sesion es una accion que se toca sin querer, y deshacerla
  /// significa volver a escribir la contrasena. Un dialogo de por medio
  /// evita ese enojo.
  Future<void> _confirmLogout() async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('¿Cerrar sesion?'),
            content: const Text(
              'Vas a salir de tu cuenta en este dispositivo. '
              'Tus pedidos y direcciones quedan guardados.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cerrar sesion'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await widget.onLogout?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.surface,
        titleSpacing: AppSpacing.md,
        title: const _Wordmark(),
        actions: <Widget>[
          // El boton de salir SOLO aparece con sesion iniciada.
          if (widget.onLogout != null)
            IconButton(
              onPressed: _confirmLogout,
              icon: const Icon(Icons.logout_rounded),
              color: AppTheme.navy,
              tooltip: 'Cerrar sesion',
            ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: FutureBuilder<HomeData>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<HomeData> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingList();
          }

          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.wifi_off_rounded,
              title: 'No pudimos cargar los restaurantes',
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }

          final HomeData data = snapshot.data!;

          if (data.isOutsideCoverage) {
            return const _MessageState(
              icon: Icons.location_off_rounded,
              title: 'Todavia no llegamos ahi',
              message: 'Estamos empezando en Tejutla. '
                  'Pronto vamos a cubrir mas lugares.',
            );
          }

          final int total = data.restaurants.length;

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xl,
              ),
              itemCount: total + 2,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return _Header(zone: data.zone!);
                }

                if (index == 1) {
                  return _SectionTitle(count: total);
                }

                final Restaurant restaurant = data.restaurants[index - 2];

                return RestaurantCard(
                  restaurant: restaurant,
                  onTap: () => _openRestaurant(restaurant),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// El logotipo: "Toro" en color de marca y "Go" en azul marino.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: <TextSpan>[
          TextSpan(text: 'Toro', style: TextStyle(color: AppTheme.teal)),
          TextSpan(text: 'Go', style: TextStyle(color: AppTheme.navy)),
        ],
      ),
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
    );
  }
}

/// Saludo + el panel de la zona, en teal de marca.
///
/// Los paneles de color fuerte son la marca registrada de las apps de
/// delivery: dan estructura y hacen que la pantalla no se vea plana.
class _Header extends StatelessWidget {
  const _Header({required this.zone});

  final DeliveryZone zone;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '¿Que queres comer hoy?',
          style: text.headlineSmall?.copyWith(
            color: AppTheme.navy,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppTheme.teal,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.place_rounded,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Entregamos en',
                    style: text.labelLarge?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                zone.name,
                style: text.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(AppRadius.image),
                ),
                // Dos lineas y no una: "Envio $2.00 ($1.50 motorizado +
                // $0.50 servicio)" no cabe en un telefono. Una Row con todo
                // eso adentro desborda, y Flutter lo avisa con rayas
                // amarillas y negras.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Envio \$${zone.deliveryFee}',
                      style: text.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '\$${zone.courierFee} al motorizado'
                      ' + \$${zone.platformFee} de servicio',
                      style: text.labelSmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Titulo de seccion con el conteo, como en las referencias.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(
          'Cerca de ti',
          style: text.titleMedium?.copyWith(
            color: AppTheme.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Text(
          '$count restaurantes',
          style: text.bodySmall?.copyWith(color: AppTheme.teal),
        ),
      ],
    );
  }
}

/// Mientras carga: bloques grises con la FORMA del contenido que va a venir.
///
/// Es mejor que un circulo girando: la pantalla no "salta" cuando llegan
/// los datos, porque el esqueleto ya ocupaba el mismo lugar.
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: const <Widget>[
        _SkeletonBlock(width: 250, height: 30),
        SizedBox(height: AppSpacing.md),
        _SkeletonBlock(width: double.infinity, height: 150),
        SizedBox(height: AppSpacing.md),
        _SkeletonCard(),
        SizedBox(height: AppSpacing.md),
        _SkeletonCard(),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color base = colors.surfaceContainerHighest;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SkeletonBlock(
            width: double.infinity,
            height: 140,
            radius: 0,
            color: base,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _SkeletonBlock(width: 160, height: 18, color: base),
                const SizedBox(height: AppSpacing.sm),
                _SkeletonBlock(
                  width: double.infinity,
                  height: 12,
                  color: base,
                ),
                const SizedBox(height: AppSpacing.md),
                _SkeletonBlock(width: 190, height: 26, color: base),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 8,
    this.color,
  });

  final double width;
  final double height;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
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
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: const BoxDecoration(
                color: Color(0xFFE0F2F5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppTheme.teal),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(
                color: AppTheme.navy,
                fontWeight: FontWeight.w800,
              ),
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
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
