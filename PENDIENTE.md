# Pendientes de Toro Go

Esta lista organiza trabajo por revisar y acordar. No autoriza implementar funcionalidades ni modificar reglas de negocio automáticamente.

## Cliente: revisar y completar

- [ ] Perfil: revisar qué datos personales puede consultar y editar el cliente, incluidos nombre y teléfono.
- [ ] Cancelaciones: comprobar cuándo puede cancelar y explicar claramente las restricciones y los estados.
- [ ] Probar el recorrido completo: pedido normal, rechazo del restaurante, pérdida de conexión, recuperación sin duplicados y entrega final.
- [ ] Seguimiento GPS: verificar la ubicación real del motorista que recibe y muestra el cliente, diferenciándola de las actualizaciones del estado del pedido.
- [ ] Estados y permisos: revisar carga, pantallas vacías, errores recuperables y acceso únicamente a los pedidos de la propia cuenta.

Antes de implementar, revisar el código para distinguir funcionalidades faltantes de las que solo necesitan validación.

## Categorías dinámicas administradas desde el panel

Implementación en `titi/feature/categorias-dinamicas`, pendiente de ejecutar migración y pruebas: catálogo global del administrador, selección múltiple desde Mi local y filtros del inicio del cliente. Se mantienen separadas de las categorías del menú. Las cinco opciones anteriores se crean como catálogo inicial; cada restaurante elige sus categorías, sin asignaciones automáticas por nombre. El cliente obtiene cambios al actualizar el inicio y el restaurante al abrir su selector.

Iconos: se conserva la presentación con icono y nombre debajo. El administrador puede subir PNG/JPG/WebP opcional (hasta 2 MB y 1024 × 1024), conservarlo al editar o quitarlo. Sin imagen, o si falla al cargar, se utiliza un icono predeterminado. Los archivos se guardan en el disco público local y se sirven mediante la API para que funcionen en el emulador sin configurar enlaces de almacenamiento.

- [ ] Revisar las categorías que se muestran al cliente y reemplazar las opciones fijas por categorías administrables desde el panel de administración.
- [ ] Permitir que Ronald agregue categorías desde el administrador.
- [ ] Cuando un restaurante solicite una categoría nueva, Ronald podrá revisarla y agregarla desde el administrador. No se ha acordado crear un flujo de solicitudes dentro de la app.
- [ ] Cargar esas categorías en el perfil del restaurante para que pueda utilizar las opciones disponibles. Definir primero cómo se seleccionan y se relacionan con cada establecimiento.
- [ ] Aclarar si estas categorías describen restaurantes o tipos de comida, y distinguirlas de las categorías internas del menú de cada restaurante antes de cambiar modelos o datos existentes.

## Pedidos que el restaurante no acepta

Problema observado: existen pedidos de prueba que siguen pendientes durante días porque el restaurante no los aceptó.

- [ ] Revisar si existe actualmente un vencimiento de pedidos pendientes y por qué permanecen abiertos.
- Implementación en la rama `titi/feature/vencimiento-pedidos`: plazo acordado de 5 minutos para pedidos nuevos, motivo de cancelación, bloqueo de aceptación tardía y scheduler cada 10 segundos. Pendiente ejecutar migración y pruebas. Los pedidos anteriores conservan plazo nulo y no se cancelan automáticamente.
- [ ] Acordar el tiempo máximo de espera antes de cancelar automáticamente un pedido sin respuesta. El plazo todavía no está definido.
- [ ] Definir desde qué momento se cuenta el plazo y qué sucede si el restaurante intenta aceptar justo cuando vence.
- [ ] Mostrar al cliente y al restaurante el vencimiento y el motivo de cancelación, conservando el historial.
- [ ] Evaluar que el tiempo de espera sea configurable desde el administrador.
- [ ] Revisar el efecto sobre cobros, propinas y ganancias: un pedido vencido no debe contarse como una entrega completada.
- [ ] Acordar cómo tratar los pedidos antiguos de prueba antes de actualizar datos. No borrar ni cancelar pedidos existentes automáticamente por crear esta lista.
- [ ] Probar el vencimiento, la aceptación antes del límite y la ausencia de acciones o notificaciones duplicadas.

## Restaurante: siguiente revisión

- [ ] Logo del negocio en Mi local: revisar carga, edición y visualización; por ahora conservar la inicial del restaurante.

- [x] Revisar y mejorar Pedidos y Mi menú del restaurante.
- [ ] Proponer mejoras visuales consistentes con Toro Go y mostrarlas antes de implementar.
- [x] Mejorar Mi local y configurar preparación entre 10 y 45 minutos.
- [ ] Validar el historial del restaurante: filtros por estado y período, paginación, detalle y aislamiento entre cuentas.

## Estimación de entrega completa

- [ ] El tiempo mostrado actualmente proviene de preparación del local. Incorporar recorrido y disponibilidad del motorista al estimar la entrega completa, sin sumar tiempos dos veces.
- [ ] El aumento de Muy ocupado se mantiene en 50%, con un techo de 45 minutos de preparación; evaluar más adelante su configuración desde el administrador.

## Etapa posterior

- [ ] Pagos con tarjeta.
- [ ] Chat vinculado a pedidos con permisos y privacidad.
- [ ] Favoritos y reseñas.

La prioridad sigue siendo terminar y validar el delivery de comida. Mantener la paleta, tipografía y tema actuales; discutir nuevas dependencias, cambios de backend y decisiones arquitectónicas antes de implementarlos.
