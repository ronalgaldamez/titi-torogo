# TOROGO - AGENDA DE DESARROLLO

**Proyecto:** ToroGo - App de Delivery
**Desarrollador:** Ronald
**Pais:** El Salvador
**Zona Horaria:** America/El_Salvador (UTC-6)
**Moneda:** USD (Dolar estadounidense)
**Idioma:** Espanol (El Salvador)
**Repositorio:** https://github.com/ronalgaldamez/titi-torogo.git (Actualmente vacio, listo para inicializar)
**Fecha de inicio:** Septiembre 2026
**Palabra clave Fase 2:** Titi

---

## TABLA DE CONTENIDOS

1. Stack Tecnologico
2. Configuracion Regional
3. Convencion de Ramas Titi
4. Flujo de Trabajo Git
5. Buenas Practicas de Desarrollo
6. UX/UI Guidelines
7. Seguridad e Idempotencia
8. Perfil: CLIENTE
9. Perfil: RESTAURANTE
10. Perfil: MOTORIZADO
11. Perfil: ADMIN
12. FASE 2: POST-MVP (Titi)

---

## STACK TECNOLOGICO

### Backend

- Framework: Laravel 12
- Base de datos: PostgreSQL
- Tiempo real: Laravel Reverb (WebSockets)
- Autenticacion: Laravel Sanctum
- Notificaciones: Firebase Cloud Messaging (FCM)

### Frontend (Apps Moviles)

- Framework: Flutter
- Diseno: Material 3 Expressive
- Mapas: Google Maps
- Estado: Riverpod o Bloc (a definir)

### Admin (Panel Web)

- Framework: Laravel + Blade/React (a definir)
- Diseno: Tailwind CSS

### Infraestructura

- Contenedores: Docker Desktop
- Control de versiones: GitHub
- Almacenamiento: MinIO (local) / S3 (produccion)

---

## CONFIGURACION REGIONAL

### Pais y localizacion

- Pais: El Salvador
- Zona horaria: America/El_Salvador (UTC-6)
- Moneda oficial: USD (Dolar estadounidense)
- Formato de fecha: DD/MM/YYYY
- Formato de hora: 12 horas (AM/PM)
- Idioma principal: Espanol (El Salvador)
- Separador de miles: Coma (,)
- Separador decimal: Punto (.)

### Configuracion en Laravel (.env)

APP_TIMEZONE=America/El_Salvador
APP_LOCALE=es_SV
APP_FAKER_LOCALE=es_SV

### Configuracion en Flutter

- Locale por defecto: es_SV
- Formato de moneda: USD
- TimeZone: America/El_Salvador

### Configuracion en PostgreSQL y Docker

- TimeZone por defecto: America/El_Salvador

---

## CONVENCION DE RAMAS TITI

Todas las ramas del proyecto usan el prefijo titi/ en honor a Titi (Aileen Daniel), simbolizando el crecimiento del proyecto.

### Estructura

titi / tipo / descripcion-corta

### Tipos de ramas

- titi/feature/ - Nuevas funcionalidades
- titi/fix/ - Correccion de bugs
- titi/refactor/ - Mejoras de codigo sin cambiar funcionalidad
- titi/docs/ - Documentacion
- titi/setup/ - Configuracion inicial
- titi/test/ - Tests

### Ejemplos

titi/feature/cliente-login
titi/feature/restaurante-menu
titi/feature/motorizado-tracking
titi/fix/pago-doble-cobro
titi/refactor/optimizar-consultas
titi/setup/docker-compose
titi/setup/laravel-inicial

---

## FLUJO DE TRABAJO GIT

### Reglas de oro

1. Yo sugiero, tu ejecutas: El agente de IA NUNCA ejecuta comandos en tu maquina. Siempre te paso los comandos y tu los ejecutas.

2. Cero comandos destructivos: Jamas te dare comandos como rm -rf, drop database, git push --force sin avisarte explicitamente.

3. Rama por feature: Cada cambio nuevo va en su propia rama. Nunca trabajamos directo en main.

4. Probar antes de mergear: Cada rama se prueba completamente antes de hacer merge a main.

5. Tu controlas el push: Yo te entrego el codigo y los comandos, tu decides cuando hacer push.

6. Ciclo de Prueba y Correccion (Obligatorio):
   - Paso 1: El agente entrega el codigo de la funcionalidad (ej. el login).
   - Paso 2: Ronald lo prueba en su entorno local.
   - Paso 3: Si algo falla, Ronald explica el error y el agente da la correccion.
   - Paso 4: Se repite hasta que Ronald confirme: "Funciona perfecto".
   - Paso 5: SOLO ENTONCES el agente da los comandos para commit y push. Jamas antes.

### Ejemplo real del ciclo de prueba

Supongamos que estamos trabajando en la pantalla de Login del Cliente:

PASO 1 - El agente entrega el codigo:

- Crea la rama: git checkout -b titi/feature/cliente-login
- Entrega login_screen.dart con campos email/contrasena, validaciones, boton iniciar sesion
- Pide a Ronald que pruebe

PASO 2 - Ronald prueba y encuentra error:

- "Cuando pongo un email sin @, el boton sigue habilitado. La validacion no funciona."

PASO 3 - El agente corrige:

- Entrega codigo corregido con validacion en tiempo real
- Pide probar de nuevo

PASO 4 - Ronald prueba otra vez:

- "Ahora la validacion funciona, pero el boton queda tapado por el teclado."

PASO 5 - El agente corrige otra vez:

- Agrega SingleChildScrollView y SafeArea
- Pide probar de nuevo

PASO 6 - Ronald confirma:

- "Perfecto, ya funciona todo como quiero."

PASO 7 - Recien ahora el agente da comandos de commit/push:

- git add .
- git commit -m "titi: pantalla de login del cliente con validaciones"
- git push origin titi/feature/cliente-login

RESUMEN DEL CICLO:
Entrega -> Prueba -> Error -> Correccion -> Prueba -> Error -> Correccion -> Prueba -> Funciona -> Commit/Push

REGLA: NUNCA se hace commit hasta que Ronald diga "funciona perfecto".

### Flujo tipico de Git (Inicializacion del repo vacio)

git init
git branch -M main
git remote add origin https://github.com/ronalgaldamez/titi-torogo.git
git checkout -b titi/setup/inicial

# (Se agregan archivos)

git add .
git commit -m "titi: setup inicial del proyecto"
git push -u origin titi/setup/inicial

---

## BUENAS PRACTICAS DE DESARROLLO

### Laravel 12

- Cero hardcode: Usar archivos .env para configuraciones
- Eloquent optimizado: Usar with() para evitar N+1 queries
- Validacion: Usar Form Requests, no validacion inline
- Servicios: Crear Service Classes para logica de negocio compleja
- Jobs y Queues: Usar colas para tareas pesadas (emails, notificaciones)
- Tests: Usar Pest PHP para testing
- API Resources: Transformar datos antes de enviarlos al frontend

### Flutter

- Arquitectura limpia: Separar UI, logica y datos
- Widgets reutilizables: Crear componentes genericos
- Gestion de estado: Usar Riverpod o Bloc (no setState para todo)
- Temas centralizados: Usar app_theme.dart con design tokens
- Cero hardcode: Constantes para colores, textos, URLs
- Responsive: Disenar para multiples tamanos de pantalla

### Base de Datos (PostgreSQL)

- Indices: Crear indices en columnas frecuentemente consultadas
- Migraciones: Siempre crear migraciones, nunca modificar DB manualmente
- Foreign keys: Usar relaciones correctamente
- Soft deletes: Usar deleted_at en lugar de borrar registros
- Optimizacion: Analizar queries lentas con EXPLAIN ANALYZE

---

## UX/UI GUIDELINES

### Estilo visual 2026

- Material 3 Expressive: Formas organicas, transiciones fluidas
- Minimalista: Espacios en blanco, tipografia clara
- Inspiracion: Glovo, Rappi, Uber Eats (pero con identidad propia)
- Cero degradados exagerados: Nada de disenos genericos de IA
- Colores: Paleta limitada y consistente
- Iconografia: Consistente en toda la app

### Modo claro/oscuro

- MVP: Solo modo claro
- Fase 2 (Titi): Agregar modo oscuro

### Notificaciones en pantalla

- Toasts: Mensajes breves en la parte inferior
- Modales: Para acciones importantes
- Sonidos: Fuertes para restaurante y motorizado (no pueden perder pedidos)
- Vibracion: Complementar sonidos en motorizado

---

## SEGURIDAD E IDEMPOTENCIA

### Idempotencia (evitar doble cobro)

- Tokens unicos: Cada transaccion tiene un ID unico
- Validacion server-side: Verificar que no se procese dos veces
- Bloqueos: Usar locks en base de datos para operaciones criticas

### Seguridad de usuarios

- Passwords: Bcrypt con salt automatico
- Tokens: JWT con expiracion corta
- HTTPS: Solo conexiones seguras
- Rate limiting: Prevenir ataques de fuerza bruta

### Seguridad de pagos (Fase 2)

- PCI-DSS: NUNCA guardar datos de tarjetas en nuestra DB
- Tokens: Usar tokens de pasarela (Stripe, Culqi, etc.)
- Validacion: Verificar firma de webhooks

---

## PERFIL: CLIENTE

Plataforma: Flutter App
Pantallas MVP: 14

### Funcionalidades MVP

Auth

- Login/Registro (combinado)
- Verificacion OTP (si usa telefono)

Home

- Lista de restaurantes cercanos
- Selector de direccion actual

Restaurante

- Detalle de restaurante con menu
- Detalle de producto (modal/bottom sheet)

Carrito y Checkout

- Carrito de compras
- Confirmar direccion (elegir entre guardadas)
- Pago (solo efectivo)

Tracking

- Tracking en tiempo real con mapa
- Pedido confirmado

Perfil

- Perfil basico
- Mis direcciones (multiples)
- Mis pedidos (historial)

### Detalles tecnicos

- Pago: Solo efectivo (sin pasarela)
- Direcciones: Multiples direcciones guardadas
- Tracking: Tiempo real con Laravel Reverb + Google Maps
- Carrito: Persistente (si cierra app, sigue ahi)

---

## PERFIL: RESTAURANTE

Plataforma: Flutter App
Pantallas MVP: 10

### Funcionalidades MVP

Auth

- Login (admin crea la cuenta, no auto-registro)

Dashboard

- Estado del restaurante (abierto/cerrado)
- Modo Muy ocupado (alarga tiempos de entrega)
- Resumen rapido de pedidos

Gestion de Pedidos

- Pedidos nuevos con sonido fuerte de notificacion
- Detalle de pedido
- Acciones: Aceptar / Rechazar / Preparando / Listo para recoger
- Aceptacion manual de pedidos

Gestion de Menu

- Lista de productos con toggle (activar/desactivar)
- Agregar/Editar producto
- Categorias del menu

Historial

- Lista de pedidos pasados

Perfil

- Info basica editable (nombre, direccion, telefono, horarios)

### Detalles tecnicos

- Sonido: Fuerte cuando llega pedido nuevo
- Aceptacion: Manual (no automatica)
- Modo ocupado: Alarga tiempos de entrega cuando hay mucho volumen

---

## PERFIL: MOTORIZADO

Plataforma: Flutter App
Pantallas MVP: 8

### Funcionalidades MVP

Auth

- Login (admin crea la cuenta, no auto-registro)

Home / Disponibilidad

- Toggle: Disponible / No disponible
- Resumen: pedidos entregados hoy, ganancias del dia

Gestion de Pedidos

- Pedidos disponibles cercanos (radio configurable, ej: 5 km)
- Detalle de pedido (productos, direcciones, monto)
- Tracking activo con navegacion Google Maps
- Botones de estados: Llegue al restaurante / Recogi / Llegue al cliente / Entregado

Historial y Ganancias

- Historial de entregas completadas
- Ganancias del dia/semana

Perfil

- Info basica (nombre, telefono, vehiculo)
- Documentos (solo visualizacion)

### Detalles tecnicos

- Tiempo para aceptar: 30 segundos
- Navegacion: Google Maps integrado
- Geolocalizacion: En background (tracking en tiempo real)
- Radio de busqueda: Solo pedidos cercanos (5 km por defecto)
- Notificacion: Sonido fuerte + vibracion cuando llega pedido disponible

---

## PERFIL: ADMIN

Plataforma: Panel Web (Laravel + Blade/React)
Pantallas MVP: 10

### Funcionalidades MVP

Auth

- Login seguro (acceso unico para Ronald)

Dashboard

- Resumen general (pedidos activos, restaurantes, motorizados)
- Graficas basicas del dia

Gestion de Restaurantes

- Lista de restaurantes (crear, editar, activar/desactivar)
- Detalle de restaurante

Gestion de Motorizados

- Lista de motorizados (crear, editar, activar/desactivar)
- Detalle de motorizado

Gestion de Pedidos

- Lista de todos los pedidos (activos y pasados)
- Detalle de pedido con intervencion manual (cancelar, reasignar)

Gestion de Clientes

- Lista de clientes registrados

Configuracion

- Tarifas de envio
- Comisiones para restaurantes y motorizados
- Parametros generales (radio de busqueda, tiempos)

### Detalles tecnicos

- Acceso: Solo Ronald por ahora (sin roles multiples)
- Intervencion: Puede cancelar pedidos, reasignar motorizados manualmente

---

## FASE 2: POST-MVP (PALABRA CLAVE: TITI)

Cuando se activa: Cuando Ronald termine el MVP y diga Titi

### Cliente - Features pendientes

- Busqueda avanzada con filtros
- Categorias y subcategorias de restaurantes
- Wallet / Billetera virtual
- Cupones y promociones
- Chat en vivo con motorizado
- Calificaciones y resenas
- Programar pedidos para despues
- Onboarding con 3 pantallas
- Modo oscuro
- Pasarela de pagos
- Lista de favoritos
- Refer a friends
- Reorden con 1 tap

### Restaurante - Features pendientes

- Estadisticas y reportes
- Graficas de productos mas vendidos
- Promociones y descuentos propios
- Responder resenas de clientes
- Gestion de horarios complejos
- Multiples sucursales
- Gestion de empleados
- Exportar historial a PDF/Excel
- Integracion con impresoras termicas
- Modo oscuro
- Facturacion electronica

### Motorizado - Features pendientes

- Estadisticas detalladas de rendimiento
- Bonos e incentivos
- Sistema de propinas
- Chat con soporte
- Gestion de documentos
- Multiples vehiculos registrados
- Historial de calificaciones
- Modo oscuro

### Admin - Features pendientes

- Roles multiples
- Reportes avanzados y exportacion
- Gestion de promociones y cupones
- Sistema de disputas y reclamos
- Gestion financiera
- Auditoria completa de logs
- Modo oscuro

---

## RESUMEN DE PANTALLAS MVP

Cliente: 14 pantallas (Flutter App)
Restaurante: 10 pantallas (Flutter App)
Motorizado: 8 pantallas (Flutter App)
Admin: 10 pantallas (Panel Web)
TOTAL: 42 pantallas

---

## PRIMEROS PASOS

1. Setup inicial: Conectar repo vacio, Docker + Laravel 12 + PostgreSQL
2. Autenticacion: Login/registro para los 4 perfiles
3. Home del cliente: Lista de restaurantes
4. Gestion de menu: Restaurante puede agregar productos
5. Flujo de pedido: Cliente a Restaurante a Motorizado a Cliente
6. Tracking en tiempo real: WebSockets + Google Maps
7. Panel admin: Controlar todo el ecosistema

---

## NOTA PERSONAL

Este proyecto lleva el nombre de Titi (Aileen Daniel) en cada rama, como simbolo de crecimiento. Cada titi/feature es un recordatorio de que estas construyendo algo que crece, igual que tu hija.

Cuando termines el MVP y estes listo para la Fase 2, solo di Titi y continuaremos desde ahi.

---

Documento generado: Septiembre 2026
Version: 1.2 (Final con repo y config regional)
Fase siguiente: Titi (pendiente de activar)
