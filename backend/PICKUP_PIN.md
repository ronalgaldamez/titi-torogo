# PIN de recogida

Cada pedido nuevo recibe seis dígitos aleatorios, incluidos posibles ceros iniciales. Se guarda cifrado con `APP_KEY`, fuera de los campos asignables y oculto en la serialización del modelo. Conservar la clave del servidor al desplegar y protegerla aparte de los respaldos.

El restaurante propietario ve `pickup_pin` en su API solo mientras el pedido está `ready`. El cliente, el motorista, otros restaurantes y los canales de tiempo real no reciben el código. El motorista asignado recibe `pickup_pin_required` y envía `pickup_pin` junto con `status: picked_up` al endpoint existente. El campo no se solicita para entregar.

La autorización y el estado se verifican bajo el bloqueo de fila existente. Un código incorrecto no modifica el pedido; cinco fallos por pedido en una ventana de 300 segundos bloquean nuevos intentos, incluso con código correcto, hasta vencer esa ventana. El contador se comparte entre asignaciones mediante el caché del servidor. Un 429 incluye `Retry-After` y los segundos restantes. Al acertar se limpia el contador. Repetir una recogida ya confirmada conserva hora y avisos, sin volver a pedir código.

Los pedidos anteriores a la migración conservan `pickup_pin = null` y pueden cerrarse con el flujo anterior. No se modifican estados, montos ni direcciones de pedidos existentes. No hay PIN de entrega ni alternativa de omisión para pedidos nuevos en este alcance.

## Despliegue

Publicar la actualización de Flutter para restaurante y motorista junto con el backend. Una versión vieja del motorista no podrá recoger pedidos nuevos protegidos: el servidor rechazará la solicitud sin PIN. No publicar el backend solo sin coordinar la actualización de las apps.

Ejecutar `php artisan migrate --force` en el procedimiento normal de despliegue y reiniciar los procesos persistentes. La migración agrega únicamente una columna nullable. El rollback elimina los códigos; no ejecutarlo mientras existan pedidos nuevos con PIN en curso. No se necesita seeder ni regenerar `APP_KEY`.

## Prueba manual local

1. Crear un pedido nuevo y llevarlo desde el restaurante hasta «Listo para recoger».
2. Comprobar que el restaurante muestra un PIN de seis dígitos en la tarjeta del pedido.
3. Tomarlo con el motorista y pulsar «Recogí el pedido». Cancelar el diálogo: el estado no debe cambiar.
4. Introducir un PIN equivocado: debe aparecer el error y continuar listo para recoger.
5. Ingresar el PIN del restaurante: debe pasar a recogido y cambiar la navegación al cliente. La entrega continúa como antes.
6. En otro pedido de prueba, introducir cinco códigos erróneos: el siguiente intento se bloquea temporalmente. Esperar el tiempo indicado y comprobar que el código correcto funciona.

## Comprobaciones automáticas

`php artisan test --filter=PickupPinTest` comprueba cifrado, privacidad, ceros iniciales, estados, reintentos, permisos, límite de intentos y pedidos anteriores. La suite backend completa pasó con 97 pruebas y 1131 verificaciones; cuatro integraciones PostgreSQL se omiten en SQLite.

Las pruebas Flutter de acciones del motorista verifican cancelación, validación, error del servidor y envío del código correcto; las del restaurante verifican la tarjeta del PIN a 320 px. El análisis de los archivos modificados no reportó problemas. Sigue pendiente la prueba manual con sesiones reales y la validación de producción.

Correcciones de revisión: el diálogo permite desplazarse con el teclado abierto; su prueba reproduce 375 × 812 px, texto ampliado y 320 px de teclado y comprueba que la confirmación sigue accesible. La prueba de aislamiento usa un segundo restaurante activo: su listado no recibe el PIN y la intervención de un pedido ajeno responde 404. Ambas comprobaciones pasaron.
