<?php

use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

/*
|--------------------------------------------------------------------------
| Canales de tiempo real (Reverb)
|--------------------------------------------------------------------------
|
| Aca se decide QUIEN puede escuchar QUE, y es la parte que no se puede
| saltear: un canal privado sin esta verificacion seria el pedido de
| cualquiera abierto a cualquiera.
|
| El telefono pide el permiso con POST /api/broadcasting/auth (ver
| routes/api.php) mandando su token de Sanctum. Si la funcion de abajo
| devuelve false, el aparato NO entra al canal y no recibe nada.
|
| Es la MISMA regla de dueno que ya usan los controladores, escrita una sola
| vez. Si cambia quien puede ver un pedido, se cambia aca.
|
*/

/*
 * El canal de UN pedido.
 *
 * Entran exactamente los tres que tienen algo que hacer con el: el cliente que
 * lo pidio, el restaurante que lo cocina y el motorizado que lo lleva. Nadie
 * mas: ni otro restaurante, ni otro motorizado, ni otro cliente.
 *
 * La consulta sale del modelo que Laravel resuelve por el {order} de la URL,
 * asi que un pedido que no existe no entra ni a la verificacion.
 */
Broadcast::channel('orders.{order}', function (User $user, Order $order): bool {
    if ($user->id === $order->user_id) {
        return true;
    }

    if ($order->courier_id !== null && $user->id === $order->courier_id) {
        return true;
    }

    return $order->restaurant !== null && $order->restaurant->user_id === $user->id;
});

/*
 * El canal personal de cada cuenta.
 *
 * Este lo deja Laravel y NO es de un pedido: sirve para los avisos que son de
 * la persona y no de un pedido puntual (por ejemplo, cuando el administrador
 * da de alta una cuenta).
 */
Broadcast::channel('App.Models.User.{id}', function (User $user, int $id): bool {
    return $user->id === $id;
});
