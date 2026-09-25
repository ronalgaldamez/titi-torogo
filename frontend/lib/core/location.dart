import 'package:geolocator/geolocator.dart';

/// Donde esta una persona, con una marca de si es de verdad.
///
/// La marca importa: si el cliente no dio permiso, la app sigue andando con una
/// ubicacion de respaldo, pero la pantalla tiene que PODER decir que esta
/// mostrando otra cosa. Sin esa marca, la app mentiria sin darse cuenta.
class Place {
  const Place({
    required this.latitude,
    required this.longitude,
    required this.isReal,
  });

  final double latitude;
  final double longitude;

  /// true = la dijo el telefono. false = es la de respaldo.
  final bool isReal;
}

/// La ubicacion del telefono.
///
/// Se usa en el Home del cliente y en la app del motorizado: las dos necesitan
/// saber DONDE ESTA la persona para poder preguntarle al backend que hay cerca.
class LocationService {
  /// Ubicacion de respaldo: Mall del Sol, Tejutla.
  ///
  /// Esta DENTRO de la zona de reparto a proposito. Si el cliente no da
  /// permiso de ubicacion, la app tiene que seguir siendo usable: mostrando los
  /// restaurantes de Tejutla con un aviso, en vez de una pantalla vacia o un
  /// error.
  static const Place fallback = Place(
    latitude: 14.101203787387021,
    longitude: -89.15061654556241,
    isReal: false,
  );

  /// Pide la ubicacion, con el permiso y todo.
  ///
  /// NUNCA lanza. Devuelve [fallback] si el permiso esta negado, si el GPS esta
  /// apagado, si tarda demasiado, o si el navegador no la da.
  ///
  /// Es a proposito: una app de delivery que no abre porque no consiguio el GPS
  /// es peor que una que muestra la zona de siempre y lo avisa.
  Future<Place> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return fallback;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      // Solo se pide si todavia no dijo nada. Si ya dijo que no, volver a
      // preguntar en cada carga es molesto y algunos navegadores lo bloquean.
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return fallback;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // Sin limite de tiempo, en un lugar con mala senal la pantalla se
          // queda esperando para siempre.
          timeLimit: Duration(seconds: 10),
        ),
      );

      return Place(
        latitude: position.latitude,
        longitude: position.longitude,
        isReal: true,
      );
    } catch (_) {
      // GPS apagado, permiso negado, tiempo agotado, o el navegador dijo que
      // no: en cualquiera de esos casos se sigue con la de respaldo.
      return fallback;
    }
  }
}
