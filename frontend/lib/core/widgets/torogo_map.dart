import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';

/// Un punto para pintar en el mapa: donde esta alguien o algo.
class MapPoint {
  const MapPoint({
    required this.latitude,
    required this.longitude,
    required this.icon,
    required this.color,
  });

  final double latitude;
  final double longitude;

  /// El icono que va adentro del globito.
  final IconData icon;

  /// El color del globito. Cada punto tiene el suyo para distinguirlos de un
  /// vistazo: el restaurante, la casa del cliente, el motorizado.
  final Color color;

  LatLng get latLng => LatLng(latitude, longitude);
}

/// El mapa de ToroGo, con OpenStreetMap.
///
/// POR QUE OPENSTREETMAP Y NO GOOGLE MAPS
///
/// Porque Google pide una cuenta de facturacion (con tarjeta) para darte la
/// llave, y ToroGo tiene que poder funcionar sin que nadie ponga una tarjeta
/// para levantarlo. OpenStreetMap no pide cuenta, ni llave, ni cuota: se
/// dibujan los mosaicos que publica la comunidad. Y el dia que haya que
/// cambiarlo, es cambiar UNA linea (el urlTemplate).
///
/// DOS CONDICIONES QUE HAY QUE RESPETAR, Y ESTAN LAS DOS ACA:
///
///   1. La licencia pide que el credito ("© OpenStreetMap contributors") este
///      SIEMPRE a la vista. Por eso se usa un crédito visible y adaptable y no el que
///      se abre con un boton: la atribucion se muestra, no se esconde.
///   2. La politica de uso pide identificarse: va el nombre del paquete en el
///      User-Agent, para que ellos sepan quien esta pidiendo los mosaicos.
///
/// Y una nota honesta: sus servidores de mosaicos son para uso LIVIANO. Para
/// Tejutla y los primeros clientes sobra. Si algun dia hay muchisima gente,
/// se pasa a un proveedor con capa gratuita o a un servidor propio.
class TorogoMap extends StatelessWidget {
  const TorogoMap({
    required this.points,
    this.center,
    this.zoom = 15,
    this.height = 220,
    super.key,
  });

  /// Los puntos a pintar, en cualquier orden.
  final List<MapPoint> points;

  /// Donde arranca la camara. Si no se pasa, se usa el primer punto.
  final MapPoint? center;

  final double zoom;
  final double height;

  @override
  Widget build(BuildContext context) {
    final MapPoint? middle = center ?? (points.isEmpty ? null : points.first);

    // Sin ningun punto no se dibuja un mapa vacio: se avisa, que es mas util
    // que un rectangulo gris que parece un error.
    if (middle == null) {
      return _NoPoints(height: height);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: middle.latLng,
            initialZoom: zoom,
            // Se puede mover y hacer zoom, pero NO girar: un mapa de reparto
            // torcido no le sirve a nadie, y se gira sin querer con dos dedos.
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // Lo pide su politica de uso: asi saben quien pide los mosaicos.
              userAgentPackageName: 'com.ronalgaldamez.torogo',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: <Marker>[
                for (final MapPoint point in points)
                  Marker(
                    point: point.latLng,
                    width: 40,
                    height: 40,
                    child: _Pin(color: point.color, icon: point.icon),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.bottomRight,
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'flutter_map · © OpenStreetMap contributors',
                  textAlign: TextAlign.right,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El globito de un punto: circulo blanco con el icono de color adentro.
///
/// El blanco y la sombra son a proposito: sobre una foto de mapa (que tiene
/// calles claras y oscuras), un icono de color sin fondo se pierde.
class _Pin extends StatelessWidget {
  const _Pin({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

/// Lo que se muestra cuando no hay ningun punto.
class _NoPoints extends StatelessWidget {
  const _NoPoints({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.tealSoft,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Text(
        'Todavía no hay un punto para mostrar en el mapa.',
        textAlign: TextAlign.center,
        style: text.bodySmall?.copyWith(color: AppTheme.tealDeep),
      ),
    );
  }
}
