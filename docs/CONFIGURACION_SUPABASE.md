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
```

El callback es la única función pública porque Google no envía un JWT de Supabase. Su seguridad depende de un `state` aleatorio, almacenado como hash, de uso único y con vencimiento.

Antes de desplegar `scan-gmail`, configurar Groq según
[Configuración de Groq](CONFIGURACION_GROQ.md). La API key debe existir
únicamente como Supabase Secret.

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
