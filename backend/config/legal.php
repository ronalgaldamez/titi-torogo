<?php

return [
    'responsible' => 'Francisco Ronal Galdamez Funes',
    'reviewed_at' => '24/10/2026',
    'pages' => [
        'privacidad' => [
            'title' => 'Privacidad',
            'description' => 'Cómo se utilizan los datos personales en ToroGo y cómo contactarnos.',
            'sections' => [
                'Qué datos utilizamos' => [
                    'Al crear una cuenta se registran tu nombre, correo y contraseña protegida mediante hash. También se utiliza tu teléfono si lo proporcionás. Los motoristas tienen información de vehículo y contacto.',
                    'Para gestionar entregas se guardan direcciones, referencias y coordenadas. Cada pedido conserva una copia de la dirección, los productos, notas, importes, propina, restaurante, motorista asignado y fechas de sus estados. Cambiar tu dirección guardada no modifica pedidos anteriores.',
                    'El funcionamiento del servicio también puede generar información de sesión, dispositivo, dirección IP y registros técnicos. Al escribirnos, tratamos la información que incluyas en tu consulta. No envíes contraseñas ni datos innecesarios.',
                ],
                'Para qué se utilizan' => [
                    'Para gestionar cuentas, comprobar cobertura, tramitar pedidos, coordinar entregas, mostrar su seguimiento privado, atender incidencias y proteger el servicio. La visita a esta página no se interpreta como autorización general para publicidad ni otros usos ajenos a esas finalidades.',
                ],
                'Ubicación durante las entregas' => [
                    'La app solicita los permisos de ubicación necesarios. El motorista asignado puede compartir su posición durante una entrega activa, incluso con la pantalla bloqueada mientras el seguimiento esté funcionando. El cliente del pedido puede consultar esa posición cuando corresponde.',
                    'El backend conserva la última posición en caché hasta dos minutos y no crea un historial GPS del recorrido. Al finalizar la entrega deja de estar disponible para su seguimiento. Esto no borra el registro del pedido, su dirección ni necesariamente los registros técnicos o respaldos.',
                ],
                'Quién puede acceder y servicios externos' => [
                    'El acceso se limita según la cuenta y sus funciones: el cliente consulta sus pedidos, el restaurante los de su negocio y el motorista asignado los datos necesarios para la entrega. El personal autorizado del operador administra el servicio. La lista compartida de pedidos disponibles no expone la dirección completa a todos los motoristas.',
                    'La web carga tipografías de Google Fonts y la app utiliza mapas de OpenStreetMap. Al solicitar estos recursos se establecen conexiones con terceros, que pueden recibir datos técnicos como la dirección IP. Los mensajes enviados al correo de soporte se tramitan mediante el proveedor de correo.',
                    'Pendiente antes del lanzamiento: identificar proveedores de alojamiento, países de tratamiento, encargados y garantías de las transferencias que correspondan. No se afirma que todos los datos permanezcan dentro de El Salvador.',
                ],
                'Conservación y seguridad' => [
                    'La información debe conservarse según la finalidad y las obligaciones aplicables. La última posición GPS tiene el plazo técnico indicado; para cuentas, pedidos, reclamos, registros y respaldos todavía falta definir y aplicar una política completa de retención. No se promete eliminación automática inmediata.',
                    'Se utilizan controles de acceso y contraseñas protegidas mediante hash. Antes del lanzamiento deben completarse la configuración de HTTPS, los respaldos y los procedimientos de seguridad. Ningún sistema se presenta como absolutamente seguro.',
                ],
                'Tus derechos y solicitudes' => [
                    'Podés solicitar acceso, rectificación, cancelación, oposición, portabilidad, olvido o limitación de tus datos, según corresponda. Escribí al contacto de esta página, indicá la cuenta y explicá tu solicitud. Te orientaremos sobre los requisitos y la comprobación de identidad necesaria; no envíes tu contraseña.',
                    'El texto legal consultado prevé respuesta a solicitudes de derechos en veinte días hábiles, con prórroga justificada de hasta otros veinte. Las obligaciones de conservación pueden limitar la eliminación de ciertos registros y deben explicarse. La baja de cuenta y el procedimiento operativo completo están pendientes de finalizar.',
                ],
            ],
        ],
        'terminos' => [
            'title' => 'Términos y condiciones',
            'description' => 'Cobertura, pagos, cancelaciones y atención de problemas en ToroGo.',
            'sections' => [
                'El servicio y su estado actual' => [
                    'ToroGo conecta clientes, restaurantes y motoristas para tramitar pedidos. Los restaurantes preparan los productos y el motorista asignado realiza la entrega. Esta distribución de funciones no excluye las responsabilidades legales que correspondan.',
                    'La landing presenta el proyecto. Los pedidos desde el navegador y la publicación de las apps en tiendas están en preparación; esta página no anuncia que ya estén disponibles.',
                ],
                'Dónde entregamos' => [
                    'La cobertura se limita a las zonas activas que incluyan la dirección de entrega en Chalatenango, El Salvador. El mapa inicial del proyecto corresponde a una zona denominada Tejutla. Esto no significa cobertura de todo el municipio ni de todo el departamento. La disponibilidad depende de la dirección y del restaurante.',
                ],
                'Cuenta, precios y pago' => [
                    'Proporcioná información correcta y protegé tus credenciales. Antes de confirmar un pedido se muestran los productos, el envío, la propina cuando corresponda y el total en dólares estadounidenses.',
                    'El sistema actual utiliza efectivo al recibir y no procesa tarjetas. Este documento no introduce multas, penalizaciones ni cargos adicionales.',
                ],
                'Aceptación y cancelación desde la app' => [
                    'El pedido queda pendiente de aceptación del restaurante. El cliente puede cancelarlo desde el seguimiento antes de que sea aceptado. Si el restaurante no responde dentro de cinco minutos desde su creación, el pedido vence y se cancela al comprobar el plazo o al ejecutarse el proceso automático. La pantalla puede depender de la conexión para actualizarse.',
                    'Después de la aceptación, el botón de cancelación deja de estar disponible. Podés solicitar ayuda al correo indicado. Esta limitación de la interfaz no elimina los derechos que correspondan ni significa que toda solicitud deba rechazarse.',
                ],
                'Entrega y problemas con un pedido' => [
                    'Los tiempos informados son estimaciones. Si el pedido no llega, está incompleto, es incorrecto o presenta un problema de calidad, contactanos con su número y una descripción. Las fotografías relevantes pueden ayudar; evitá compartir datos innecesarios. No se fija aquí un plazo breve que extinga tus derechos.',
                    'Propuesta pendiente de confirmación operativa: revisar el caso con el restaurante y el motorista y coordinar corrección, reposición o devolución cuando corresponda. Si ya hubo pago en efectivo, la forma de reintegro se acuerda y registra; no existe devolución automática en la app ni se impone un cupón como única solución.',
                    'No se promete atención permanente ni resolución inmediata. Antes del lanzamiento deben definirse el horario, los responsables y el procedimiento de reclamos. Podés acudir a la Defensoría del Consumidor y ejercer los derechos aplicables.',
                ],
                'Puntos pendientes antes del lanzamiento' => [
                    'Completar domicilio de atención, condiciones de contratación, restricciones de edad y productos regulados, horarios y procedimiento de incidentes. Este borrador no autoriza la venta de productos regulados ni certifica cumplimiento legal.',
                ],
            ],
        ],
        'cookies' => [
            'title' => 'Cookies y almacenamiento',
            'description' => 'Información sobre sesiones, cookies, recursos externos y almacenamiento de ToroGo.',
            'sections' => [
                'Qué son las cookies' => [
                    'Son información que un sitio puede guardar en tu navegador. Ayudan, por ejemplo, a mantener una sesión o proteger formularios. No equivalen a los permisos GPS del teléfono.',
                ],
                'Sesión y protección de formularios' => [
                    'La web utiliza sesiones Laravel. Su cookie identifica la sesión para funciones del sitio y del panel de administración. El nombre depende de la configuración del despliegue. La configuración local revisada establece 120 minutos de inactividad; el nombre y la duración efectivos deben verificarse en el servidor publicado.',
                    'Laravel puede establecer XSRF-TOKEN para protección de formularios frente a solicitudes falsificadas. Su presencia y vencimiento exactos deben comprobarse en las respuestas del entorno final.',
                ],
                'Analítica, publicidad y terceros' => [
                    'No se identificaron Google Analytics, Meta Pixel ni Hotjar en el código revisado de la landing. Esto no sustituye la comprobación del navegador y del entorno publicado.',
                    'La web solicita fuentes de Google Fonts. Estas solicitudes externas pueden comunicar información técnica de conexión y deben revisarse; no se describen automáticamente como cookies publicitarias. La app carga mapas de OpenStreetMap.',
                ],
                'Almacenamiento de la app' => [
                    'La app utiliza almacenamiento local para sesión, carrito e intentos de pedido. Sus permisos de ubicación se administran desde el dispositivo. Las opciones de cookies de la web no modifican esos permisos ni borran los datos locales de la app.',
                ],
                'Tus opciones' => [
                    'Podés administrar las cookies desde tu navegador. Bloquear las necesarias puede impedir funciones de sesión o formularios. El panel de preferencias de ToroGo todavía es informativo: no guarda consentimiento ni permite activar o desactivar categorías.',
                    'Antes de incorporar herramientas opcionales se revisarán los requisitos aplicables y los controles necesarios. No se muestra un botón de aceptación que simule bloquear herramientas que no controla.',
                ],
                'Inventario pendiente de verificación' => [
                    'Antes del lanzamiento se comprobarán las cookies efectivas, sus nombres, finalidades, proveedores y vencimientos. Esta versión distingue la configuración local revisada del comportamiento que tendrá el servidor definitivo.',
                ],
            ],
        ],
    ],
];
