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
- `https://www.googleapis.com/auth/calendar.calendarlist`, para dejar **Agenda**
  visible y seleccionada en la interfaz de Google Calendar.

Gmail y Calendar se autorizan con botones separados y cada solicitud incluye
solamente el permiso del servicio elegido. El usuario puede conectar varias
cuentas Gmail diferentes hasta el límite de su plan. Calendar debe autorizarse
con la misma identidad Google de la cuenta Gmail que el usuario seleccionó como
Calendar principal.

Calendar no consume un espacio Gmail. Todas las cuentas fuente escriben primero
en una única Agenda interna; el único Calendar principal replica esos eventos.
Una desconexión o error de Google no elimina el compromiso interno.
Las conexiones Calendar existentes deben usar una vez **Volver a autorizar
Calendar** después de agregar `calendar.calendarlist`; la autorización conserva
el calendario y sus eventos y sólo corrige su visibilidad en Google.

Gmail History es el flujo normal. Como defensa ante cursores vencidos o huecos,
AgenKin recorre una vez por día los últimos siete días con un cursor separado y
100 IDs por página. La reparación es idempotente y nunca reinicia la carga de 90
días.

La cola de Calendar admite `crear` y `eliminar`. Si el usuario descarta un
evento autoagendado, AgenKin lo oculta primero en su Agenda y solicita después
`events.delete` sobre el evento que creó en el calendario secundario. Google
`404` se considera éxito idempotente; los errores temporales quedan para
reintento. El alcance `calendar.app.created` no permite administrar eventos
ajenos a la aplicación.

Cambiar el Calendar principal no mueve eventos ya creados: los eventos futuros
y pendientes se envían a la nueva cuenta y Agenda sigue siendo la fuente
interna.
El programador reconstruye tareas faltantes de eventos futuros sin
`google_event_id` cuando vuelve a existir un Calendar principal activo.

`gmail.readonly` es un permiso restringido. Una publicación abierta puede requerir verificación de Google y, si los datos restringidos pasan por un servidor, una evaluación de seguridad. Revisar los requisitos oficiales antes de salir de Testing.

## 3. Clientes OAuth

Se necesitan dos flujos OAuth independientes. Pueden usar el mismo cliente web
durante la beta si se registran ambos callbacks, aunque separar clientes por
entorno simplifica la rotación futura.

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

## 6. Comprobación multicuenta

1. Conectar dos Gmail distintas y verificar que consuman dos espacios del plan.
2. Elegir una de ellas para Calendar y completar OAuth con esa misma identidad.
3. Intentar Calendar con otra identidad y confirmar el rechazo.
4. Cambiar el Calendar principal y comprobar que los eventos ya sincronizados
   permanezcan en el anterior.
5. Desactivar la cuenta usada por Calendar y confirmar que primero exija elegir
   otra o desactivar Calendar.
6. Probar callbacks simultáneos cuando quede un solo espacio disponible.
7. Crear un evento con Calendar activo y comprobar la secuencia `Google
   pendiente` → `Sincronizado con Google`.
8. Descartar ese evento y confirmar que desaparezca de Agenda y del calendario
   secundario sin afectar eventos creados por el usuario.

“Desactivar” detiene el servicio dentro de AgenKin. “Revocar acceso” solicita a
Google la revocación completa de los permisos de esa cuenta.
