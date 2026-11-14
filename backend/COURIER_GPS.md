# Seguimiento GPS del motorista

## Comportamiento

- Se envía presencia privada mientras el motorista está disponible, incluso sin pedidos.
- El GPS visible al cliente solo se envía para pedidos propios `ready` o `picked_up`.
- Se reutiliza geolocator; no se añadió una dependencia.
- En Android se inicia desde la aplicación visible un servicio con notificación
  de seguimiento. Permite continuar al abrir Google Maps o bloquear la pantalla.
  No se inicia un servicio nuevo desde segundo plano.
- Sin permiso, GPS apagado o precisión peor que 100 metros, se avisa al motorista.
  No se envía el punto de respaldo del Home.
- Se consulta la asignación antes de cada envío, aproximadamente cada 10 segundos.
  Entregar, cancelar, reasignar o liberar un pedido impide nuevos envíos para él.
  Al quedarse sin entregas y no estar disponible, o al cerrar sesión, se cancela la captura.
  Si sigue disponible al terminar, continúa enviando presencia para recibir otro pedido.
- Tras un corte de conexión se envía una posición nueva; no se acumulan recorridos.
- El cliente consulta cada 10 segundos mientras mira el seguimiento, puede centrar
  el mapa en el motorista y ve si se perdió la actualización o falta una posición.

## Privacidad y almacenamiento

`PATCH /api/courier/orders/{id}/location` solo admite al motorista actualmente
asignado y mantiene el bloqueo de fila compartido con las acciones de pedidos.
Valida coordenadas, precisión y captura reciente; ignora muestras repetidas o
anteriores a la última recibida.

`GET /api/orders/{id}/location` solo admite al dueño del pedido. No comparte GPS
con restaurantes, otros clientes ni otros motoristas. La ubicación no forma
parte de `OrderResource` ni de los avisos de WebSocket compartidos.

Solo la última posición se guarda en caché durante dos minutos por pedido y
motorista, sin tabla ni historial de movimientos. Los pedidos cerrados no la
devuelven; después de una reasignación no se lee la posición del motorista anterior.
Las respuestas del cliente usan `private, no-store`.

## Disponibilidad para pedidos nuevos

`PATCH /api/courier/presence` requiere cuenta de motorista activa y disponible,
coordenadas válidas, precisión de hasta 100 metros y captura de los últimos
30 segundos (hasta 10 segundos futuros por desfase del reloj). Solo conserva
la última posición por usuario en caché privada durante dos minutos; no hay
ruta pública para leerla ni eventos con coordenadas. Desactivar disponibilidad
borra la presencia; reactivarla requiere una posición nueva. Cerrar sesión la borra.

Antes de crear un pedido, el servidor exige un motorista activo, disponible,
sin pedidos activos asignados, a máximo 5 km del restaurante (distancia geográfica,
no distancia por carretera), con presencia recibida y capturada hace menos de
dos minutos. Sin él devuelve 422 y el cliente conserva su carrito. Los reintentos
con clave de un pedido ya creado lo recuperan aunque no haya motoristas libres.

La toma y la asignación administrativa bloquean la fila del motorista para impedir
dos entregas simultáneas. Los pedidos existentes no se reasignan ni cancelan en lote.
Esta comprobación no reserva al motorista: varios clientes pueden confirmar antes
de que alguien tome una entrega. No garantiza quién repartirá un pedido ya aceptado.

## Prueba local

1. Ejecutar las pruebas de backend y Flutter. No se requiere una migración nueva
   para el GPS ni modificar las dependencias.
2. Reinstalar/iniciar la compilación Android para aplicar los nuevos permisos
   de servicio de ubicación. Una recarga en caliente no actualiza el manifiesto.
3. Usar dos sesiones: cliente en el emulador y motorista en un teléfono Android,
   o dos dispositivos de prueba. Activar Disponible y GPS preciso a menos de 5 km
   del restaurante, esperar «GPS activo · Disponible para recibir pedidos cerca».
   Crear, aceptar y preparar un pedido, dejarlo listo y tomarlo como motorista.
4. Conceder ubicación precisa. Si falta permiso, usar «Activar seguimiento GPS».
   Verificar la notificación «Toro Go · GPS activo».
5. Abrir el seguimiento como cliente. Mover el teléfono del motorista, comprobar
   el marcador y «Ver motorista en el mapa». La precisión y la señal condicionan
   la frecuencia; no se simula el recorrido automáticamente.
6. Probar GPS apagado, permiso denegado, pérdida de conexión, Google Maps abierto
   y pantalla bloqueada. Una posición de más de dos minutos deja de mostrarse.
7. Entregar/cancelar o reasignar desde el administrador. Comprobar que el motorista
   anterior deja de enviar y que no se muestra su posición al cliente.

8. Sin motoristas disponibles, confirmar desde el cliente: comprobar el aviso y
   que conserva productos, dirección y propina sin crear un pedido.
9. Dejar al motorista sin internet durante dos minutos y probar otro pedido:
   debe bloquearlo. Reconectar, recibir una posición GPS nueva y volver a confirmar.
10. Con un pedido asignado, intentar tomar/asignar otro: debe rechazarlo. Terminar,
    cancelar o liberar el primero permite tomar otro; repetir la toma del mismo
    pedido sigue siendo seguro.

## Prueba de asignaciones simultáneas en PostgreSQL

Desde la raíz del proyecto, con Docker local activo:

```bash
docker compose -f backend/docker-compose.yml exec -e CONCURRENCY_DB_DATABASE=torogo app php vendor/bin/phpunit --filter CourierAssignmentConcurrencyTest
```

`CONCURRENCY_DB_DATABASE` indica la base local de pruebas disponible (el nombre
predeterminado local es `torogo`). La prueba crea un esquema temporal exclusivo,
ejecuta allí las migraciones y lo elimina al terminar; no cambia el esquema
público ni sus pedidos. No ejecutar contra producción. Requiere PostgreSQL y
`pcntl`, incluidos en el contenedor de PHP. Sin la variable, estas tres pruebas
se omiten en la suite normal de SQLite.

Se ejecutan dos procesos con conexiones independientes para dos tomas, toma
contra asignación administrativa y dos asignaciones administrativas. Se verifica
que ambos esperen el bloqueo del motorista y que solo una asignación se complete.

## Límites por validar

Falta ejecutar las pruebas y validar un teléfono real. Si el usuario fuerza el
cierre de Toro Go o Android mata su proceso, no se promete seguimiento continuo:
debe volver a abrir la aplicación. La muestra caduca y no se presenta como actual.
Este repositorio solo tiene configurado Android; no se agregó una plataforma iOS.
