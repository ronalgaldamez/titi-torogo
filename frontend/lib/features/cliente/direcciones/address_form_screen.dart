import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../core/auth_storage.dart';
import '../../../core/location.dart';
import '../../../core/session.dart';
import '../../../core/theme.dart';
import '../../../models/address.dart';
import '../home/home_repository.dart';
import 'address_repository.dart';

/// El formulario de una direccion: sirve para CREAR y para EDITAR.
///
/// La parte interesante es la ubicacion. El cliente escribe "Casa, frente a la
/// farmacia" — palabras. El backend necesita COORDENADAS, y esas no se escriben
/// a mano: se toman del GPS, que es donde la persona esta parada en ese momento.
///
/// Y si el GPS no da una ubicacion real, esto NO DEJA GUARDAR. Ver _save: un
/// aviso no alcanza cuando el sistema, despues, responde que si.
///
/// Al cerrarse devuelve la direccion guardada, o null si no se guardo nada.
class AddressFormScreen extends StatefulWidget {
  const AddressFormScreen({this.address, super.key});

  /// null = direccion nueva.
  final Address? address;

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen>
    with WidgetsBindingObserver {
  final Session _session = Session(AuthStorage());
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _label;
  late final TextEditingController _address;
  late final TextEditingController _reference;

  /// La ubicacion que se va a guardar. Arranca en la de respaldo y se
  /// reemplaza por la del telefono.
  Place _place = LocationService.fallback;

  /// ¿Esa ubicacion cae DENTRO de la zona donde entregamos?
  ///
  /// null = todavia no se sabe: o no hay ubicacion con la que preguntar, o no
  /// se pudo preguntar.
  ///
  /// Una direccion fuera de la zona no sirve para nada — no se puede pedir ahi
  /// — asi que se avisa ANTES de guardarla, en vez de dejar que lo descubra en
  /// el checkout con el carrito ya armado.
  bool? _inZone;

  bool _locating = true;
  bool _isDefault = false;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.address != null;

  @override
  void initState() {
    super.initState();

    // Para enterarse de cuando el cliente vuelve a la app (ver
    // didChangeAppLifecycleState).
    WidgetsBinding.instance.addObserver(this);

    final Address? address = widget.address;

    _label = TextEditingController(text: address?.label ?? '');
    _address = TextEditingController(text: address?.address ?? '');
    _reference = TextEditingController(text: address?.reference ?? '');
    _isDefault = address?.isDefault ?? false;

    if (address != null) {
      // Editando: las coordenadas ya estan guardadas. No hay que pedirle nada
      // al GPS, y ademas seria peligroso: si el cliente edita el nombre de su
      // casa desde el trabajo, no queremos mover su casa al trabajo.
      _place = Place(
        latitude: address.latitude,
        longitude: address.longitude,
        isReal: true,
      );
      _locating = false;
      return;
    }

    // Al abrir NO se le pregunta el permiso al cliente: solo se mira como esta.
    // El cartel aparece cuando el toca "Actualizar ubicacion".
    _locate(ask: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _label.dispose();
    _address.dispose();
    _reference.dispose();
    super.dispose();
  }

  /// Cuando el cliente VUELVE a la app, se revisa la ubicacion otra vez.
  ///
  /// Es el caso que aparecio probando: la tarjeta dice "el permiso esta
  /// bloqueado", el cliente toca "Abrir ajustes", prende el permiso, y vuelve.
  /// Sin esto, la pantalla se queda con el estado viejo —"bloqueado"— y hay que
  /// salir y volver a entrar para que reaccione.
  ///
  /// OJO CON LA CONDICION, QUE ACA ESTABA EL BUG:
  ///
  /// Solo se revisa si el permiso quedo BLOQUEADO PARA SIEMPRE. Suena raro, pero
  /// es justo al reves de lo que parece:
  ///
  ///   - permiso negado "a secas" -> la app lo vuelve a pedir -> Android muestra
  ///     el cartel -> el cartel PAUSA la app -> al cerrarlo, la app vuelve al
  ///     frente -> se revisa otra vez -> pide otra vez... BUCLE INFINITO, y
  ///     Android termina cerrando la app.
  ///
  ///   - permiso bloqueado para siempre -> Android YA NO muestra el cartel ->
  ///     preguntar no pausa nada -> no hay bucle, y cuando el cliente vuelve de
  ///     los Ajustes con el permiso prendido, se captura la ubicacion sola.
  ///
  /// Ademas se exige que no haya una revision en curso, para no pisarse.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed &&
        !_place.isReal &&
        _place.needsSettings &&
        !_locating) {
      _locate();
    }
  }

  /// [ask] = false NO le muestra el cartel del permiso al cliente.
  ///
  /// Al ABRIR la pantalla se usa asi: solo se mira como esta. El cartel sale
  /// cuando el cliente toca "Actualizar ubicación", que es cuando lo pidio el.
  Future<void> _locate({bool ask = true}) async {
    setState(() => _locating = true);

    final Place place = await LocationService().current(ask: ask);

    if (!mounted) {
      return;
    }

    // Con ubicacion real, se pregunta si cae en la zona. Sin ubicacion no hay
    // nada que preguntar.
    bool? inZone;

    if (place.isReal) {
      inZone = await _isInsideZone(place);

      if (!mounted) {
        return;
      }
    }

    setState(() {
      _place = place;
      _inZone = inZone;
      _locating = false;
    });
  }

  /// ¿Esa ubicacion cae dentro de la zona de reparto?
  ///
  /// Se reusa la MISMA pregunta que hace el Home ("que puedo entregar DONDE
  /// ESTAS"), asi que no hay dos definiciones de "zona" que se puedan separar
  /// con el tiempo.
  ///
  /// Si no se puede preguntar (sin internet, por ejemplo) devuelve null y se
  /// deja pasar: el checkout lo vuelve a validar al confirmar, asi que una
  /// direccion mala nunca llega a convertirse en un pedido.
  Future<bool?> _isInsideZone(Place place) async {
    try {
      final HomeData data = await HomeRepository(ApiClient()).load(
        latitude: place.latitude,
        longitude: place.longitude,
      );

      return !data.isOutsideCoverage;
    } on ApiException {
      return null;
    }
  }

  String? _validateLabel(String? value) {
    final String text = (value ?? '').trim();

    if (text.isEmpty) {
      return 'Poné un nombre para reconocerla (Casa, Trabajo...).';
    }

    if (text.length > 60) {
      return 'El nombre es demasiado largo.';
    }

    return null;
  }

  String? _validateAddress(String? value) {
    final String text = (value ?? '').trim();

    if (text.isEmpty) {
      return 'Escribí la dirección.';
    }

    if (text.length > 255) {
      return 'La dirección es demasiado larga.';
    }

    return null;
  }

  String? _validateReference(String? value) {
    if ((value ?? '').length > 255) {
      return 'La referencia es demasiado larga.';
    }

    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // SIN UBICACION REAL NO SE GUARDA. Punto.
    //
    // Antes esto abria un aviso con un boton de "Guardar igual", y estaba mal.
    // El cliente que no lee el aviso guardaba una direccion con las coordenadas
    // del Mall del Sol, el backend le respondia que SI llegamos (porque el Mall
    // esta dentro de la zona), y el motorizado terminaba en otro lado mientras
    // el cliente esperaba en su casa.
    //
    // Un aviso no alcanza cuando el sistema, despues, responde que si.
    if (!_place.isReal) {
      setState(() => _error =
          'Necesitamos tu ubicación para guardar la dirección. Activá el GPS '
          'y tocá "Actualizar ubicación".');

      return;
    }

    // Aproximada tampoco. Es la misma trampa que la de arriba, pero mas
    // dificil de ver: la ubicacion SI es del telefono, asi que el sistema
    // responde que llegamos, y el motorizado sale a una cuadra que no es.
    // Con 500 metros de error, "frente a la farmacia" es otra farmacia.
    if (_place.isApproximate) {
      setState(() => _error =
          'Tu ubicación es aproximada (${_place.accuracyText} de error). '
          'Con esa precisión la dirección puede quedar en otra cuadra. Salí a '
          'un lugar abierto y tocá "Actualizar ubicación".');

      return;
    }

    // Fuera de la zona tampoco: una direccion ahi no sirve, porque no se puede
    // pedir. Mejor decirlo ahora.
    if (_inZone == false) {
      setState(() => _error =
          'Esa ubicación está fuera de la zona donde entregamos. Volvé a '
          'intentarlo cuando estés dentro.');

      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final ApiClient api = await _session.client();
      final AddressRepository repository = AddressRepository(api);

      final String reference = _reference.text.trim();
      final Address? current = widget.address;

      final Address saved = current == null
          ? await repository.create(
              label: _label.text.trim(),
              address: _address.text.trim(),
              reference: reference.isEmpty ? null : reference,
              latitude: _place.latitude,
              longitude: _place.longitude,
              isDefault: _isDefault,
            )
          : await repository.update(
              id: current.id,
              label: _label.text.trim(),
              address: _address.text.trim(),
              reference: reference.isEmpty ? null : reference,
              latitude: _place.latitude,
              longitude: _place.longitude,
              isDefault: _isDefault,
            );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Borra la direccion, con confirmacion.
  Future<void> _delete() async {
    final Address address = widget.address!;

    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('¿Borrar "${address.label}"?'),
            content: const Text(
              'Los pedidos que hiciste a esta dirección no se tocan: guardan su '
              'propia copia.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Borrar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final ApiClient api = await _session.client();
      await AddressRepository(api).delete(address.id);

      if (!mounted) {
        return;
      }

      // pop() sin nada: la que borramos ya no existe, asi que no hay direccion
      // que devolver. Quien llamo recarga la lista y listo.
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.message;
        _saving = false;
      });
    }
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
          _isEditing ? 'Editar dirección' : 'Nueva dirección',
          style: text.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        actions: <Widget>[
          if (_isEditing)
            IconButton(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppTheme.coral,
              tooltip: 'Borrar dirección',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: <Widget>[
            _Field(
              controller: _label,
              label: 'Nombre',
              hint: 'Casa',
              validator: _validateLabel,
            ),
            const SizedBox(height: AppSpacing.md),
            _Field(
              controller: _address,
              label: 'Dirección',
              hint: 'Colonia Las Flores, calle principal',
              validator: _validateAddress,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),
            _Field(
              controller: _reference,
              label: 'Referencia (opcional)',
              hint: 'Frente a la farmacia, casa de dos pisos',
              validator: _validateReference,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),
            _LocationCard(
              place: _place,
              inZone: _inZone,
              locating: _locating,
              onRefresh: _locate,
              onOpenSettings: () => LocationService().openSettings(),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              value: _isDefault,
              onChanged: _saving
                  ? null
                  : (bool value) => setState(() => _isDefault = value),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppTheme.teal,
              title: const Text('Usar como predeterminada'),
              subtitle: const Text(
                'Es la que el checkout elige sola.',
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppTheme.tealSoft,
                  borderRadius: BorderRadius.circular(AppRadius.image),
                ),
                child: Text(
                  _error!,
                  style: text.bodyMedium?.copyWith(color: AppTheme.navy),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              height: 52,
              child: FilledButton(
                // Sin ubicacion real O con una aproximada, el boton queda
                // apagado: el cliente ya ve en la tarjeta de arriba por que.
                onPressed: (_saving ||
                        !_place.isReal ||
                        _place.isApproximate ||
                        _inZone == false)
                    ? null
                    : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Guardar cambios' : 'Guardar dirección',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un campo del formulario.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.validator,
    this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.image),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Los estados en los que puede estar la ubicacion que se va a guardar.
///
/// Existe para que la tarjeta no sea una cascada de condiciones: con seis
/// casos, un encadenado de ternarios se vuelve imposible de leer y de revisar.
enum _LocationState {
  /// Todavia se le esta preguntando al telefono.
  searching,

  /// El permiso quedo negado para siempre: la unica salida son los Ajustes.
  blocked,

  /// No hubo ubicacion: GPS apagado, sin senal, o permiso negado a secas.
  missing,

  /// La dio el telefono, pero con error de cuadras.
  approximate,

  /// La dio el telefono y cae fuera de la zona donde entregamos.
  outside,

  /// La buena: real, con precision, y dentro de la zona.
  good,
}

/// La tarjeta que muestra DE DONDE van a ser las coordenadas.
///
/// Es la parte que hace honesto el formulario. Tiene CINCO estados malos, y
/// cada uno le dice al cliente algo distinto:
///
///   1. buscando             -> esperá
///   2. permiso bloqueado    -> hay que abrirlo en los Ajustes del telefono
///   3. sin ubicacion        -> activá el GPS y reintentá
///   4. ubicacion aproximada -> el GPS no llego a los satelites; el punto puede
///                              caer a varias cuadras y NO alcanza para guardar
///   5. fuera de la zona     -> acá no entregamos
///
/// Y el sexto, el bueno: ubicacion de verdad, con precision, dentro de la zona.
class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.place,
    required this.inZone,
    required this.locating,
    required this.onRefresh,
    required this.onOpenSettings,
  });

  final Place place;

  /// null = no se pudo averiguar (sin internet, por ejemplo).
  final bool? inZone;

  final bool locating;
  final VoidCallback onRefresh;
  final VoidCallback onOpenSettings;

  /// En cual de los seis estados esta la tarjeta AHORA.
  ///
  /// El orden de las preguntas ES el diseno, no un detalle. Dos casos donde el
  /// orden decide:
  ///
  ///   - bloqueado antes que "no hay ubicacion": las dos son "no hay
  ///     ubicacion", pero la bloqueada tiene una salida distinta, los Ajustes,
  ///     y es la que el cliente necesita ver.
  ///
  ///   - aproximada antes que "fuera de la zona": si el punto puede caer a
  ///     cuadras, la respuesta sobre la zona tampoco es confiable, y lo que hay
  ///     que hacer es lo mismo en los dos casos: volver a tomar la ubicacion.
  ///     Decirle "estas fuera de la zona" con un punto malo lo manda a caminar
  ///     sin motivo.
  _LocationState get _state {
    if (locating) {
      return _LocationState.searching;
    }

    if (!place.isReal) {
      return place.needsSettings
          ? _LocationState.blocked
          : _LocationState.missing;
    }

    if (place.isApproximate) {
      return _LocationState.approximate;
    }

    return inZone == false ? _LocationState.outside : _LocationState.good;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;

    final _LocationState state = _state;

    final Color background = switch (state) {
      _LocationState.good => AppTheme.tealSoft,
      _LocationState.outside => AppTheme.coral,
      _ => AppTheme.yellow,
    };

    final Color foreground = switch (state) {
      _LocationState.good => AppTheme.tealDeep,
      _LocationState.outside => Colors.white,
      _ => AppTheme.navy,
    };

    final IconData icon = switch (state) {
      _LocationState.good => Icons.my_location_rounded,
      _LocationState.approximate => Icons.gps_not_fixed_rounded,
      _LocationState.blocked => Icons.lock_outline_rounded,
      _ => Icons.location_searching_rounded,
    };

    final String title = switch (state) {
      _LocationState.searching => 'Buscando tu ubicación...',
      _LocationState.blocked => 'El permiso de ubicación está bloqueado',
      _LocationState.missing => 'No pudimos obtener tu ubicación',
      _LocationState.approximate => 'Tu ubicación es aproximada',
      _LocationState.outside => 'Estás fuera de la zona donde entregamos',
      _LocationState.good => 'Ubicación tomada de tu GPS',
    };

    final String message = switch (state) {
      _LocationState.good =>
        'La dirección va a quedar en el punto donde estás parado AHORA '
            '(${place.latitude.toStringAsFixed(5)}, '
            '${place.longitude.toStringAsFixed(5)}). Si todavía no estás en el '
            'lugar, esperá a llegar para guardarla.',
      _LocationState.approximate =>
        'El GPS no consiguió la señal de los satélites, así que el teléfono '
            'contestó con la ubicación de la antena o del wifi '
            '(${place.accuracyText} de error). Alcanza para saber en qué zona '
            'estás, pero NO para guardar la dirección: el motorizado podría '
            'terminar en otra cuadra. Salí a un lugar abierto y tocá '
            '"Actualizar ubicación".',
      _LocationState.blocked =>
        'Negaste el permiso, así que Android ya no nos deja volver a '
            'preguntarte. Abrilo a mano en los Ajustes y volvé.',
      _LocationState.outside =>
        'Esta zona todavía no la cubrimos, así que no vas a poder pedir a una '
            'dirección de acá.',
      // Mientras se busca se muestra el mismo texto que cuando no hubo
      // ubicacion: es lo que el cliente tiene que hacer igual si el GPS no
      // contesta.
      _LocationState.searching || _LocationState.missing =>
        'No podemos guardar la dirección sin tu ubicación: quedaría en '
            'un punto que no es el tuyo, y el motorizado iría a otro lado. '
            'Activá el GPS y probá de nuevo.',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: text.bodySmall?.copyWith(color: foreground),
          ),
          if (state == _LocationState.good && inZone == true) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                Icon(Icons.check_circle_rounded, size: 14, color: foreground),
                const SizedBox(width: 4),
                Text(
                  'Estás dentro de la zona de reparto.',
                  style: text.bodySmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            // Con el permiso bloqueado, "Actualizar" no sirve de nada: Android
            // ya no muestra el cartel. La unica salida son los Ajustes.
            child: state == _LocationState.blocked
                ? FilledButton(
                    onPressed: onOpenSettings,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.navy,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Abrir ajustes'),
                  )
                : TextButton(
                    onPressed: locating ? null : onRefresh,
                    child: const Text('Actualizar ubicación'),
                  ),
          ),
          if (state == _LocationState.missing)
            Text(
              'Tip: si estás bajo techo, el GPS tarda o no llega. Salí a un '
              'lugar abierto y volvé a intentar.',
              style: text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
