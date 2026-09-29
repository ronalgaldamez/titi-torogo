import axios from 'axios';
window.axios = axios;

window.axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';

/*
 * ACA ESTABA EL import './echo', Y SE QUITO A PROPOSITO.
 *
 * El instalador de broadcasting lo agrego para el cliente de JavaScript
 * (laravel-echo + pusher-js). Nosotros NO lo usamos: el tiempo real lo consumen
 * las apps Flutter (ver frontend/lib/core/realtime.dart). Esos dos paquetes de
 * npm nunca se instalaron, asi que el import rompia la compilacion:
 *
 *   Rollup failed to resolve import "laravel-echo"
 *
 * El dia que el panel necesite escuchar los pedidos en vivo, se instalan
 * (npm install laravel-echo pusher-js) y se vuelve a agregar. Hasta entonces,
 * esto es codigo muerto que ademas rompia el build.
 */
