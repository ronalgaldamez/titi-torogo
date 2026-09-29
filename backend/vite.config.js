import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js'],
            refresh: true,
        }),
        tailwindcss(),
    ],
    server: {
        // OJO CON ESTAS DOS LINEAS, QUE PARECEN LO MISMO Y NO LO SON:
        //
        //   host: true  -> Vite ESCUCHA en todas las interfaces (0.0.0.0), que
        //                  es lo que hace falta para que el puerto publicado del
        //                  contenedor llegue a tu PC.
        //
        //   hmr.host    -> la direccion que Vite le escribe AL NAVEGADOR, en
        //                  public/hot. Tiene que ser localhost: un navegador no
        //                  puede ir a 0.0.0.0, y cuando Laravel arma el HTML con
        //                  esa direccion el CSS no carga y sale
        //                  ERR_ADDRESS_INVALID (nos paso con el panel).
        host: true,
        port: 5173,
        strictPort: true,
        hmr: {
            host: 'localhost',
        },
        watch: {
            ignored: ['**/storage/framework/views/**'],
        },
    },
});
