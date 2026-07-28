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

La primera migración crea tipos, tablas, índices, triggers, funciones, permisos y políticas RLS. La segunda contiene la promoción manual del propietario: reemplazar `REEMPLAZAR_EMAIL_SUPERADMIN` por el correo real después de que esa persona haya iniciado sesión al menos una vez y volver a ejecutar solo esa instrucción desde SQL Editor.

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

Antes de desplegar `scan-gmail`, configurar Groq según
[Configuración de Groq](CONFIGURACION_GROQ.md). La API key debe existir
únicamente como Supabase Secret.

## Activar la sincronización programada

La última migración habilita Cron, Queues y `pg_net`, y programa cuatro trabajos:
descubrir cambios de Gmail cada 5 minutos, procesar su cola cada minuto, crear
eventos elegibles cada 2 minutos y reintentar la réplica de Agenda a Google
Calendar cada minuto.

Antes de aplicar esa migración:

1. Generar un valor aleatorio largo para `CRON_SECRET`.
2. Guardarlo como Edge Function Secret con ese nombre.
3. Guardar el mismo valor en Vault con el nombre `agenkin_cron_secret`.
4. Guardar `https://kpqzwbhprqlapwhadejt.supabase.co` en Vault con el nombre
   `agenkin_project_url`.

Ingresar esos valores desde el Dashboard de Supabase; no escribir el secreto en
archivos, historial de shell, migraciones ni logs. La automatización permanece
desactivada por usuario hasta que este la habilita desde el portal.

## Variables públicas

El navegador solo usa:

```env
VITE_SUPABASE_URL=https://kpqzwbhprqlapwhadejt.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_RYsbufUA91Oy-cmI4bZD4Q_Q54aE9KL
```

Son valores públicos y reemplazables. Nunca configurar una clave `service_role` con prefijo `VITE_`.

## Verificación rápida

1. Crear un usuario con Google.
2. Confirmar que existen `perfiles` y `suscripciones`.
3. Confirmar rol `usuario`, estado `activo` y una prueba con vencimiento a 15 días.
4. Ejecutar consultas desde otro JWT y verificar que RLS no expone filas ajenas.
