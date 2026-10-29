# ToroGo: levantar los servicios locales

Guía para un entorno que ya está instalado y configurado. Permite trabajar con la landing y el admin sin conectar el teléfono ni abrir Flutter en emulador o navegador.

## 1. Abrir Docker Desktop

Abrí Docker Desktop y esperá a que el motor esté funcionando.

## 2. Entrar al proyecto

Elegí **solo el comando de tu terminal**. Las rutas de Git Bash y Ubuntu/WSL son distintas.

### Git Bash / UCRT64 / MINGW64

```bash
cd /c/Users/ronal/Documents/Proyectos/titi_app
```

### Ubuntu / WSL

```bash
cd /mnt/c/Users/ronal/Documents/Proyectos/titi_app
```

### PowerShell

```powershell
Set-Location 'C:\Users\ronal\Documents\Proyectos\titi_app'
```

Si falla el cambio de carpeta, corregí la ruta antes de seguir. Los siguientes comandos se ejecutan desde la raíz `titi_app`, no desde `frontend`.

## 3. Levantar Docker y revisar el estado

Los comandos son los mismos en las tres terminales:

```bash
docker compose -f backend/docker-compose.yml up -d
docker compose -f backend/docker-compose.yml ps
```

Esperá a que los servicios aparezcan como `Up` o `Running`. PostgreSQL y Redis deben aparecer como `healthy`.

Este arranque incluye Laravel/PHP, Nginx, PostgreSQL, Redis, MinIO, Mailpit, Reverb, scheduler y Node/Vite para los estilos del admin.

El servicio Docker `app` es **Laravel**, no la aplicación Flutter. Estos comandos no abren la app en teléfono, emulador ni navegador. No hace falta ejecutar `flutter run` ni comandos de ADB para trabajar en la landing.

## 4. Abrir la landing o el admin

| Página | Dirección local |
| --- | --- |
| Landing | [http://localhost:8080/](http://localhost:8080/) |
| Admin | [http://localhost:8080/admin](http://localhost:8080/admin) |
| Editar la landing | [http://localhost:8080/admin/pagina-web](http://localhost:8080/admin/pagina-web) |
| Correos de prueba: Mailpit | [http://localhost:8025/](http://localhost:8025/) |
| Archivos: consola MinIO | [http://localhost:9001/](http://localhost:9001/) |

Estas son las direcciones con los puertos predeterminados. Si se cambiaron en `backend/.env`, usá los puertos configurados.

Si no ves un cambio de diseño, recargá la página con **Ctrl + F5**.

## Cuando hay migraciones nuevas

Después de levantar los servicios, si los cambios del proyecto incluyen migraciones pendientes:

```bash
docker compose -f backend/docker-compose.yml exec app php artisan migrate
```

No necesitás ejecutar migraciones todos los días. Para este arranque no hace falta reiniciar ni volver a sembrar la base de datos.

## Si un servicio falla

Revisá el estado y los últimos mensajes:

```bash
docker compose -f backend/docker-compose.yml ps -a
docker compose -f backend/docker-compose.yml logs --tail=80 app nginx reverb scheduler node
```

Si aparece el error de montaje de `default.conf` o `Could not open input file: artisan`, verificá primero que estés en la carpeta correcta y que existan estos archivos:

- `backend/artisan`
- `backend/docker/nginx/default.conf`

Si ambos existen, recreá los contenedores que montan el código:

```bash
docker compose -f backend/docker-compose.yml up -d --force-recreate app nginx reverb scheduler node
```

Esto conserva los volúmenes de datos. Si vuelve a fallar, guardá la salida del error antes de intentar otros cambios.

## Al terminar

Para detener los servicios sin borrar los datos:

```bash
docker compose -f backend/docker-compose.yml stop
```

Para volver a levantarlos, repetí el paso 3.

**No uses `docker compose down -v` ni `php artisan migrate:fresh` para arrancar el proyecto:** eliminan volúmenes o tablas y pueden borrar tus datos.


### Imágenes de restaurantes en S3

Mi local permite elegir logo y portada (PNG, JPG o WebP, hasta 5 MB por archivo y 6000 píxeles por lado), previsualizar y guardar. Las claves solo viven en `backend/.env`; nunca se envían a Flutter ni se suben al repositorio.

La migración `2026_10_25_120000_add_restaurant_cover_and_media_directory` agrega campos sin borrar datos. Las rutas se guardan en la base; el prefijo `negocios/{nombre-inicial}-{id}` queda fijo aunque cambie el nombre, con subcarpetas `logo/` y `portada/`. Las fotos de platos se guardan bajo `platos/{id}/`, una por plato, desde Agregar/Editar plato. Los seeders no deben sobrescribir estas rutas.

El bucket permanece privado. Las URLs de lectura firmadas duran una hora y se renuevan consultando el restaurante. Si una imagen deja de cargar después de ese tiempo, actualizar la pantalla. Los archivos anteriores se eliminan después de confirmar el reemplazo; si falla antes de guardar, se conserva la referencia anterior y se intenta limpiar la subida parcial.

Al agregar `image_picker`, ejecutar `flutter pub get` y detener/volver a ejecutar Flutter; hot reload no registra el plugin nativo nuevo. La selección es desde galería; no pide cámara. Se debe probar la carga en Android con fotos presentes en el emulador. El editor de platos permite guardar una foto con sus datos y una oferta opcional. Antes de probarlo, ejecutar `php artisan migrate` dentro del contenedor app para agregar las columnas de ofertas (sin borrar datos). La oferta usa inicio inclusivo y final exclusivo; al vencer vuelve al precio normal sin scheduler. Los selectores usan hora de El Salvador. El servidor calcula el importe y rechaza pedidos cuyo precio confirmado haya cambiado; el cliente debe actualizar el menú y revisar el carrito.
