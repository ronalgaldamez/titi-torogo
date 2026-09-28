import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Las notificaciones del telefono. Hoy las usa solo el RESTAURANTE.
///
/// PARA QUE SIRVE
///
/// El tiempo real ya hace que la lista de pedidos se actualice sola, pero eso
/// sirve solo si alguien esta MIRANDO la pantalla. En una cocina el telefono
/// esta apoyado en el mostrador, asi que un pedido nuevo tiene que SONAR.
///
/// POR QUE UNA NOTIFICACION Y NO UN SONIDO CUALQUIERA
///
/// Porque en Android el sonido fuerte, la vibracion y el cartel que aparece
/// arriba (el "heads-up") son cosas del SISTEMA de notificaciones, no de la
/// app: solo se consiguen con un CANAL de importancia maxima. Y ademas es el
/// mismo camino que va a usar FCM el dia que queramos avisar con la app cerrada
/// (ver AGENDS: "Notificaciones: Firebase Cloud Messaging (FCM)").
///
/// OJO CON EL CANAL, QUE ES LA TRAMPA CLASICA
///
/// Android guarda el sonido, la vibracion y la importancia del canal CUANDO SE
/// CREA, y despues no los deja cambiar. Si algun dia se cambia el archivo del
/// sonido, hay que crear un canal con OTRO id (o borrar los datos de la app en
/// el telefono): si no, va a seguir sonando el viejo y parece que el cambio no
/// funciono.
class Notifications {
  Notifications._();

  static final Notifications instance = Notifications._();

  /// El id del canal. Cambiar esto es lo que "refresca" el sonido y la
  /// vibracion (ver arriba). Por eso lleva version al final.
  static const String _channelId = 'torogo_pedidos_v1';

  /// El nombre del canal, tal como lo ve el dueno del telefono en los Ajustes.
  static const String _channelName = 'Pedidos nuevos';

  static const String _channelDescription =
      'Avisa cuando entra un pedido en ToroGo.';

  /// El archivo del sonido en android/app/src/main/res/raw, SIN la extension.
  ///
  /// Ese archivo NO esta versionado a proposito (el motivo esta en
  /// design/sonidos/LICENCIA.txt).
  /// Si falta en tu copia, la notificacion igual sale: suena con el sonido por
  /// defecto del telefono.
  static const String _sound = 'restaurante';

  /// El patron de vibracion: espera, vibra, pausa, vibra... en milisegundos.
  ///
  /// Tres golpes y no uno: en una cocina, un zumbido corto se pierde entre el
  /// ruido y no se siente en el bolsillo del delantal.
  ///
  /// No puede ser `const` porque Int64List.fromList es una fabrica.
  static final Int64List _vibration = Int64List.fromList(<int>[
    0,
    500,
    250,
    500,
    250,
    700,
  ]);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Si ya se inicializo el plugin y se creo el canal.
  bool _ready = false;

  /// Deja todo listo: plugin inicializado, canal creado y permiso pedido.
  ///
  /// Devuelve true si al final hay permiso para notificar.
  ///
  /// Se llama la primera vez que el restaurante abre sus pedidos. En Android 13
  /// en adelante eso hace aparecer el cartel de "Permitir notificaciones", que
  /// hay que aceptar: si se niega, no suena NADA y no hay ningun error que lo
  /// explique.
  Future<bool> ensureReady() async {
    if (!_ready) {
      _ready = true;

      await _plugin.initialize(
        settings: const InitializationSettings(
          // El icono chico de la barra de estado. Se usa el de la app; Android
          // lo recorta a una silueta blanca, asi que se ve como un cuadrado si
          // el icono tiene fondo, pero se distingue de las otras apps.
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      await _android?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(_sound),
          enableVibration: true,
          vibrationPattern: _vibration,
          // USAGE_ALARM: el sonido sale por el volumen de ALARMAS y no por el
          // notificaciones. Es a proposito: el telefono esta en el mostrador de
          // una cocina y tiene que oirse por encima del ruido.
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
    }

    // El permiso se pide cada vez que se llama (no solo la primera): el
    // restaurante pudo haberlo negado antes, y en Android 12 y anteriores esto
    // no muestra ningun cartel (no hace falta permiso).
    return await _android?.requestNotificationsPermission() ?? true;
  }

  /// Avisa que entro un pedido NUEVO.
  ///
  /// [orderId] se usa como id de la notificacion: si el mismo pedido avisara
  /// dos veces, la segunda REEMPLAZA el cartel en vez de apilar otro.
  Future<void> newOrder({
    required int orderId,
    required int units,
    required String total,
  }) async {
    // En el navegador no se hace nada: ahi no hay canal de notificacion ni
    // sonido propio, y la app del restaurante vive en el telefono. Esto evita
    // que probando en web salte un error por algo que no aplica.
    if (!_isAndroid) {
      return;
    }

    if (!await ensureReady()) {
      // Sin permiso no hay nada que hacer. Se deja escrito en la consola
      // porque, si no, el sintoma es "no suena" y no hay por donde empezar.
      debugPrint('Notificaciones: no hay permiso para avisar del pedido.');

      return;
    }

    await _plugin.show(
      id: orderId,
      title: 'Pedido nuevo #$orderId',
      body: units == 1 ? '1 plato · \$$total' : '$units platos · \$$total',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          // Priority es para Android 7 y anteriores, que no tienen canales:
          // sin esto, el aviso no sale como cartel arriba.
          priority: Priority.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(_sound),
          enableVibration: true,
          vibrationPattern: _vibration,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          ticker: 'Pedido nuevo',
          // Abrir la app al tocar el cartel es lo que hace Android solo; el
          // payload queda por si mas adelante queremos llevarlo al pedido.
        ),
      ),
      payload: '$orderId',
    );
  }

  /// ¿La app corre en Android?
  ///
  /// El canal, el sonido propio y el permiso son cosas de Android. En web y en
  /// escritorio este archivo no hace nada.
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// El plugin de Android, o null si la app corre en otra plataforma (el
  /// navegador, por ejemplo). Asi esto no rompe cuando se prueba en web.
  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
}
