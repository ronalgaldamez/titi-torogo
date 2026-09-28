import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Las notificaciones del telefono: las del RESTAURANTE y las del MOTORIZADO.
///
/// PARA QUE SIRVEN
///
/// El tiempo real ya hace que las listas se actualicen solas, pero eso sirve
/// solo si alguien esta MIRANDO la pantalla. En una cocina —y arriba de una
/// moto— el telefono esta guardado, asi que los avisos tienen que SONAR.
///
/// POR QUE NOTIFICACIONES Y NO UN SONIDO CUALQUIERA
///
/// Porque en Android el sonido fuerte, la vibracion y el cartel que aparece
/// arriba (el "heads-up") son cosas del SISTEMA de notificaciones, no de la
/// app: solo se consiguen con un CANAL de importancia maxima. Y es el mismo
/// camino que va a usar FCM el dia que queramos avisar con la app cerrada (ver
/// AGENDS: "Notificaciones: Firebase Cloud Messaging (FCM)").
///
/// OJO CON LOS CANALES, QUE ES LA TRAMPA CLASICA
///
/// Android guarda el sonido, la vibracion y la importancia de un canal CUANDO
/// CREA, y despues no los deja cambiar. Si algun dia se cambia el archivo del
/// sonido, hay que crear un canal con OTRO id (o borrar los datos de la app en
/// el telefono): si no, sigue sonando el viejo y parece que el cambio no
/// funciono. Por eso los ids llevan version al final.
class Notifications {
  Notifications._();

  static final Notifications instance = Notifications._();

  /// El canal del RESTAURANTE: entro un pedido nuevo.
  static const _Channel _restaurant = _Channel(
    'torogo_pedidos_v1',
    'Pedidos nuevos',
    'Avisa cuando entra un pedido en ToroGo.',
  );

  /// El canal del MOTORIZADO: hay un pedido para recoger.
  ///
  /// Va aparte del del restaurante a proposito: son dos publicos distintos, y
  /// asi cada uno puede silenciar el suyo sin tocar el del otro (Android los
  /// muestra separados en los Ajustes del telefono).
  static const _Channel _courier = _Channel(
    'torogo_motorizado_v1',
    'Pedidos disponibles',
    'Avisa cuando hay un pedido para recoger cerca tuyo.',
  );

  /// El archivo del sonido en android/app/src/main/res/raw, SIN la extension.
  ///
  /// Ese archivo NO esta versionado a proposito (el motivo esta en
  /// design/sonidos/LICENCIA.txt). Si falta en tu copia, la notificacion igual
  /// sale: suena con el sonido por defecto del telefono.
  ///
  /// Los dos canales usan el MISMO archivo. Si algun dia queremos que el
  /// motorizado suene distinto al restaurante, se agrega otro archivo y se
  /// cambia el canal del motorizado (con id nuevo, por lo del cache de arriba).
  static const String _sound = 'restaurante';

  /// El patron de vibracion: espera, vibra, pausa, vibra... en milisegundos.
  ///
  /// Tres golpes y no uno: en una cocina —o con el telefono en el bolsillo
  /// mientras se maneja— un zumbido corto se pierde.
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

  /// Si ya se inicializo el plugin y se crearon los canales.
  bool _ready = false;

  /// Deja todo listo: plugin inicializado, los dos canales creados y el permiso
  /// pedido.
  ///
  /// Devuelve true si al final hay permiso para notificar.
  ///
  /// Se llama la primera vez que el restaurante —o el motorizado— entra a su
  /// pantalla de pedidos. En Android 13 en adelante eso hace aparecer el cartel
  /// de "Permitir notificaciones", que hay que aceptar: si se niega, no suena
  /// NADA y no hay ningun error que lo explique.
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

      // Los dos canales se crean de una, aunque el telefono sea de un cliente
      // que no es ninguno de los dos: crear un canal no molesta a nadie, y asi
      // no hay que acordarse de crearlo en cada pantalla.
      for (final _Channel channel in <_Channel>[_restaurant, _courier]) {
        await _android?.createNotificationChannel(channel.toAndroid());
      }
    }

    // El permiso se pide cada vez que se llama (no solo la primera): el usuario
    // pudo haberlo negado antes, y en Android 12 y anteriores esto no muestra
    // ningun cartel (no hace falta permiso).
    return await _android?.requestNotificationsPermission() ?? true;
  }

  /// Avisa que entro un pedido NUEVO. Lo usa el restaurante.
  ///
  /// [orderId] se usa como id de la notificacion: si el mismo pedido avisara
  /// dos veces, la segunda REEMPLAZA el cartel en vez de apilar otro.
  Future<void> newOrder({
    required int orderId,
    required int units,
    required String total,
  }) {
    return _notify(
      channel: _restaurant,
      id: orderId,
      title: 'Pedido nuevo #$orderId',
      body: units == 1 ? '1 plato · \$$total' : '$units platos · \$$total',
    );
  }

  /// Avisa que hay un pedido DISPONIBLE para recoger. Lo usa el motorizado.
  ///
  /// [detail] es la linea de abajo del cartel: distancia, restaurante y monto.
  Future<void> availableOrder({
    required int orderId,
    required String detail,
  }) {
    return _notify(
      channel: _courier,
      id: orderId,
      title: 'Pedido disponible #$orderId',
      body: detail,
    );
  }

  /// El comun de las dos: revisar que se pueda, armar el cartel y mostrarlo.
  Future<void> _notify({
    required _Channel channel,
    required int id,
    required String title,
    required String body,
  }) async {
    // En el navegador no se hace nada: ahi no hay canal de notificacion ni
    // sonido propio, y estas dos apps viven en el telefono. Esto evita que
    // probando en web salte un error por algo que no aplica.
    if (!_isAndroid) {
      return;
    }

    if (!await ensureReady()) {
      // Sin permiso no hay nada que hacer. Se deja escrito en la consola
      // porque, si no, el sintoma es "no suena" y no hay por donde empezar.
      debugPrint('Notificaciones: no hay permiso para avisar (${channel.id}).');

      return;
    }

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          // Priority es para Android 7 y anteriores, que no tienen canales:
          // sin esto, el aviso no sale como cartel arriba.
          priority: Priority.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(_sound),
          enableVibration: true,
          vibrationPattern: _vibration,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          ticker: title,
        ),
      ),
      payload: '$id',
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

/// Un canal de notificacion de Android: su id, su nombre y su descripcion.
///
/// Existe para no repetir los mismos siete parametros en los dos lugares donde
/// se arma un canal (la creacion y el cartel), que es justo donde se
/// desincronizan las cosas.
class _Channel {
  const _Channel(this.id, this.name, this.description);

  final String id;
  final String name;
  final String description;

  /// El canal tal como lo pide Android, con el sonido y la vibracion puestos.
  AndroidNotificationChannel toAndroid() {
    return AndroidNotificationChannel(
      id,
      name,
      description: description,
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound(Notifications._sound),
      enableVibration: true,
      vibrationPattern: Notifications._vibration,
      // USAGE_ALARM: el sonido sale por el volumen de ALARMAS y no por el de
      // notificaciones. Es a proposito: el telefono esta en el mostrador de una
      // cocina, o en el bolsillo de alguien que va manejando, y tiene que oirse
      // por encima del ruido.
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
  }
}
