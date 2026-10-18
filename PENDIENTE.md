# Pendientes de Toro Go

Esta lista organiza trabajo por revisar y acordar. No autoriza implementar funcionalidades ni modificar reglas de negocio automáticamente.

Actualizada el 18/10/2026. Las casillas distinguen implementación completada de verificaciones todavía pendientes; no significan que se hayan vuelto a ejecutar las pruebas hoy.

## Cliente: revisar y completar

- [ ] Perfil: revisar qué datos personales puede consultar y editar el cliente, incluidos nombre y teléfono.
- [ ] Cancelaciones: comprobar cuándo puede cancelar y explicar claramente las restricciones y los estados.
- [ ] Probar el recorrido completo: pedido normal, rechazo del restaurante, pérdida de conexión, recuperación sin duplicados y entrega final.
- [ ] Seguimiento GPS: verificar la ubicación real del motorista que recibe y muestra el cliente, diferenciándola de las actualizaciones del estado del pedido.
  - Implementado en `titi/feature/seguimiento-gps`, pendiente de ejecutar pruebas y validar dos sesiones/dispositivos: captura Android con notificación durante entregas propias, consulta privada del cliente cada 10 segundos, precisión y caducidad visibles. Solo se conserva la última posición en caché por dos minutos; no se publica en canales compartidos. Ver `backend/COURIER_GPS.md` para permisos y pruebas con pantalla bloqueada, desconexión y reasignación.
- [ ] Estados y permisos: revisar carga, pantallas vacías, errores recuperables y acceso únicamente a los pedidos de la propia cuenta.

Antes de implementar, revisar el código para distinguir funcionalidades faltantes de las que solo necesitan validación.

## Categorías dinámicas administradas desde el panel

Implementadas y fusionadas en `main` desde `titi/feature/categorias-dinamicas`: catálogo global del administrador, selección múltiple desde Mi local y filtros del inicio del cliente. Las cinco opciones anteriores se crean como catálogo inicial; cada restaurante elige sus categorías, sin asignaciones automáticas por nombre. El cliente obtiene cambios al actualizar el inicio y el restaurante al abrir su selector. Ronald confirmó que pudo agregar «Cuca» desde el administrador.

Iconos: se conserva la presentación con icono y nombre debajo. El administrador puede subir PNG/JPG/WebP opcional (hasta 2 MB y 1024 × 1024), conservarlo al editar o quitarlo. Sin imagen, o si falla al cargar, se utiliza un icono predeterminado. Los archivos se guardan en el disco público local y se sirven mediante la API para que funcionen en el emulador sin configurar enlaces de almacenamiento.

- [x] Reemplazar las opciones fijas del inicio del cliente por categorías administrables y filtros funcionales.
- [x] Permitir al administrador crear, editar, ordenar y desactivar categorías.
- [x] Permitir que Ronald agregue desde el administrador las categorías que le soliciten los restaurantes. No se creó un flujo de solicitudes dentro de la app.
- [x] Cargar las opciones activas en Mi local y permitir seleccionar varias categorías por restaurante.
- [x] Separar las categorías globales de tipos de comida de las categorías internas del menú.
- [x] Recuperar la presentación con iconos y reducir la separación entre opciones.
- [x] Implementar imágenes opcionales administrables e iconos predeterminados cuando no haya imagen o falle su carga.
- [ ] Confirmar las pruebas de backend y Flutter después de incorporar los iconos personalizados; las 41 pruebas de Flutter reportadas como aprobadas fueron anteriores a ese ajuste.
- [ ] Probar en el entorno local subir, reemplazar y quitar una imagen, y verificar su visualización en el emulador.
- [ ] Verificar manualmente selección en Mi local, filtrado del cliente y ocultación de una categoría desactivada.

## Pedidos que el restaurante no acepta

Problema original: existían pedidos de prueba que seguían pendientes durante días porque el restaurante no los aceptó. Los pedidos anteriores se conservan sin vencimiento y siguen sujetos a una decisión aparte.

- [x] Revisar e implementar el vencimiento; fusionado desde `titi/feature/vencimiento-pedidos`.
- [x] Acordar e implementar 5 minutos para aceptar pedidos nuevos, contados desde su creación. Los reintentos no extienden el plazo.
- [x] Proteger la aceptación al llegar al límite con bloqueo de fila y cancelación confirmada en la misma transacción.
- [x] Ejecutar la migración y levantar el scheduler, que revisa los vencimientos cada 10 segundos.
- [x] Mostrar fecha límite y motivo de cancelación al cliente y al restaurante, conservando el historial.
- [x] Actualizar Mis pedidos del cliente automáticamente cada 15 segundos mientras hay pedidos activos y la pantalla está visible en primer plano.
- [x] Implementar el aviso de que no hay que pagar para pedidos cancelados o rechazados en efectivo.
- [ ] Evaluar que el tiempo de espera sea configurable desde el administrador.
- [x] Mantener el desglose original, registrar la cancelación sin marcar entrega y verificar que el vencimiento no modifica los montos.
- [ ] Acordar cómo tratar los pedidos antiguos de prueba antes de actualizar datos. No borrar ni cancelar pedidos existentes automáticamente por crear esta lista.
- [x] Aprobar las pruebas de backend del vencimiento: límite exacto, aceptación previa, pedidos antiguos, aislamiento entre cuentas y ausencia de eventos duplicados. Ronald reportó 33 pruebas aprobadas y 300 verificaciones en esa etapa.
- [x] Comprobar en la app un pedido cancelado con el motivo «El restaurante no respondió a tiempo».

## Restaurante: siguiente revisión

- [ ] Logo del negocio en Mi local: revisar carga, edición y visualización; por ahora conservar la inicial del restaurante.

- [x] Revisar y mejorar Pedidos y Mi menú del restaurante.
- [x] Mostrar propuestas y aplicar los diseños aprobados para Pedidos, Mi menú, Mi local e Historial.
- [x] Mejorar Mi local y configurar preparación entre 10 y 45 minutos.
- [x] Implementar y probar el historial del restaurante: filtros por estado y período, paginación, detalle y aislamiento entre cuentas. Ronald aprobó el diseño y reportó las pruebas correspondientes como aprobadas antes del merge.

## Estimación de entrega completa

- [ ] El tiempo mostrado actualmente proviene de preparación del local. Incorporar recorrido y disponibilidad del motorista al estimar la entrega completa, sin sumar tiempos dos veces.
- [ ] El aumento de Muy ocupado se mantiene en 50%, con un techo de 45 minutos de preparación; evaluar más adelante su configuración desde el administrador.

## Etapa posterior

- [ ] Pagos con tarjeta.
- [ ] Chat vinculado a pedidos con permisos y privacidad.
- [ ] Favoritos y reseñas.

La prioridad sigue siendo terminar y validar el delivery de comida. Mantener la paleta, tipografía y tema actuales; discutir nuevas dependencias, cambios de backend y decisiones arquitectónicas antes de implementarlos.
