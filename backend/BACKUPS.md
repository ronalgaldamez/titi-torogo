# Respaldos de ToroGo

## Alcance y configuración

`/admin/respaldos` permite solicitar una copia manual, activar una programación
diaria en hora de El Salvador y consultar el historial. El valor inicial es
03:00 y la programación comienza desactivada para poder verificar primero el
destino y la restauración. El servidor procesa una solicitud por minuto; cerrar
el navegador no cancela la copia. Un respaldo en espera o en ejecución impide
solicitar otro. Si el servidor vuelve después de la hora programada, recupera la
copia de ese día una sola vez.

Cada archivo `.tar.gz` contiene:

- `database.dump`: PostgreSQL en formato custom, con una instantánea consistente.
- `public/`: archivos de `storage/app/public`, incluidas landing y categorías.
- `manifest.json`: fecha, identificador y SHA-256 del archivo de PostgreSQL.

La copia toma un bloqueo de lectura sobre las tablas que referencian las imágenes
locales hasta terminar de archivarlas. Su edición puede esperar durante ese
intervalo; no se bloquean las tablas de pedidos para generar la copia.

La subida usa HTTPS, SSE-S3 y SHA-256. Se comprueban el tamaño y checksum devueltos
por S3 antes de registrar éxito. No se envían ACL. Los nombres son únicos bajo
`backups/AAAA/MM/DD/`. Las credenciales del VPS solo permiten listar ese prefijo,
guardar, leer y abortar subidas multipart; no borrar copias ni administrar el bucket.

Los errores se muestran en el historial y con un aviso en el panel. El detalle
técnico queda en el registro privado del servidor. Esta etapa no envía correos:
el correo de producción sigue pendiente de configuración.

No incluye `.env`, claves SSH, configuración del sistema ni archivos que ya están
en el bucket de imágenes. Hay que conservar los secretos en una copia cifrada
separada, fuera del VPS, y acordar la protección de `torogo-images`. No se debe
considerar cubierta la recuperación completa del VPS hasta terminar esos puntos.

## Variables privadas

En `backend/.env`, sin reemplazar las variables de las imágenes:

```dotenv
BACKUP_AWS_ACCESS_KEY_ID=
BACKUP_AWS_SECRET_ACCESS_KEY=
BACKUP_AWS_DEFAULT_REGION=us-east-2
BACKUP_AWS_BUCKET=torogo-backups
```

El bucket debe ser privado, con todas las opciones de bloqueo público activadas,
ACL deshabilitadas, SSE-S3 y control de versiones habilitado. El usuario
`torogo-backups-vps` no necesita acceso a la consola. No publicar ni pegar sus claves.

## Retención en S3: paso obligatorio antes de activar la programación

El administrador del bucket debe configurar estas reglas en **Administración →
Reglas del ciclo de vida**, limitadas al prefijo `backups/`:

1. Expirar versiones actuales después de **30 días**.
2. Eliminar definitivamente versiones no actuales después de **1 día** desde que
   dejan de ser actuales, sin fijar un número mínimo de versiones a conservar.
3. Eliminar marcadores de eliminación vencidos. Si la consola no permite combinar
   esta opción con la expiración por días, crear otra regla para el mismo prefijo.
4. Cancelar cargas multipart incompletas después de **1 día**.

Con versiones habilitadas, expirar un objeto actual NO elimina inmediatamente sus
datos: pasa a versión no actual. Es necesaria la segunda acción para liberar el
espacio. La eliminación de versiones antiguas es irreversible: esta regla es solo
para el bucket exclusivo de respaldos, no para imágenes. S3 aplica las reglas de
forma asíncrona; puede quedar almacenamiento adicional después del día 30. El panel
ofrece descargas durante 30 días desde que la copia se completa.

Además, agregar al bucket una política que deniegue transporte sin TLS:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyInsecureTransport",
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": ["arn:aws:s3:::torogo-backups", "arn:aws:s3:::torogo-backups/*"],
    "Condition": {"Bool": {"aws:SecureTransport": "false"}}
  }]
}
```

Se configura usando la cuenta administradora de AWS, no las claves limitadas del
VPS. No sustituir políticas adicionales existentes sin revisarlas.

## Despliegue en el VPS

Después de probar, fusionar el PR y ejecutar `git pull --ff-only origin main`:

```bash
cd /var/www/torogo/backend
pg_dump --version
pg_restore --version
php artisan migrate --force &&
php artisan config:cache &&
php artisan route:cache &&
php artisan view:cache &&
sudo systemctl reload php8.5-fpm &&
sudo systemctl restart torogo-queue torogo-reverb torogo-scheduler
```

`pg_dump` debe ser compatible con PostgreSQL 18. El VPS ya reportó `pg_dump 18.6`.
El usuario que ejecuta `torogo-scheduler` necesita escribir en `storage/` y acceso
de lectura a PostgreSQL y a los archivos públicos. No necesita permisos root.

1. Entrar como administrador en `/admin/respaldos` y pulsar **Respaldar ahora**.
2. Esperar al próximo minuto y actualizar el historial; debe quedar **Correcto**.
3. Descargar la copia desde el panel y probarla en un entorno aislado.
4. Confirmar las reglas de ciclo de vida en AWS y la prueba de restauración.
5. Activar la programación diaria a las **03:00**. No requiere mantener el panel abierto.
6. Comprobar al día siguiente el historial y verificar periódicamente otra restauración.

El comando `php artisan backups:run` permite procesar inmediatamente una solicitud
pendiente. También comprueba la programación diaria. No crea una copia manual si
no hay una solicitud y el horario automático no corresponde.

El límite de generación es 10 minutos para `pg_dump` y 10 para `tar`. Las llamadas
a S3 tienen timeout de 120 segundos y dos reintentos. El bloqueo de ejecución dura
una hora; al recuperar el servidor, una ejecución marcada activa hace más de una
hora queda registrada como interrumpida. No hay reintentos automáticos de copias
fallidas: el administrador puede solicitar otra y se conserva el error anterior.

## Pruebas locales

La imagen PHP incluye el cliente PostgreSQL 18. Reconstruir sin borrar volúmenes:

```bash
docker compose -f backend/docker-compose.yml build app
docker compose -f backend/docker-compose.yml run --rm --no-deps app php vendor/bin/phpunit --filter BackupsTest
docker compose -f backend/docker-compose.yml run --rm --no-deps -e BACKUP_TEST_DATABASE=torogo app php vendor/bin/phpunit --filter BackupRestoreTest
```

La segunda prueba usa S3 simulado. La tercera ejecuta `pg_dump` y `pg_restore`
reales en dos bases temporales con nombres aleatorios y datos sintéticos; también
simula S3. El rol local necesita permiso de crear bases para esa prueba. Las bases
temporales se eliminan al finalizar, sin migrar ni restaurar sobre `torogo`.
No ejecutar esta prueba de desarrollo en producción. Sin `BACKUP_TEST_DATABASE`,
se omite en la suite normal de SQLite.

La prueba automática demuestra recuperación del formato generado; no sustituye
descargar y restaurar una copia real desde el bucket de producción.

## Restauración manual: solo entorno aislado

No existe una ruta web ni un comando de la aplicación que restaure producción.
Usar una instancia PostgreSQL de pruebas separada, con su propia base vacía y su
propio archivo `.pgpass` privado (modo 0600), fuera del VPS de producción.

1. Descargar una copia desde el panel y anotar su SHA-256, visible en **Ver SHA-256**
   en el historial. Comparar con `sha256sum archivo.tar.gz` antes de extraerla.
2. Extraerla en un directorio privado vacío y comprobar el SHA-256 de
   `database.dump` contra `manifest.json`.
3. Verificar con `psql` que la conexión apunta a la instancia y base de pruebas.
4. Ejecutar, sustituyendo las tres variables por datos exclusivos de pruebas:

```bash
pg_restore --exit-on-error --no-owner --no-acl \
  --host="$RESTORE_HOST" --username="$RESTORE_USER" --dbname="$RESTORE_DATABASE" \
  database.dump
```

5. Recuperar `public/` únicamente en el almacenamiento de la aplicación de pruebas.
6. Comprobar usuarios, restaurantes, pedidos, montos e imágenes. La aplicación de
   pruebas debe tener las copias automáticas desactivadas, correo y tareas
   externas deshabilitados, y nunca reutilizar credenciales de producción.

El respaldo no contiene roles globales de PostgreSQL ni secretos de Laravel. La
instancia de recuperación necesita sus usuarios, extensiones y configuración antes
de restaurar. La primera versión admite archivos de hasta 5 GB; debe cambiar a
multipart si el tamaño se acerca a ese límite. No se dejan copias terminadas en el
disco del VPS. Si el sistema mata el proceso, pueden quedar temporales privados
en `storage/app/private/backup-work/`; revisar y retirar solo directorios de
ejecuciones terminadas, nunca mientras hay una copia activa.
