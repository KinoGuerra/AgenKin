# Configuración de Supabase

## Requisitos

- Cuenta y proyecto Supabase.
- Supabase CLI autenticada.
- Docker, solo si se usa el entorno local completo de Supabase.

## Enlazar el proyecto

```bash
supabase login
supabase link --project-ref kpqzwbhprqlapwhadejt
```

## Aplicar la base

```bash
supabase db push
```

Las migraciones crean tipos, tablas, índices, triggers, funciones, permisos,
RLS, conexiones multicuenta y workers globales. La promoción del propietario
es manual: ejecutar la instrucción correspondiente después de que esa persona
haya iniciado sesión al menos una vez. Nunca guardar su correo en una migración
publicada.

## Desplegar funciones

```bash
supabase functions deploy admin-manage-user
supabase functions deploy google-oauth-start
supabase functions deploy google-oauth-callback --no-verify-jwt
supabase functions deploy google-disconnect
supabase functions deploy scan-gmail
supabase functions deploy create-calendar-event
supabase functions deploy sync-gmail-scheduled --no-verify-jwt
supabase functions deploy process-gmail-queue --no-verify-jwt
supabase functions deploy create-calendar-scheduled --no-verify-jwt
supabase functions deploy process-calendar-queue --no-verify-jwt
```

El callback OAuth es público porque Google no envía un JWT de Supabase. Su
seguridad depende de un `state` aleatorio, almacenado como hash, de uso único
y con vencimiento. Las cuatro funciones programadas tampoco validan JWT en el
gateway, pero rechazan toda llamada que no incluya el secreto interno de Cron.

Las funciones nuevas comparten módulos internos; una Edge Function no debe
invocar otra por cada correo o evento.

Antes de desplegar `scan-gmail`, configurar Groq según
[Configuración de Groq](CONFIGURACION_GROQ.md). La API key debe existir
únicamente como Supabase Secret.

## Activar la sincronización programada

La última migración usa Cron y `pg_net`, y programa cuatro trabajos globales:
descubrir cambios de Gmail cada 5 minutos, procesar la cola SQL cada minuto,
crear eventos elegibles cada 2 minutos y reintentar la réplica de Agenda a
Google Calendar cada minuto. No se crea un cron por usuario o cuenta.

Gmail mantiene un cursor History por conexión. La importación inicial revisa
hasta 90 días y avanza por páginas; después solo consulta cambios incrementales.
Las tareas SQL son la única fuente de verdad y se reparten circularmente entre
cuentas.

Antes de aplicar esa migración:

1. Generar un valor aleatorio largo para `CRON_SECRET`.
2. Guardarlo como Edge Function Secret con ese nombre.
3. Guardar el mismo valor en Vault con el nombre `agenkin_cron_secret`.
4. Guardar `https://kpqzwbhprqlapwhadejt.supabase.co` en Vault con el nombre
   `agenkin_project_url`.

Ingresar esos valores desde el Dashboard de Supabase; no escribir el secreto en
archivos, historial de shell, migraciones ni logs. La automatización permanece
activa por defecto y cada usuario puede pasar todas sus conexiones a modo manual
desde el portal.

## Límites de la beta Free

- Diseñar para un máximo inicial de 25 usuarios activos y 125 cuentas Gmail.
- El descubridor reclama hasta 40 cuentas con concurrencia 4 y 120 segundos.
- El worker procesa hasta 20 tareas con concurrencia 4.
- El panel alerta a partir de 350 MB.
- Desde 425 MB se detiene la carga histórica, no Gmail History incremental.
- El mantenimiento compacta y elimina en sentencias de hasta 1.000 filas,
  repitiendo lotes suficientes para superar la tasa diaria esperada.
- Migrar a Pro si la cola supera 30 minutos de forma sostenida, la proyección
  excede 350.000 invocaciones o se necesitan backups y disponibilidad garantizada.

## Variables públicas

El navegador solo usa:

```env
VITE_SUPABASE_URL=https://kpqzwbhprqlapwhadejt.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_RYsbufUA91Oy-cmI4bZD4Q_Q54aE9KL
```

Son valores públicos y reemplazables. Nunca configurar una clave `service_role` con prefijo `VITE_`.

## Verificación rápida

1. Ejecutar lint de base, advisors y revisar migraciones pendientes.
2. Crear dos usuarios y confirmar que RLS no expone filas cruzadas.
3. Confirmar rol `usuario`, estado `activo` y prueba de 15 días.
4. Probar IDs de Gmail iguales en conexiones distintas.
5. Probar reconexión y callbacks simultáneos al completar el cupo.
6. Verificar un único Calendar principal.
7. Simular compactación a 15/30 días, tombstones a 120 y limpieza de tareas.
8. Medir tablas e índices con `pg_total_relation_size`.

## Orden seguro de publicación

El frontend nuevo y las firmas RPC no son compatibles con el esquema anterior.
Cuando una versión cambia esos contratos:

1. Pausar los cron afectados.
2. Aplicar la migración y comprobar permisos/RLS.
3. Desplegar todas las Edge Functions y ejecutar pruebas de humo.
4. Reanudar cron.
5. Hacer commit y push para publicar GitHub Pages al final.

Un `db push --dry-run` enumera migraciones pendientes, pero no reemplaza la
ejecución real contra PostgreSQL ni los advisors.
