# ToroGo: borradores de Privacidad, Términos y Cookies

Preparación: 24/10/2026. **Documento de trabajo para revisión; no es una política publicada ni una fecha de entrada en vigor.** Los apartados de cancelaciones posteriores a la aceptación y solución de reclamos son propuestas operativas pendientes de confirmar con Ronald.

## Datos confirmados

- Responsable propuesto: **Francisco Ronal Galdamez Funes**, persona natural que opera con el nombre ToroGo.
- Correo de contacto y privacidad: **torogoappsv@gmail.com**.
- Ubicación general: Chalatenango, El Salvador. Falta precisar el domicilio o dirección de atención que corresponda publicar; no se presume que esta ubicación general sustituye ese dato.
- Cobertura: únicamente las zonas activas que incluyan la dirección de entrega. El mapa inicial se importa desde `backend/database/data/zonas-de-envio.kml` como zona «Tejutla». Esto no significa cobertura de todo Tejutla ni de todo Chalatenango. Las zonas vigentes pueden cambiar desde la base de datos/admin.

## Borrador de aviso de privacidad

### Quién trata tus datos y cómo contactarnos

ToroGo es operado por Francisco Ronal Galdamez Funes en Chalatenango, El Salvador. Podés escribir a **torogoappsv@gmail.com** para consultas sobre tus datos. Antes de publicar este aviso se completarán el domicilio de atención y los datos de los proveedores de infraestructura.

### Qué información se utiliza

- Cuenta: nombre, correo, contraseña protegida mediante hash, perfil y teléfono cuando lo proporcionás. No necesitás enviarnos tu contraseña por correo.
- Entrega: direcciones guardadas, referencias, coordenadas y dirección copiada en cada pedido. Editar una dirección guardada no modifica las entregas ya registradas.
- Pedidos: productos, cantidades, notas, importes, envío, propina, estados y fechas del recorrido, restaurante y motorista asignado.
- Motoristas: información de cuenta, teléfono, vehículo y ubicación durante entregas activas. El backend conserva la última posición en caché hasta dos minutos; no crea un historial GPS de recorridos. Esto no elimina el historial comercial del pedido ni garantiza que registros técnicos o respaldos se borren simultáneamente.
- Funcionamiento y seguridad: identificadores de sesión y acceso, nombre de dispositivo cuando se informa, dirección IP y datos técnicos que generen los servidores. Los campos y retención de registros se verificarán al desplegar.
- Atención: datos que envíes voluntariamente al correo de soporte sobre un pedido o una solicitud de privacidad.

### Para qué se usan

Para gestionar la cuenta, comprobar cobertura, tramitar pedidos y entregas, mostrar el seguimiento privado, atender consultas e incidentes y proteger el servicio. Antes del lanzamiento se documentará la base jurídica de cada finalidad. No se utilizará la aceptación de términos como permiso general para publicidad u otros usos ajenos a la operación.

### Quién puede acceder

El personal autorizado de ToroGo accede según sus funciones. Los restaurantes consultan los pedidos de su negocio; el motorista asignado accede a la información de entrega necesaria y el cliente puede consultar su seguimiento. La app muestra al cliente el nombre del motorista y su posición cuando corresponde. No todos los motoristas reciben la dirección completa de los pedidos disponibles.

La web solicita tipografías de Google Fonts. La app utiliza mapas de OpenStreetMap; al cargar recursos de terceros el dispositivo se conecta con sus servidores. Al escribir al correo de soporte, el mensaje se tramita mediante el proveedor de correo. Los proveedores pueden recibir datos técnicos de conexión. Antes de publicar se identificarán el alojamiento, sus ubicaciones y las transferencias internacionales y garantías que correspondan. No se declara que todo el tratamiento ocurra dentro de El Salvador.

### Conservación y seguridad

Se conservarán los datos necesarios para las finalidades informadas y las obligaciones aplicables. Antes del lanzamiento se fijarán y aplicarán plazos por categoría, incluyendo cuentas, pedidos, reclamos, registros y respaldos. La versión revisada no tiene un borrado automático general de cuentas ni una política completa de retención; no se prometerá un plazo de borrado que el sistema no cumple.

ToroGo limita el acceso por cuenta y perfil y protege las contraseñas mediante hash. La seguridad no se presenta como absoluta. El despliegue deberá configurar HTTPS, respaldos y procedimientos de respuesta a incidentes antes de atender usuarios reales.

### Tus derechos

Podés solicitar acceso, rectificación, cancelación, oposición, portabilidad, olvido o limitación, según corresponda, escribiendo al correo indicado. Identificá la cuenta y explicá tu solicitud; te orientaremos sobre los requisitos legales y la comprobación de identidad necesaria. No envíes contraseñas ni documentación innecesaria en el primer contacto. La eliminación puede estar limitada por obligaciones de conservación que deberán explicarse.

El procedimiento interno deberá permitir cumplir los plazos legales: el texto consolidado consultado prevé respuesta en veinte días hábiles, con prórroga justificada de hasta otros veinte. No se confundirá esta respuesta con la resolución inmediata de todo reclamo comercial.

## Borrador de términos de uso y pedidos

### Servicio, cobertura y cuenta

ToroGo conecta clientes, restaurantes y motoristas para tramitar pedidos dentro de las zonas habilitadas. El operador es Francisco Ronal Galdamez Funes; contacto: **torogoappsv@gmail.com**. El restaurante prepara los productos y el motorista asignado realiza la entrega. Esta descripción no excluye las responsabilidades legales que correspondan a cada participante.

La dirección de entrega debe estar dentro de una zona activa y el restaurante debe estar disponible. No se promete cobertura de todo Chalatenango. Debés proporcionar información correcta y proteger tus credenciales. Las restricciones de edad y la contratación de productos regulados se definirán antes del lanzamiento; no se habilita su venta por este documento.

### Precio, aceptación y entrega

Antes de confirmar se muestran productos, envío, propina cuando corresponda y total en dólares estadounidenses. El sistema actual opera con pago en efectivo al recibir y no procesa tarjetas. No se establecen cargos o penalizaciones nuevas mediante este borrador.

El pedido queda pendiente hasta la aceptación del restaurante. Si no lo acepta dentro de cinco minutos desde su creación, se cancela por vencimiento. La cancelación se procesa al comprobar el plazo o mediante el scheduler; su reflejo en pantalla puede depender de la conexión. Los tiempos de preparación y entrega son estimaciones, sin excluir los derechos ante incumplimientos.

### Cancelaciones e incidencias: propuesta para confirmar

1. **Antes de la aceptación:** el cliente puede cancelar desde el seguimiento. En el modelo actual, al pagarse al recibir, no hay un pago anticipado que devolver.
2. **Después de la aceptación:** el botón de cancelación deja de estar disponible. El cliente puede pedir ayuda al correo de soporte; ToroGo revisa con el restaurante el estado de preparación y las circunstancias. La limitación del botón no elimina derechos legales ni implica que toda solicitud deba rechazarse.
3. **Pedido no entregado, incompleto, equivocado o con problemas de calidad:** enviar número de pedido, descripción y, si es posible, fotografías relevantes, evitando datos innecesarios. Reportarlo cuanto antes facilita revisar el caso; no se establece un plazo de 24 horas que extinga derechos.
4. **Solución:** documentar el reclamo y coordinar una corrección, reposición o devolución del importe afectado cuando corresponda. No obligar a aceptar un cupón como única solución. Si ya hubo pago en efectivo, acordar y registrar la forma de reintegro; no existe devolución automática en la app.
5. **Contacto o dirección incorrectos, ausencia o retrasos:** intentar contactar y revisar el caso. No inventar multas, cobros por reintento ni pérdida automática de lo pagado.

No prometer atención 24/7 ni devolución en un plazo fijo hasta definir una operación capaz de cumplirlo. Estos mecanismos no restringen la posibilidad de acudir a la Defensoría del Consumidor o ejercer otros derechos aplicables.

### Estado de lanzamiento

La landing es informativa y el flujo de pedidos desde la web aún está en preparación. Estos términos no anuncian que esa funcionalidad esté disponible ni que las apps ya estén publicadas en las tiendas.

## Borrador de información sobre cookies

### Qué son y cuáles se han identificado

Las cookies son información que un sitio puede almacenar en el navegador. No son lo mismo que los permisos GPS de la app ni que su almacenamiento local.

La revisión del código y la configuración local identifica una sesión Laravel con almacenamiento en base de datos, un plazo de inactividad configurado de 120 minutos y el nombre de aplicación ToroGo. El nombre de cookie se deriva de la configuración y puede modificarse al desplegar. También debe verificarse la cookie `XSRF-TOKEN`, utilizada por Laravel para protección de formularios.

| Elemento | Finalidad prevista | Duración que debe comprobarse |
| --- | --- | --- |
| Cookie de sesión, nombre dependiente de la configuración | Mantener sesión y estado necesario del sitio/admin | Configuración local: 120 minutos de inactividad; verificar expiración y renovación reales |
| `XSRF-TOKEN`, si la respuesta la establece | Protección de solicitudes frente a falsificación | Verificar en el navegador y en la respuesta del despliegue |

No se identificaron integraciones de Google Analytics, Meta Pixel o Hotjar en el código revisado de la landing. Esto no es un inventario definitivo del entorno publicado ni prueba de ausencia de todas las cookies de terceros.

### Recursos externos y app móvil

La hoja de estilos carga Google Fonts y el navegador realiza solicitudes externas. Ese acceso no debe describirse automáticamente como una cookie publicitaria: hay que observar qué información y almacenamiento intervienen realmente.

La app guarda información de sesión, carrito e intentos de pedido en almacenamiento local mediante SharedPreferences. El seguimiento utiliza permisos de ubicación del dispositivo. Las preferencias de cookies de la web no cambian esos permisos ni eliminan esos datos.

### Preferencias

El panel actual es informativo y no registra consentimiento. Antes de habilitar analítica o publicidad se revisarán los requisitos aplicables y se implementarán las opciones necesarias, incluido el bloqueo previo de herramientas opcionales cuando corresponda. No se añadirá un botón «Aceptar todo» que simule controlar herramientas inexistentes o que ya se cargaron sin control.

Podés administrar las cookies desde el navegador; al bloquear las necesarias algunas funciones de sesión o formularios pueden dejar de funcionar. Contacto: **torogoappsv@gmail.com**.

## Pendientes concretos antes de publicar como versión definitiva

- Confirmar el procedimiento propuesto de reclamos y definir horario y responsable de atender el correo.
- Precisar domicilio comercial/de atención y demás identificación exigible sin publicar datos personales adicionales por suposición.
- Determinar alojamiento, país, proveedores, contratos y transferencias; revisar Google Fonts, OpenStreetMap y correo.
- Revisar bases de tratamiento y plazos de retención con sus procedimientos reales; contemplar la conservación legal de documentación comercial.
- Observar cookies, cabeceras y almacenamiento en el entorno final; no se inspeccionaron cookies del navegador durante esta revisión.
- Definir gestión de derechos, verificación de identidad, baja de cuenta, conservación obligatoria y reclamos. La app no tiene todavía una ruta de eliminación de cuenta en la API revisada.
- Revisar la normativa aplicable y el texto final antes del lanzamiento; no usar este borrador como certificación de cumplimiento.

## Fuentes y evidencia

- [Ley para la Protección de Datos Personales, texto consolidado de la Corte Suprema de Justicia](https://www.jurisprudencia.gob.sv/DocumentosBoveda/D/2/2020-2029/2024/11/10660E.PDF). Incluye reforma del Decreto 659 de septiembre de 2026. Referencias para revisión: derechos y procedimiento de solicitudes, arts. 7–21; condiciones de tratamiento y responsabilidades.
- [Defensoría del Consumidor: obligaciones de proveedores, incluido comercio electrónico](https://www.defensoria.gob.sv/obligaciones/). Incluye información precontractual, condiciones de entrega y supuestos de reintegro; no se sustituye por una regla de «sin devoluciones».
- Evidencia técnica: `backend/database/seeders/DeliveryZoneSeeder.php`, `backend/database/data/zonas-de-envio.kml`, `backend/app/Http/Controllers/Api/OrderController.php`, `CourierLocationController.php`, `backend/config/session.php`, `backend/routes/api.php`, `backend/public/css/landing.css`, `frontend/lib/core/widgets/torogo_map.dart` y almacenamiento local de la app.

Los datos del responsable y el correo proceden de Ronald. El inventario describe código y configuración local revisados; no confirma la zona activa ni los servicios contratados de un futuro servidor de producción.
