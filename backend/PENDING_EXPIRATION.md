# Vencimiento de pedidos sin aceptar

Los pedidos nuevos guardan `acceptance_expires_at` al crearse: cinco minutos.
Un reintento con la misma clave no extiende el plazo. Los pedidos anteriores
con plazo nulo quedan intactos; esta migración no modifica sus estados.

Al llegar al límite, una aceptación tardía devuelve 409 y confirma la cancelación
en la misma transacción. El scheduler revisa cada diez segundos con el mismo
bloqueo de fila que usa el restaurante. Una aceptación confirmada antes del
límite queda fuera del vencimiento. La hora del servidor decide, no el teléfono.

Se conserva el pedido y su desglose original, con estado `cancelled`, hora de
cancelación y motivo. No se marca como entregado ni se genera un cobro: el pago
actual es efectivo al recibir. Se reutilizan los avisos privados de tiempo real.

## Activación local (WSL, desde la raíz del proyecto)

```bash
docker compose -f backend/docker-compose.yml exec app php artisan migrate
docker compose -f backend/docker-compose.yml up -d scheduler
docker compose -f backend/docker-compose.yml logs --tail=30 scheduler
```

El scheduler debe permanecer activo. Sin él se rechaza la aceptación tardía,
pero no se cancela en segundo plano hasta que vuelva a funcionar. La actualización
automática puede tardar unos diez segundos tras el límite. Al desplegar una nueva
versión, reiniciar el servicio scheduler para que cargue el código actualizado.

Mis pedidos del cliente consulta cambios cada quince segundos mientras hay
pedidos activos, la aplicación está en primer plano y no se abrió otra ruta.
Una consulta fallida conserva los datos visibles. Se cancela el temporizador al
salir de la pantalla. Por esto, la lista puede reflejar el vencimiento hasta unos
veinticinco segundos después del límite, sumando servidor y consulta del cliente.

La configuración desde el administrador y el tratamiento de pedidos antiguos
quedan pendientes. Las pruebas automatizadas aún deben ejecutarse localmente.
