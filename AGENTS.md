# AGENTS.md — AgenKin

## Objetivo

AgenKin detecta fechas importantes en cuentas Gmail autorizadas, las guarda
primero en su Agenda interna y, si el usuario lo habilita, replica eventos en
un único Google Calendar. La beta admite varias cuentas Gmail por usuario,
sin cupo comercial de mensajes, y creación automática solamente para
hallazgos futuros, confiables y autorizados por reglas personales.

## Stack y rutas

- Vite multipágina con JavaScript ES, HTML semántico y CSS responsive.
- Sin React ni router; cada destino tiene su propio HTML.
- Supabase Auth, PostgreSQL, RLS, Cron y Edge Functions con Deno.
- GitHub Pages bajo el base path `/AgenKin/`.
- Vitest y ESLint para validación local.

Rutas principales:

- `index.html`: landing y login.
- `app.html`: dashboard del usuario.
- `correos.html`, `vencimientos.html`, `agenda.html`, `reglas.html` y
  `configuracion.html`: subpáginas del portal.
- `access.html`: selector exclusivo del superadministrador.
- `admin.html`: administración.
- `src/services/supabase.js`: único cliente Supabase del frontend.
- `supabase/migrations/`: esquema, funciones, permisos y RLS.
- `supabase/functions/`: administración, OAuth y workers.
- `supabase/functions/_shared/`: Gmail, Calendar, IA y procesamiento compartido.

## Modelo multicuenta

- Cada plan limita cuentas Gmail activas: 1, 2, 3 o 5; no limita mensajes.
- `AgenKin` es un plan interno equivalente a Pro y solo lo asigna un
  superadministrador.
- Una conexión se identifica por `usuario_id + google_subject_id`.
- Correos y tareas se deduplican por
  `conexion_google_id + gmail_message_id`.
- Calendar solo puede activarse sobre una Gmail conectada y solo una conexión
  puede ser el Calendar principal de cada usuario.
- Agenda es la fuente principal. Un fallo o desconexión de Google no puede
  eliminar ni impedir el evento interno.
- El modo automático/manual se aplica a todas las Gmail activas del usuario.

## Restricciones de la beta Free

- Diseñar para hasta 25 usuarios activos y 125 cuentas conectadas.
- Usar jobs globales: nunca crear un cron por usuario o por cuenta.
- Gmail usa History incremental. La importación inicial toma como máximo los
  últimos 90 días; después se procesan todos los cambios nuevos sin cupo de
  mensajes.
- El descubridor reclama como máximo 40 cuentas, concurrencia 4 y presupuesto
  de 120 segundos.
- El worker procesa como máximo 20 tareas, concurrencia 4, y no inicia otro
  grupo cuando quedan menos de 65 segundos.
- No encadenar Edge Functions por correo o evento; reutilizar módulos internos.
- La cola conserva trabajo pendiente cuando falta capacidad.
- Alertar desde 350 MB y detener solo cargas históricas desde 425 MB.
- Recomendar Supabase Pro al superar 25 usuarios, sostener una cola de más de
  30 minutos, proyectar más de 350.000 invocaciones o necesitar garantías.

## Reglas de implementación

- Escribir interfaz y documentación en español.
- Mantener la solución más simple que cubra el requisito.
- No agregar React, frameworks, dependencias o abstracciones sin necesidad real.
- No usar datos simulados en producción ni botones que aparenten funcionar.
- Mostrar estados claros de carga, error, éxito, vacío o configuración requerida.
- Mantener accesibilidad básica, contraste, teclado, movimiento reducido y móvil.
- No insertar datos externos mediante `innerHTML`; usar `textContent` y nodos DOM.
- Paginar correos de 25 en 25 y consultar progreso solo durante una sincronización.

## Seguridad e integridad

- Nunca exponer secretos, tokens OAuth ni `SUPABASE_SERVICE_ROLE_KEY`.
- Ningún secreto puede usar el prefijo `VITE_`.
- Validar identidad desde el JWT; nunca confiar en correos o UUID enviados por
  el frontend sin volver a comprobar propiedad.
- Mantener RLS activa en tablas expuestas y evitar lecturas cruzadas.
- Las RPC `SECURITY DEFINER` deben fijar `search_path`, validar al usuario y
  revocar `EXECUTE` de `PUBLIC`, `anon` y roles que no correspondan.
- Ejecutar acciones administrativas sensibles mediante Edge Functions, exigir
  AAL2 y auditarlas.
- Cifrar refresh tokens; no mostrarlos, registrarlos ni conservarlos cuando ya
  no existe ninguna integración local activa.
- No asignar automáticamente `superadministrador`.
- Las transiciones sensibles, como descartar un vencimiento, deben usar una RPC
  con propiedad y estado validados, no un `UPDATE` abierto desde el navegador.
- Mantener atómicas e idempotentes las escrituras de correo, vencimiento y
  métricas. Registrar evidencias de patrones solo después de esa confirmación.

## Correo, patrones e IA

- Gmail se usa únicamente con `gmail.readonly`.
- No almacenar cuerpos completos ni adjuntos.
- Extraer localmente fechas, importes, entidades y acciones.
- Enviar a IA solo líneas relevantes, sanitizadas y limitadas a 3.000 caracteres.
- Resolver en orden: regla personal, patrón verificado y finalmente IA.
- Aprender patrones únicamente de remitentes autenticados; los patrones son
  selectores declarativos, nunca XPath, expresiones o código ejecutable.
- Una discrepancia o corrección devuelve el patrón a observación.
- Las limitaciones de Groq difieren solo los correos que necesitan IA.
- Nunca incluir cuerpos, prompts, respuestas, tokens ni PII en logs.

## Retención

- Detalle con vencimiento: hasta 15 días después de la fecha.
- Sin vencimiento, ignorado o irrelevante: compactar a los 30 días.
- Tombstone antirrepetición: conservar hasta 120 días.
- Agenda y vencimientos: eliminar 15 días después de vencer, sin borrar Google.
- Tareas completadas: 48 horas; tareas fallidas: 30 días.
- Patrones personales no activos y sin cambios: eliminar a los 90 días.
- Conservar métricas mensuales antes de compactar.
- La limpieza puede iterar, pero cada sentencia debe operar lotes de hasta 1.000.

## Validación

Antes de entregar:

```bash
npm run lint
npm run test
npm run build
```

Para cada Edge Function modificada:

```bash
npx --yes deno check supabase/functions/<funcion>/index.ts
```

También revisar:

- migración en seco, advisors, permisos y RLS con dos usuarios;
- callbacks simultáneos, reconexión y cupos de cuenta;
- dos cuentas con el mismo Gmail message ID;
- consola, enlaces, base path, móvil, claro/oscuro y teclado;
- ausencia de secretos y tamaño de tablas/índices.

## Git y publicación

- No hacer commit, push, despliegue ni cambios remotos sin autorización explícita.
- No sobrescribir cambios ajenos ni usar comandos Git destructivos.
- Publicar en este orden: pausar crons si la migración cambia contratos,
  aplicar migración, desplegar Edge Functions, ejecutar smoke tests, reanudar
  crons y por último publicar el frontend.
- El workflow de Pages debe conservar `npm ci`, lint, pruebas y build.
- Los permisos `pages: write` e `id-token: write` pertenecen solo al job de deploy.
- GitHub Pages requiere habilitación previa; no cambiar visibilidad sin permiso.
