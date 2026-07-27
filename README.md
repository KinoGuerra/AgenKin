# AgenKin

**Del correo a tu agenda, automáticamente.**

AgenKin es un MVP SaaS que permite iniciar sesión con Google, conectar Gmail y Google Calendar por separado, analizar manualmente nuevos correos, detectar fechas con IA y crear eventos únicamente después de la confirmación del usuario.

## Estado del MVP

El frontend, la base, RLS y las Edge Functions están implementados. La landing y los portales cargan sin credenciales de Gmail, Calendar o IA; esas acciones muestran “Configuración requerida” hasta completar los secretos externos. No se incluyen datos simulados, cobros ni procesamiento continuo.

## Arquitectura

```text
GitHub Pages (Vite multipágina)
        │ Supabase JS + JWT
        ▼
Supabase Auth ── PostgreSQL + RLS
        │
        └── Edge Functions
              ├── administración transaccional
              ├── OAuth adicional de Google
              ├── lectura Gmail + clasificación IA
              └── creación confirmada en Calendar
```

Se eligió JavaScript multipágina sin React ni router: GitHub Pages sirve cada destino directamente, Vite comparte los módulos y las guardas, y no hay una capa de estado global que mantener.

## Estructura

```text
.
├── index.html, app.html, admin.html, access.html
├── auth-callback.html, cuenta-bloqueada.html
├── privacidad.html, terminos.html
├── src/
│   ├── components/       UI segura compartida
│   ├── config/           variables públicas
│   ├── guards/           autorización de rutas
│   ├── pages/            controladores por página
│   ├── services/         Supabase, Auth y Edge Functions
│   ├── styles/           estilos responsive
│   └── utils/            lógica pura validada
├── supabase/
│   ├── migrations/       esquema, RLS y promoción manual
│   └── functions/        funciones Deno y módulos compartidos
├── tests/                Vitest
├── docs/                 configuración y seguridad
└── .github/workflows/    validación y GitHub Pages
```

## Requisitos

- Node.js 22 o superior.
- npm 10 o superior.
- Supabase CLI para aplicar base y funciones.
- Proyecto Google Cloud para habilitar integraciones.
- Proveedor de IA con endpoint compatible con OpenAI Chat Completions y salida JSON.

## Inicio local

```bash
git clone https://github.com/KinoGuerra/AgenKin.git
cd AgenKin
copy .env.example .env
npm install
npm run dev
```

Abrir `http://localhost:5173/AgenKin/`. El base path `/AgenKin/` se usa también en desarrollo para detectar problemas antes del despliegue.

Variables públicas:

```env
VITE_SUPABASE_URL=https://kpqzwbhprqlapwhadejt.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=sb_publishable_RYsbufUA91Oy-cmI4bZD4Q_Q54aE9KL
```

Son una URL y clave publicable. No agregar secretos ni `SUPABASE_SERVICE_ROLE_KEY` a archivos `.env` del frontend.

## Base de datos y Supabase Auth

Seguir [Configuración de Supabase](docs/CONFIGURACION_SUPABASE.md). Resumen:

```bash
supabase login
supabase link --project-ref kpqzwbhprqlapwhadejt
supabase db push
```

La migración crea:

- perfiles con rol `usuario` y acceso `activo`;
- prueba automática por 15 días;
- planes Prueba, Básico y Profesional;
- consumos mensuales con unicidad por período;
- conexiones Google con campos cifrados;
- correos sin cuerpo completo;
- vencimientos, eventos, reglas y auditoría;
- índices, restricciones, triggers, funciones auxiliares y RLS.

En Supabase → Authentication → URL Configuration:

- Site URL local: `http://localhost:5173/AgenKin/`
- Redirect local: `http://localhost:5173/AgenKin/auth-callback.html`
- Redirect publicado: `https://kinoguerra.github.io/AgenKin/auth-callback.html`

Configurar Google como proveedor de Supabase Auth para el login básico.

## Crear el superadministrador

1. El propietario inicia sesión al menos una vez para crear su perfil.
2. Abrir `supabase/migrations/202607270002_promover_superadministrador.sql`.
3. Reemplazar `REEMPLAZAR_EMAIL_SUPERADMIN` por el correo real.
4. Ejecutar la instrucción desde Supabase SQL Editor.
5. No guardar ni publicar el correo si se prefiere mantenerlo fuera del repositorio.

Ninguna cuenta obtiene ese rol automáticamente.

## Google Cloud

Seguir [Configuración de Google](docs/CONFIGURACION_GOOGLE.md). Se necesitan Gmail API, Calendar API, una pantalla de consentimiento y un cliente OAuth web.

Callback:

```text
https://kpqzwbhprqlapwhadejt.supabase.co/functions/v1/google-oauth-callback
```

Permisos adicionales:

- `gmail.readonly`
- `calendar.app.created`

El login inicial no solicita estos permisos.

## IA y secretos

Configurar los secretos en Supabase, nunca en el frontend:

```bash
supabase secrets set \
  GOOGLE_CLIENT_ID="..." \
  GOOGLE_CLIENT_SECRET="..." \
  GOOGLE_REDIRECT_URI="https://kpqzwbhprqlapwhadejt.supabase.co/functions/v1/google-oauth-callback" \
  TOKEN_ENCRYPTION_KEY="BASE64_DE_32_BYTES" \
  APP_PUBLIC_URL="https://kinoguerra.github.io/AgenKin/" \
  AI_API_KEY="..." \
  AI_MODEL="modelo-compatible"
```

`AI_API_URL` es opcional; por defecto se usa un endpoint compatible con OpenAI en `https://api.openai.com/v1/chat/completions`. El modelo no está fijado en el código. Antes de usar otro proveedor, confirmar que acepte `response_format: {"type":"json_object"}` o adaptar `supabase/functions/_shared/ai.ts`.

Generar la clave de cifrado:

```bash
openssl rand -base64 32
```

Supabase inyecta `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` en sus funciones alojadas. No crear equivalentes `VITE_*`.

## Desplegar Edge Functions

```bash
supabase functions deploy admin-manage-user
supabase functions deploy google-oauth-start
supabase functions deploy google-oauth-callback --no-verify-jwt
supabase functions deploy google-disconnect
supabase functions deploy scan-gmail
supabase functions deploy create-calendar-event
```

La clasificación vive dentro de `scan-gmail` para evitar una segunda llamada y un segundo límite de confianza.

## Calidad

```bash
npm run lint
npm run test
npm run build
npm run preview
```

Las pruebas cubren normalización de fechas, confianza, prueba de 15 días, estados y límites de suscripción, guardas, respuesta de IA, duplicados y formularios administrativos.

## Publicación en GitHub Pages

1. Confirmar que el repositorio se llame `AgenKin`; Vite usa `base: /AgenKin/`.
2. En GitHub → Settings → Pages elegir **GitHub Actions** como Source.
3. Revisar los cambios, hacer commit y push a `main` solo cuando estén aprobados.
4. El workflow ejecuta `npm ci`, lint, pruebas y build antes de publicar `dist`.
5. Configurar `APP_PUBLIC_URL` y las URLs OAuth con `https://kinoguerra.github.io/AgenKin/`.

La publicación automática se detiene ante cualquier fallo.

## Privacidad y eliminación

Consultar [Seguridad](docs/SEGURIDAD.md) y la política incluida en `privacidad.html`. Durante el MVP la eliminación se solicita al propietario. Antes de producción debe completarse un canal de soporte y, si el volumen lo justifica, automatizar el borrado autenticado.

## Limitaciones actuales

- Sin pasarela de pagos: planes y vencimientos se administran manualmente.
- Sin sincronización continua: el usuario pulsa “Analizar correos ahora”.
- Gmail requiere verificación y posiblemente evaluación de seguridad antes de un lanzamiento público.
- El proveedor de IA debe revisarse en materia de retención y privacidad.
- GitHub Pages no permite todos los encabezados HTTP; la CSP se aplica mediante HTML.
- No hay recuperación automática ante un evento creado en Google pero no registrado por una caída excepcional posterior. El ID determinista evita crear un duplicado al reintentar, pero ese caso debe reconciliarse operativamente.
- Los textos legales son una base técnica y requieren revisión profesional antes de comercializar.

## Próximos pasos

1. Configurar y verificar Google OAuth.
2. Elegir el proveedor/modelo de IA y revisar sus condiciones.
3. Ejecutar migraciones y pruebas RLS con dos cuentas.
4. Completar contacto y revisión legal.
5. Agregar conciliación de eventos y eliminación autoservicio antes de escalar.
