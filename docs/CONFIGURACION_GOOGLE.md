# Configuración de Google

## 1. Proyecto y APIs

1. Crear o elegir un proyecto en Google Cloud Console.
2. Habilitar **Gmail API** y **Google Calendar API**.
3. Configurar la pantalla de consentimiento OAuth con el nombre AgenKin, dominio, política de privacidad y términos publicados.
4. Agregar los usuarios de prueba mientras la aplicación esté en modo Testing.

## 2. Permisos

AgenKin solicita los permisos adicionales únicamente desde el portal:

- `openid` y `email`, para identificar la cuenta conectada.
- `https://www.googleapis.com/auth/gmail.readonly`, para leer correos sin modificarlos.
- `https://www.googleapis.com/auth/calendar.app.created`, para crear un calendario secundario AgenKin y administrar solamente sus eventos.

`gmail.readonly` es un permiso restringido. Una publicación abierta puede requerir verificación de Google y, si los datos restringidos pasan por un servidor, una evaluación de seguridad. Revisar los requisitos oficiales antes de salir de Testing.

## 3. Cliente OAuth

Crear un cliente de tipo **Aplicación web** y registrar exactamente:

- Origen del frontend: `https://kinoguerra.github.io`
- Callback de Edge Function: `https://kpqzwbhprqlapwhadejt.supabase.co/functions/v1/google-oauth-callback`

En desarrollo, agregar los orígenes locales necesarios. El callback de Google siempre debe apuntar a la Edge Function, nunca al navegador.

## 4. Secretos

Configurar con Supabase CLI:

```bash
supabase secrets set \
  GOOGLE_CLIENT_ID="..." \
  GOOGLE_CLIENT_SECRET="..." \
  GOOGLE_REDIRECT_URI="https://kpqzwbhprqlapwhadejt.supabase.co/functions/v1/google-oauth-callback" \
  APP_PUBLIC_URL="https://kinoguerra.github.io/AgenKin/"
```

No copiar estos valores a `.env`, a variables `VITE_*` ni al código.

## 5. Supabase Auth

El primer inicio de sesión usa el proveedor Google de **Supabase Auth** y solicita solo perfil básico. En Supabase:

1. Authentication → Providers → Google.
2. Configurar el cliente destinado a Supabase Auth.
3. En URL Configuration agregar:
   - `http://localhost:5173/AgenKin/auth-callback.html`
   - `https://kinoguerra.github.io/AgenKin/auth-callback.html`

La autorización de Gmail/Calendar es una segunda conexión independiente gestionada por las Edge Functions.
