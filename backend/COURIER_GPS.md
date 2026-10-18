# Seguimiento GPS del motorista

## Comportamiento

- Solo se envían posiciones del GPS durante pedidos propios `ready` o `picked_up`.
- Se reutiliza geolocator; no se añadió una dependencia.
- En Android se inicia desde la aplicación visible un servicio con notificación
  de seguimiento. Permite continuar al abrir Google Maps o bloquear la pantalla.
  No se inicia un servicio nuevo desde segundo plano.
- Sin permiso, GPS apagado o precisión peor que 100 metros, se avisa al motorista.
  No se envía el punto de respaldo del Home.
- Se consulta la asignación antes de cada envío, aproximadamente cada 10 segundos.
  Entregar, cancelar, reasignar o liberar un pedido impide nuevos envíos para él.
  Al quedarse sin entregas o cerrar sesión se cancela la captura.
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

## Prueba local

1. Ejecutar las pruebas de backend y Flutter. No se requiere una migración nueva
   para el GPS ni modificar las dependencias.
2. Reinstalar/iniciar la compilación Android para aplicar los nuevos permisos
   de servicio de ubicación. Una recarga en caliente no actualiza el manifiesto.
3. Usar dos sesiones: cliente en el emulador y motorista en un teléfono Android,
   o dos dispositivos de prueba. Crear, aceptar y preparar un pedido, dejarlo listo
   y tomarlo como motorista.
4. Conceder ubicación precisa. Si falta permiso, usar «Activar seguimiento GPS».
   Verificar la notificación de entrega en curso.
5. Abrir el seguimiento como cliente. Mover el teléfono del motorista, comprobar
   el marcador y «Ver motorista en el mapa». La precisión y la señal condicionan
   la frecuencia; no se simula el recorrido automáticamente.
6. Probar GPS apagado, permiso denegado, pérdida de conexión, Google Maps abierto
   y pantalla bloqueada. Una posición de más de dos minutos deja de mostrarse.
7. Entregar/cancelar o reasignar desde el administrador. Comprobar que el motorista
   anterior deja de enviar y que no se muestra su posición al cliente.

## Límites por validar

Falta ejecutar las pruebas y validar un teléfono real. Si el usuario fuerza el
cierre de Toro Go o Android mata su proceso, no se promete seguimiento continuo:
debe volver a abrir la aplicación. La muestra caduca y no se presenta como actual.
Este repositorio solo tiene configurado Android; no se agregó una plataforma iOS.
