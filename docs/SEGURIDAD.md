# Seguridad de AgenKin

## Límites de confianza

- El frontend no decide roles, identidad, suscripción ni cupos.
- Supabase obtiene la identidad desde el JWT.
- RLS protege las consultas propias.
- Las cuentas suspendidas o bloqueadas pierden acceso en RLS, no solo en la interfaz.
- Las operaciones administrativas y de Google usan Edge Functions.
- La administración exige un JWT con nivel de autenticación `aal2`.
- La función SQL administrativa verifica el rol, bloquea el auto-bloqueo, actualiza y audita dentro de una transacción.
- Las conexiones, correos, tareas y eventos validan que el usuario y la cuenta
  Google pertenezcan al mismo propietario.
- Las transiciones sensibles se exponen mediante RPC acotadas; el frontend no
  recibe permiso para modificar libremente columnas de seguridad.

## Tokens y secretos

El refresh token de Google se cifra con AES-256-GCM. `TOKEN_ENCRYPTION_KEY` debe contener 32 bytes aleatorios codificados en base64:

```bash
openssl rand -base64 32
```

Guardar el resultado solo como Supabase Secret. La rotación requiere descifrar y volver a cifrar los tokens existentes o desconectar las cuentas.

Cada cuenta Google tiene su propio token cifrado. Al desactivar la última
integración local se elimina la copia del token; “Revocar acceso” también
solicita la revocación a Google.

Secretos requeridos:

- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_REDIRECT_URI`
- `TOKEN_ENCRYPTION_KEY`
- `APP_PUBLIC_URL`
- `AI_PROVIDER`
- `AI_API_KEY`
- `AI_MODEL`
- `AI_API_URL`
- `AI_TIMEOUT_MS`

`SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` son inyectados por Supabase en las funciones. La clave `service_role` nunca debe salir de ese entorno.

## Correo e IA

- Gmail se abre en modo de solo lectura.
- No se registran tokens ni cuerpos en logs.
- Groq se invoca desde el worker global mediante el módulo compartido de
  procesamiento; nunca desde `scan-gmail` ni desde el navegador.
- La clave de Groq vive únicamente en Supabase Secrets y nunca usa prefijo `VITE_`.
- Se envían únicamente asunto, dominio del remitente, fecha, candidatos
  estructurados y un fragmento sanitizado.
- Antes del envío se redactan direcciones de correo, secuencias numéricas largas,
  URLs y credenciales reconocibles.
- No se envían tokens OAuth, identificadores internos, roles, datos de
  suscripción, adjuntos, HTML completo ni historial innecesario.
- El asunto se limita a 500 caracteres, el fragmento a 1.200 y cada contexto de
  candidato a 240.
- El cuerpo plano se limita antes de normalizarse, se sanitiza y no se persiste.
- La base conserva identificadores, remitente, asunto, categoría y resultado
  estructurado solamente durante el período de retención correspondiente.
- El JSON Schema estricto se complementa con validación local de categorías,
  tipos, confianza, fecha, hora, zona horaria, coherencia y longitudes.
- Los correos se deduplican por
  `conexion_google_id + gmail_message_id`; el mismo ID en dos cuentas distintas
  no colisiona. Cada correo puede generar como máximo un vencimiento.
- Una huella funcional adicional combina tipo, entidad, fecha, hora, monto,
  referencia explícita, asunto normalizado y plantilla. Sólo se calcula cuando
  existe una referencia; un bloqueo transaccional impide duplicar el mismo
  compromiso reciente entre cuentas sin fusionar cuotas o turnos parecidos.
- El orden de resolución es regla personal, patrón verificado, clasificación
  local segura y finalmente IA.
- Los patrones se aprenden solo de remitentes autenticados, son selectores
  declarativos y vuelven a observación ante discrepancias o correcciones.
- La validación de patrones es determinística: 15% al inicio, 5% en estabilidad,
  2% para patrones muy estables y 100% tras una discrepancia reciente.
- La automatización requiere un plan habilitado y una regla personal
  `Priorizar`; la confianza del modelo no reemplaza la confianza del remitente.
- La creación automática se limita a veinte eventos diarios por usuario.
- No existe cupo comercial de correos. Un fallo transitorio de Gmail, Google o
  IA conserva la tarea para reintento sin perder el cursor.
- Los logs técnicos incluyen solamente proveedor, modelo, duración, estado HTTP,
  intentos, código interno y conteos de tokens cuando existen.
- Verificar las condiciones de tratamiento y retención del proveedor antes de habilitarlo.

Los errores enviados al frontend están normalizados y nunca incluyen el cuerpo,
la respuesta cruda del proveedor, headers, claves ni detalles de infraestructura.
La configuración operativa está en
[Configuración de Groq](CONFIGURACION_GROQ.md).

## OAuth

- `state` tiene entropía criptográfica, se almacena como hash, vence en diez minutos y es de un solo uso.
- El estado vincula usuario, servicio y, para Calendar, la conexión Gmail elegida.
- Cada usuario puede conectar varias cuentas Gmail hasta el límite del plan.
- Calendar solo puede autorizarse con una Gmail ya conectada y existe un único
  Calendar principal por usuario.
- El cupo se comprueba dentro de la transacción del callback, también al
  reactivar una conexión existente.
- Solo se conserva un intento pendiente por usuario y servicio; los estados
  vencidos o utilizados se eliminan por mantenimiento.
- Las URLs de aplicación y callback deben usar HTTPS, salvo localhost.
- El callback nunca agrega tokens a la redirección.

## Retención y capacidad

- La importación inicial de Gmail revisa hasta 90 días. Después, Gmail History
  incorpora todos los cambios nuevos sin cupo comercial; el exceso de capacidad
  permanece en cola.
- El detalle con vencimiento se conserva hasta 15 días después de vencer.
- Los correos sin vencimiento se compactan a los 30 días.
- El registro mínimo antirrepetición se conserva hasta 120 días.
- Los eventos internos y vencimientos se eliminan 15 días después de vencer;
  esa limpieza por retención no elimina eventos ya creados en Google Calendar.
- Un descarte explícito sí oculta el evento interno y encola la eliminación
  idempotente del evento creado por AgenKin en Google Calendar.
- Las tareas completadas se eliminan a las 48 horas y las fallidas a los 30 días.
- Los patrones personales no activos y sin cambios se eliminan a los 90 días.
- Las métricas mensuales se conservan antes de compactar.
- El mantenimiento usa sentencias de hasta 1.000 filas y repite lotes para no
  quedar por debajo del volumen esperado.
- El panel alerta desde 350 MB y las cargas históricas se detienen desde 425 MB;
  la sincronización incremental continúa.

## Frontend y GitHub Pages

GitHub Pages no permite definir encabezados HTTP arbitrarios. Cada página
principal usa una política CSP mediante `<meta>` que restringe `connect-src` al
proyecto Supabase de AgenKin, una política de referer y un guardia temprano que
oculta la aplicación si se carga dentro de un marco. Este último es una
mitigación adicional, pero no reemplaza un encabezado `frame-ancestors`. Antes
de manejar operaciones de mayor riesgo, publicar el frontend detrás de un
servicio que permita encabezados CSP completos.

El código dinámico usa `textContent` y creación de nodos; no inserta datos externos con `innerHTML`.

## Despliegue seguro

Cuando cambian contratos entre SQL, Edge Functions y frontend:

1. Pausar los cron afectados.
2. Aplicar la migración y verificar advisors/RLS.
3. Desplegar las Edge Functions y ejecutar pruebas de humo.
4. Reanudar cron.
5. Publicar el frontend al final.

## Respuesta a incidentes

1. Deshabilitar las funciones afectadas.
2. Rotar las credenciales implicadas.
3. Revocar conexiones Google cuando corresponda.
4. Revisar `auditoria_administrativa` y errores recientes sin copiar datos sensibles.
5. Notificar a las personas afectadas conforme a la normativa aplicable.

Para una clave de Groq expuesta: revocarla en Groq, crear una nueva, actualizar
`AI_API_KEY` en Supabase Secrets y revisar el uso reciente sin copiar contenido
de correos a los registros del incidente.
