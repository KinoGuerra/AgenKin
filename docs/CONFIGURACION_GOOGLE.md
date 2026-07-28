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
- `https://www.googleapis.com/auth/calendar.app.created`, para crear un calendario secundario **Agenda** y administrar solamente sus eventos.

Gmail y Calendar se autorizan con botones separados y cada solicitud incluye
solamente el permiso del servicio elegido. Ambos deben usar la misma cuenta
Google; para cambiar de cuenta hay que usar primero **Revocar acceso de Google**.

`gmail.readonly` es un permiso restringido. Una publicación abierta puede requerir verificación de Google y, si los datos restringidos pasan por un servidor, una evaluación de seguridad. Revisar los requisitos oficiales antes de salir de Testing.

## 3. Clientes OAuth

Se necesitan dos flujos OAuth independientes. Pueden usar el mismo cliente web durante el MVP si se registran ambos callbacks, aunque separar los clientes por entorno simplifica la rotación futura.

Registrar:

- Orígenes JavaScript: `https://kinoguerra.github.io`, `http://localhost:5173` y `http://127.0.0.1:5173`.
- Callback de Supabase Auth para el ingreso: `https://kpqzwbhprqlapwhadejt.supabase.co/auth/v1/callback`.
- Callback de Edge Function para Gmail y Calendar: `https://kpqzwbhprqlapwhadejt.supabase.co/functions/v1/google-oauth-callback`.

El callback de Supabase Auth vuelve luego a `auth-callback.html`; el callback de la Edge Function vuelve al portal. No intercambiar esas URLs.

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
2. Configurar el Client ID y Client Secret del cliente web y habilitar el proveedor.
3. En URL Configuration agregar:
   - `http://localhost:5173/AgenKin/auth-callback.html`
   - `https://kinoguerra.github.io/AgenKin/auth-callback.html`

La autorización de Gmail/Calendar es una segunda conexión gestionada por las
Edge Functions, independiente del inicio de sesión y separada por servicio.
