# Pendientes de Toro Go

Esta lista organiza trabajo por revisar y acordar. No autoriza implementar funcionalidades ni modificar reglas de negocio automáticamente.

Actualizada el 14/11/2026. Las casillas distinguen implementación completada de verificaciones todavía pendientes; las validaciones de producción se registran aparte de las locales.

## Orden de trabajo acordado — 13/11/2026

1. [x] Validar disponibilidad en local: Ronald confirmó un pedido nuevo completo con cliente y motorista en dos sesiones, rutas correctas al restaurante y al cliente, y entrega final. La conservación del carrito al rechazar por falta de motorista tiene cobertura automática. La validación integral contra producción sigue pendiente.
2. [x] Comprobar manualmente una entrega a la vez: Ronald confirmó «Una entrega a la vez» en la app, rechazo desde el administrador y posibilidad de tomar el segundo pedido después de entregar el primero.
3. [x] Subir y fusionar `titi/feature/disponibilidad-motorizados`. Ronald confirmó local limpio y sincronizado con `origin/main`; el VPS llegó a `cb7b23d`, con cachés regeneradas, cinco servicios activos y HTTP 200. La corrección de coordenadas de la prueba local no se traslada a producción.
4. [ ] Preparar los respaldos del VPS y comprobar una restauración aislada, con el alcance y costos acordados en la sección de respaldos.
5. [ ] Continuar con el PIN de recogida según el alcance registrado abajo.

Verificaciones de la etapa de disponibilidad: 20 pruebas seleccionadas de Flutter, 78 pruebas del backend (876 verificaciones) y tres pruebas concurrentes en PostgreSQL (36 verificaciones) aprobadas; análisis de navegación sin problemas. Ronald completó después las pruebas manuales locales anteriores. No equivalen a una validación del recorrido contra producción.

## Propuestas por acordar: disponibilidad de motoristas, PIN y efectivo

Registradas el 07/11/2026 a solicitud de Ronald. Antes de implementar, revisar lo existente y acordar las reglas; esta sección no autoriza cambios automáticos en producción.

- [ ] Validar el bloqueo por falta de motoristas, implementado en `titi/feature/disponibilidad-motorizados` el 08/11/2026: cuenta activa y disponible, ubicación real y precisa reciente (menos de dos minutos), hasta 5 km del restaurante y sin pedidos activos asignados. El servidor rechaza pedidos nuevos con un aviso, conserva el carrito y permite recuperar pedidos ya creados. La presencia usa caché privada y el GPS existente; no reserva ni asigna automáticamente. Probar backend, Flutter y dos sesiones antes de marcar como terminado.
- [ ] Validar una entrega por motorista: bloqueo en toma y asignación administrativa bajo bloqueo de fila del usuario; pedidos históricos conservados. Al terminar, cancelar o liberar la entrega puede recibir otra. Si permanece disponible, el GPS sigue publicando presencia; al desactivarse sin entregas se detiene.
- [ ] Definir qué ocurre si un pedido ya aceptado no consigue motorista: acordar plazo, avisos al cliente y restaurante, intervención del administrador y condiciones de cancelación. No fijar tiempos ni cancelar pedidos existentes automáticamente.
- [ ] Incorporar PIN de recogida: el restaurante muestra un código por pedido y el motorista asignado lo ingresa al recibir la comida, antes de marcarla como recogida. Validar en el servidor y limitar intentos; no permitir que otros motoristas accedan al código o confirmen la recogida.
- [ ] Evaluar un PIN distinto para la entrega: lo conserva el cliente y el motorista asignado lo ingresa para confirmar. Acordar el procedimiento cuando el cliente no pueda proporcionarlo y registrar cualquier intervención autorizada.
- [ ] Definir liquidaciones de efectivo: registrar cuánto cobró el motorista, cuánto corresponde al restaurante, a ToroGo y al propio motorista, lo entregado y el saldo pendiente. Conservar el desglose original de cada pedido y evitar registros duplicados. El PIN acredita pasos del pedido, no demuestra que se haya liquidado el dinero.

Seguir el orden de trabajo acordado arriba: validar disponibilidad y una entrega por motorista, publicar los cambios, preparar respaldos y continuar con el PIN de recogida. Las liquidaciones y el alcance del PIN de entrega siguen por acordar.

## Prioridad: respaldos de producción desde el administrador

Pendiente prioritario acordado con Ronald el 01/11/2026. El 14/11/2026 autorizó continuar: una copia diaria a las 03:00 de El Salvador y retención de 30 días. Creó el bucket privado `torogo-backups` en Ohio, con versiones habilitadas, y el usuario `torogo-backups-vps` con la política `ToroGoBackupsVps`, limitada al prefijo `backups/`. Ronald confirmó guardar las variables `BACKUP_AWS_*` en el `.env` del VPS, separadas de las imágenes; las claves no se copiaron al repositorio.

Desarrollo local en `titi/feature/respaldos-vps`: panel manual/programado, historial, avisos de fallo, descarga privada, PostgreSQL custom y archivos locales, comprobación SHA-256 y exclusión de ejecuciones simultáneas. La programación comienza desactivada. Ver `backend/BACKUPS.md` para alcance, pruebas, despliegue y restauración aislada. El VPS reportó PostgreSQL/pg_dump 18.6, base de 9246 kB, 1,8 MB de archivos públicos y 34 GB libres. La estimación inicial de almacenamiento fue del orden de centavos al mes para el tamaño actual; solicitudes, versiones antiguas, transferencias y crecimiento pueden agregar costo.

Antes de activar producción: configurar el ciclo de vida de objetos y versiones en S3, exigir TLS, desplegar y generar una copia real, descargarla y verificar restauración aislada. La prueba automática local usa pg_dump/pg_restore reales con bases sintéticas y S3 simulado; no sustituye esa verificación contra el bucket real. Siguen pendientes la protección aparte de secretos y de `torogo-images` y las alertas fuera del panel.

Validación local del 14/11/2026: suite backend con 88 pruebas aprobadas y 1007 verificaciones; cuatro pruebas de integración omitidas en SQLite. La prueba específica de restauración PostgreSQL se ejecutó aparte y aprobó con 13 verificaciones, usando dos bases temporales eliminadas al finalizar. Formato PHP y revisión de diferencias aprobados. No se ejecutó una copia contra el S3 real ni se desplegó esta rama en el VPS.

- [ ] Permitir al administrador generar un respaldo manual con «Respaldar ahora».
- [ ] Programar respaldos automáticos desde el panel, con hora de El Salvador; el servidor debe ejecutarlos aunque el administrador esté desconectado.
- [ ] Guardar los respaldos de PostgreSQL en un bucket privado de Amazon S3 separado de las imágenes, con permisos mínimos y credenciales fuera del código y de la interfaz.
- [ ] Incluir los archivos locales necesarios (imágenes de Página web y categorías) y acordar la protección de las imágenes que ya están en S3. Proteger la configuración y los secretos en una copia segura aparte.
- [ ] Mostrar historial, última copia correcta y errores; avisar cuando un respaldo falle.
- [ ] Acordar frecuencia, retención, costos de S3 y recuperación antes de implementar. Evitar ejecuciones simultáneas y proteger los respaldos durante generación, transferencia y almacenamiento.
- [ ] Restringir las operaciones al administrador y probar la restauración en un entorno aislado antes de dar el sistema por terminado. No restaurar ni sobrescribir producción automáticamente.

## Prioridad: completar configuración y validación del servidor

Pendientes prioritarios acordados con Ronald el 01/11/2026, además de los respaldos detallados arriba. Solo registrar y planificar; no autoriza implementar ni modificar el VPS automáticamente.

- [ ] Configurar y probar correo de producción. Confirmar que Mailpit y los valores de desarrollo fueron sustituidos; evaluar costos antes de elegir un proveedor y mantener las credenciales privadas.
- [ ] Configurar alertas por caída de la web y servicios, errores y espacio en disco; revisar actualizaciones de seguridad y mantenimiento del VPS, con opciones y costos acordados.
- [ ] Completar la protección del origen del administrador: validar el token de Cloudflare Access en el servidor o usar un túnel con validación de Access. El firewall restringe los puertos web a las IP de Cloudflare, pero eso no verifica por sí solo la identidad ni la aplicación de Access. Comprobar que no se pueda evadir por IP, otros hosts o rutas y conservar SSH y el acceso público a la API.
- [ ] Documentar la configuración y el procedimiento de despliegue y recuperación, incluida la recarga o reinicio de procesos persistentes al actualizar. Conservar en el repositorio la actualización de dependencias realizada en el VPS, sin subir secretos ni archivos de producción.
- [ ] Probar Flutter contra producción: API HTTPS, WebSockets seguros, imágenes de restaurantes en S3, registro e inicio de sesión, notificaciones, pedido completo, aceptación, asignación, seguimiento GPS, entrega y vencimiento; verificar aislamiento entre cuentas y canales privados. Las pruebas locales previas no sustituyen esta validación.
- [ ] Revisar la seguridad final antes de abrir a clientes. No considerar terminada la puesta en producción solo porque la web, el panel y los servicios responden.

## Prioridades de la app acordadas con Ronald

El diseño del perfil del restaurante que ve el cliente está completado y confirmado por Ronald. Sigue pendiente la prueba de desconexión y recuperación del GPS.

1. [x] Aplicar el diseño aprobado del perfil del restaurante que ve el cliente:
   - [x] Portada y datos del restaurante.
   - [x] Categorías del menú.
   - [x] Productos en dos columnas.
   - [x] Detalle del producto y agregar al carrito, conservando el flujo de compra existente.
2. [ ] Probar pérdida de conexión y recuperación del GPS durante una entrega: distinguir ubicación reciente de posición antigua, recuperar el seguimiento al volver la conexión y comprobar que se detiene al finalizar. No dar esta prueba por aprobada con las verificaciones anteriores.

Validaciones manuales ya confirmadas por Ronald: pedido hasta entrega, GPS con pantalla bloqueada durante tres minutos, reasignación con pérdida de acceso del motorista anterior, visualización de la ubicación del nuevo motorista y detención del GPS al entregar. Estas confirmaciones no sustituyen la prueba pendiente de desconexión.

## Cliente: revisar y completar

- [x] Perfil del cliente: edición de nombre y teléfono, avatar y rediseño editorial completados; fusionado en main mediante el PR #71 desde `titi/design/cliente-perfil`. Ronald confirmó el funcionamiento y reportó análisis sin problemas y 8 pruebas aprobadas de perfil del cliente, motorizado y navegación. Correo de solo lectura y teléfono opcional de El Salvador; se conserva el diseño del motorizado. La validación integral contra producción sigue pendiente en la sección del servidor.
- [ ] Cancelaciones: implementadas en `titi/feature/cliente-cancelar-pedido`, pendientes de pruebas. El cliente solo puede cancelar pedidos propios pendientes, antes de la aceptación; confirmación en seguimiento, motivo en historial y aviso de que no debe pagar. El servidor bloquea la fila para coordinar con aceptación y vencimiento, conserva montos y permite reintentos sin repetir eventos. No se cancelan pedidos antiguos en lote.
- [ ] Probar el recorrido completo: pedido normal, rechazo del restaurante, pérdida de conexión, recuperación sin duplicados y entrega final.
- [ ] Seguimiento GPS: verificar la ubicación real del motorista que recibe y muestra el cliente, diferenciándola de las actualizaciones del estado del pedido.
  - Implementado en `titi/feature/seguimiento-gps`, pendiente de ejecutar pruebas y validar dos sesiones/dispositivos: captura Android con notificación durante entregas propias, consulta privada del cliente cada 10 segundos, precisión y caducidad visibles. Solo se conserva la última posición en caché por dos minutos; no se publica en canales compartidos. Ver `backend/COURIER_GPS.md` para permisos y pruebas con pantalla bloqueada, desconexión y reasignación.
- [ ] Estados y permisos: revisar carga, pantallas vacías, errores recuperables y acceso únicamente a los pedidos de la propia cuenta.

Antes de implementar, revisar el código para distinguir funcionalidades faltantes de las que solo necesitan validación.

## Categorías dinámicas administradas desde el panel

Implementadas y fusionadas en `main` desde `titi/feature/categorias-dinamicas`: catálogo global del administrador, selección múltiple desde Mi local y filtros del inicio del cliente. Las cinco opciones anteriores se crean como catálogo inicial; cada restaurante elige sus categorías, sin asignaciones automáticas por nombre. El cliente obtiene cambios al actualizar el inicio y el restaurante al abrir su selector. Ronald confirmó que pudo agregar «Cuca» desde el administrador.

Iconos: se conserva la presentación con icono y nombre debajo. El administrador puede subir PNG/JPG/WebP opcional (hasta 2 MB y 1024 × 1024), conservarlo al editar o quitarlo. Sin imagen, o si falla al cargar, se utiliza un icono predeterminado. Los archivos se guardan en el disco público local y se sirven mediante la API para que funcionen en el emulador sin configurar enlaces de almacenamiento.

- [x] Reemplazar las opciones fijas del inicio del cliente por categorías administrables y filtros funcionales.
- [x] Permitir al administrador crear, editar, ordenar y desactivar categorías.
- [x] Permitir que Ronald agregue desde el administrador las categorías que le soliciten los restaurantes. No se creó un flujo de solicitudes dentro de la app.
- [x] Cargar las opciones activas en Mi local y permitir seleccionar varias categorías por restaurante.
- [x] Separar las categorías globales de tipos de comida de las categorías internas del menú.
- [x] Recuperar la presentación con iconos y reducir la separación entre opciones.
- [x] Implementar imágenes opcionales administrables e iconos predeterminados cuando no haya imagen o falle su carga.
- [ ] Confirmar las pruebas de backend y Flutter después de incorporar los iconos personalizados; las 41 pruebas de Flutter reportadas como aprobadas fueron anteriores a ese ajuste.
- [ ] Probar en el entorno local subir, reemplazar y quitar una imagen, y verificar su visualización en el emulador.
- [ ] Verificar manualmente selección en Mi local, filtrado del cliente y ocultación de una categoría desactivada.

## Pedidos que el restaurante no acepta

Problema original: existían pedidos de prueba que seguían pendientes durante días porque el restaurante no los aceptó. Los pedidos anteriores se conservan sin vencimiento y siguen sujetos a una decisión aparte.

- [x] Revisar e implementar el vencimiento; fusionado desde `titi/feature/vencimiento-pedidos`.
- [x] Acordar e implementar 5 minutos para aceptar pedidos nuevos, contados desde su creación. Los reintentos no extienden el plazo.
- [x] Proteger la aceptación al llegar al límite con bloqueo de fila y cancelación confirmada en la misma transacción.
- [x] Ejecutar la migración y levantar el scheduler, que revisa los vencimientos cada 10 segundos.
- [x] Mostrar fecha límite y motivo de cancelación al cliente y al restaurante, conservando el historial.
- [x] Actualizar Mis pedidos del cliente automáticamente cada 15 segundos mientras hay pedidos activos y la pantalla está visible en primer plano.
- [x] Implementar el aviso de que no hay que pagar para pedidos cancelados o rechazados en efectivo.
- [ ] Evaluar que el tiempo de espera sea configurable desde el administrador.
- [x] Mantener el desglose original, registrar la cancelación sin marcar entrega y verificar que el vencimiento no modifica los montos.
- [ ] Acordar cómo tratar los pedidos antiguos de prueba antes de actualizar datos. No borrar ni cancelar pedidos existentes automáticamente por crear esta lista.
- [x] Aprobar las pruebas de backend del vencimiento: límite exacto, aceptación previa, pedidos antiguos, aislamiento entre cuentas y ausencia de eventos duplicados. Ronald reportó 33 pruebas aprobadas y 300 verificaciones en esa etapa.
- [x] Comprobar en la app un pedido cancelado con el motivo «El restaurante no respondió a tiempo».

## Web pública de ToroGo

- [ ] Validar la landing implementada en `titi/feature/web-landing`: diseño público en `/`, textos y dos imágenes editables desde `/admin/pagina-web`, acceso exclusivo de administrador, validación y pruebas de persistencia y archivos. Requiere ejecutar la migración nueva; no es necesario reiniciar ni sembrar la base.
- [ ] Conectar `/pedir` al catálogo, autenticación, carrito y pedidos existentes. Por ahora la ruta muestra un aviso explícito de que los pedidos web están en preparación; no simula compras reales.
- [ ] Validar correo de contacto configurado en el administrador para negocios y motoristas. Esta etapa abre el correo del visitante, no crea solicitudes ni envía mensajes automáticamente.

## Restaurante: siguiente revisión

- [x] Rediseño de Mi local completado y aprobado por Ronald: fondo azul oscuro, encabezado editorial, dirección, categorías, disponibilidad y preparación; se conservan los controles y validaciones.
- [ ] Validar carga de logo/portada y el nuevo editor de platos con S3 privado (una foto, reemplazo y conservación al fallar). Organizar por `negocios/{nombre-inicial-normalizado}-{id}/logo/`, `portada/` y `platos/{producto-id}/`, con nombres únicos para los archivos. Guardar las rutas; conservar el prefijo al renombrar el negocio. No mezclar archivos entre negocios ni perder imágenes al ejecutar seeders.
- [x] Conectar Laravel al bucket `torogo-images` (Ohio): Ronald confirmó escritura y lectura de prueba y ejecutó la eliminación del archivo de prueba. Las credenciales permanecen en `.env`.

- [ ] Validar en emulador carga y reemplazo de logo y portada desde Mi local (PNG/JPG/WebP, 5 MB), persistencia al volver a abrir y visualización en el cliente. Implementado con S3 privado y URLs firmadas de una hora; actualizar la pantalla renueva las URLs.

- [x] Revisar y mejorar Pedidos y Mi menú del restaurante.
- [x] Mostrar propuestas y aplicar los diseños aprobados para Pedidos, Mi menú, Mi local e Historial.
- [x] Mejorar Mi local y configurar preparación entre 10 y 45 minutos.
- [x] Implementar y probar el historial del restaurante: filtros por estado y período, paginación, detalle y aislamiento entre cuentas. Ronald aprobó el diseño y reportó las pruebas correspondientes como aprobadas antes del merge.

## Estimación de entrega completa

- [ ] El tiempo mostrado actualmente proviene de preparación del local. Incorporar recorrido y disponibilidad del motorista al estimar la entrega completa, sin sumar tiempos dos veces.
- [ ] El aumento de Muy ocupado se mantiene en 50%, con un techo de 45 minutos de preparación; evaluar más adelante su configuración desde el administrador.

## Etapa posterior

- [ ] Pagos con tarjeta.
- [ ] Chat vinculado a pedidos con permisos y privacidad.
- [ ] Favoritos: permitir guardar y quitar restaurantes por cuenta, conservar la selección y mostrar la lista de favoritos. El corazón del cierre del menú solo anuncia «Favoritos · Próximamente»; todavía no guarda favoritos.
- [ ] Reseñas.

La prioridad sigue siendo terminar y validar el delivery de comida. Mantener la paleta, tipografía y tema actuales; discutir nuevas dependencias, cambios de backend y decisiones arquitectónicas antes de implementarlos.

- [ ] Validar ofertas de platos: programar en hora de El Salvador, activar/desactivar, comprobar precio del cliente y rechazo de una oferta vencida en el carrito; verificar que pedidos anteriores y reintentos mantengan sus importes.

## Rediseño del administrador

Implementado en `codex/rediseno-admin`: acceso y tablero renovados con datos reales, logo oficial, menú lateral con sección activa también al crear o editar, fondos Original/Negro/Blanco recordados en el navegador, menú móvil y tablas como fichas. Las pantallas existentes conservan rutas, campos, archivos y validaciones. Las acciones de escritura piden confirmación (excepto iniciar sesión); los botones se bloquean mientras se envía y se recuperan al volver con Atrás. El bloqueo de doble clic corresponde al formulario abierto; no agrega idempotencia global entre pestañas.

Pendiente: revisión visual de Ronald en su celular y PC, subir la rama, revisar el PR y desplegar al VPS. No se modificó producción. Las imágenes y los estilos del rediseño están incluidos en el repositorio y se compila Tailwind con el proceso habitual.

Validación local: compilación de producción correcta; suite backend con 91 pruebas aprobadas y cuatro integraciones omitidas por sus requisitos de PostgreSQL/concurrencia. Después se agregó y aprobó una prueba adicional con registros para los formularios de edición e intervención. Tres pruebas de interfaz comprueban cancelación, confirmación, doble envío, regreso con Atrás y temas. Navegador local: acceso, tablero, nueve secciones a 320 px, fondos y confirmación de tarifas sin guardar cambios; nombres y correos se apilan en las fichas móviles.
