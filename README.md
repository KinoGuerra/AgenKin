# AgenKin

**Del correo a tu agenda, automáticamente.**

AgenKin es una beta SaaS que permite iniciar sesión con Google, conectar una o
varias cuentas Gmail y un Google Calendar principal, analizar correos a pedido o
periódicamente y guardar fechas accionables en una Agenda interna. La réplica a
Calendar es opcional; la creación puede ser manual o automática con un umbral de
confianza configurable y aprendizaje privado a partir de los descartes.

## Estado de la beta

El frontend, la base, RLS y las Edge Functions están implementados. La landing y los portales cargan sin credenciales de Gmail, Calendar o IA; esas acciones muestran “Configuración requerida” hasta completar los secretos externos. No se incluyen datos simulados ni cobros.

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
              ├── descubrimiento incremental + cola durable
              ├── lectura Gmail + clasificación local/patrones/IA
              └── Agenda interna + cola de creación/eliminación en Calendar
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
│   ├── migrations/       esquema, RLS, RPC, colas y Cron
│   └── functions/        funciones Deno y módulos compartidos
├── tests/                Vitest
├── mobile/               aplicación Android Flutter para usuarios finales
├── docs/                 configuración y seguridad
└── .github/workflows/    validación y GitHub Pages
```

## Documentación

- [Análisis de correos](docs/ANALISIS_CORREOS.md): resolución local, patrones,
  IA, autoagenda y estados de Calendar.
- [Configuración de Supabase](docs/CONFIGURACION_SUPABASE.md): migraciones,
  funciones, Vault, Cron, colas y orden de despliegue.
- [Configuración de Google](docs/CONFIGURACION_GOOGLE.md): OAuth, Gmail y
  Calendar multicuenta.
- [Configuración de Groq](docs/CONFIGURACION_GROQ.md): secretos, modelo,
  pruebas, límites y privacidad.
- [Seguridad](docs/SEGURIDAD.md): límites de confianza, RLS, retención y
  respuesta a incidentes.
- [Preproducción](docs/PREPRODUCCION.md): testers de Google, oleadas de carga,
  umbrales, monitoreo y rollback operativo.

## Requisitos

- Node.js 22 o superior.
- npm 10 o superior.
- Supabase CLI para aplicar base y funciones.
- Proyecto Google Cloud para habilitar integraciones.
- Cuenta de Groq opcional para la clasificación con Structured Outputs.

## Inicio local

```bash
git clone https://github.com/KinoGuerra/AgenKin.git
cd AgenKin
copy .env.example .env
npm install
npm run dev
```

Abrir `http://localhost:5173/AgenKin/`. El base path `/AgenKin/` se usa también en desarrollo para detectar problemas antes del despliegue.

El selector claro/oscuro también funciona al abrir `index.html` con `file://`. Para el ingreso y el resto de la aplicación hay que usar Vite: el navegador bloquea los módulos ES y OAuth no admite una página servida como archivo local. Bajo HTTP, la interfaz muestra además el estado real del proveedor Google consultando la configuración pública de Supabase Auth.

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

Las migraciones crean:

- perfiles con rol `usuario` y acceso `activo`;
- prueba automática por 15 días;
- planes Prueba, Básico, Dúo, Pro y Ultra, más el plan interno AgenKin;
- límites por cantidad de cuentas Gmail (1, 1, 2, 3 y 5), sin cupo comercial por mensajes;
- consumos mensuales usados únicamente como métricas históricas;
- varias conexiones Google cifradas por usuario y un único Calendar seleccionado;
- correos sin cuerpo completo;
- vencimientos, Agenda interna, réplica opcional en Calendar, reglas y auditoría;
- cola global con reparto entre cuentas, Gmail History incremental y retención automática;
- patrones personales y globales declarativos para evitar llamadas innecesarias a IA;
- exclusiones privadas por usuario, dominio y plantilla para recordar descartes;
- reconciliación Gmail de siete días y presupuesto diario de IA para que el
  atraso histórico no bloquee los mensajes nuevos;
- índices, restricciones, triggers, funciones auxiliares y RLS.

En Supabase → Authentication → URL Configuration:

- Site URL local: `http://localhost:5173/AgenKin/`
- Redirect local: `http://localhost:5173/AgenKin/auth-callback.html`
- Redirect publicado: `https://kinoguerra.github.io/AgenKin/auth-callback.html`

Configurar Google como proveedor de Supabase Auth para el login básico.

El callback que debe registrarse en Google Cloud para ese proveedor es:

```text
https://kpqzwbhprqlapwhadejt.supabase.co/auth/v1/callback
```

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
- `calendar.calendarlist`, para que el calendario secundario **Agenda** quede
  visible y seleccionado en Google Calendar.

El login inicial no solicita estos permisos. Las conexiones Calendar creadas
antes de incorporar `calendar.calendarlist` deben autorizarse nuevamente una
vez desde Configuración.

## IA y secretos

Seguir [Configuración de Groq](docs/CONFIGURACION_GROQ.md). Groq es opcional y
se usa desde el worker global mediante el módulo compartido de procesamiento;
nunca se llama al proveedor desde `scan-gmail` ni desde el frontend. Con
`AI_PROVIDER=none`, o sin clave configurada, los casos ambiguos pasan a revisión
sin reservar presupuesto ni realizar solicitudes externas.

Configurar los secretos de IA en Supabase, nunca en el frontend:

```bash
supabase secrets set \
  AI_PROVIDER="groq" \
  AI_API_URL="https://api.groq.com/openai/v1/chat/completions" \
  AI_MODEL="openai/gpt-oss-20b" \
  AI_API_KEY="REEMPLAZAR_CON_CLAVE_GROQ" \
  AI_TIMEOUT_MS="20000" \
  AI_MAX_SOLICITUDES_DIA="300" \
  AI_MAX_TOKENS_DIA="80000" \
  AI_MAX_ATRASO_DIA="20"
```

Las credenciales de Google se configuran por separado según
[Configuración de Google](docs/CONFIGURACION_GOOGLE.md). Las variables de IA
mantienen nombres genéricos, pero esta versión acepta sólo `groq` y `none`; el
modelo predeterminado es `openai/gpt-oss-20b`.

El adaptador usa JSON Schema estricto, timeout configurable, una sola llamada
por intento y como máximo un segundo intento al día siguiente. Antes
de consultar la IA extrae localmente fechas, importes, acciones y entidades, y
reduce el contenido relevante a 1.200 caracteres. El contrato compacto y el
flujo completo están en [Análisis de correos](docs/ANALISIS_CORREOS.md). Cada correo se reclama por
`conexion_google_id + gmail_message_id`; un fallo técnico queda diferido en la
cola sin bloquear otros mensajes ni consumir un cupo comercial.

Los patrones se aprenden únicamente a partir de resultados autenticados y
consistentes. Son selectores declarativos, no código ejecutable: permiten
resolver estructuras conocidas sin IA y conservan una validación periódica para
detectar cambios.

La marca exacta `(Publicidad)` en el asunto tiene prioridad sobre patrones,
clasificación local e IA. Se guarda como promoción sin vencimiento aunque el
contenido incluya fechas, montos o llamados a reservar, pagar o solicitar un
turno.

Nunca agregar `AI_API_KEY` a `.env` del frontend ni crear una variable
`VITE_AI_API_KEY`.

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
supabase functions deploy sync-gmail-scheduled --no-verify-jwt
supabase functions deploy process-gmail-queue --no-verify-jwt
supabase functions deploy create-calendar-scheduled --no-verify-jwt
supabase functions deploy process-calendar-queue --no-verify-jwt
supabase functions deploy manage-web-push
supabase functions deploy process-notifications-scheduled --no-verify-jwt
```

## Notificaciones internas y Web Push

Cada evento de Agenda se versiona y se reconcilia de forma asíncrona. Los avisos
del día previo y del mismo día se programan a las 09:00 en la zona horaria del
usuario. El centro interno funciona sin Push; una falla externa nunca revierte
ni oculta un evento. Consultá [Notificaciones](docs/NOTIFICACIONES.md) para
configurar VAPID, retención, validación de endpoints y el orden seguro de
publicación.

`scan-gmail` descubre mensajes de todas las cuentas Gmail activas del usuario y
los deja en una cola durable. Los workers globales procesan esa cola sin llamadas
Edge anidadas, con concurrencia y presupuesto de tiempo limitados. Cada evento se
guarda primero en Agenda; la cola de Calendar ejecuta operaciones idempotentes de
creación o eliminación en la única cuenta elegida sin bloquear ni duplicar el
registro interno.
Cuando el usuario habilita la creación automática, los hallazgos futuros que
superan su umbral y no requieren revisión se guardan sin una regla adicional de
priorización. Un descarte registra una exclusión personal por dominio y plantilla;
los correos similares futuros siguen visibles y pueden agendarse manualmente, pero
no vuelven a autoagendarse. Si el evento ya se había replicado, la misma cola
solicita también su eliminación; un `404` de Google se considera éxito
idempotente.

## Operación de la beta Free

- La sincronización automática usa jobs globales; no se crea un cron por cuenta.
- Existen seis jobs: descubrimiento Gmail cada 5 minutos, procesamiento Gmail
  cada minuto, autoagenda cada 2 minutos, Calendar y notificaciones cada minuto,
  y mantenimiento diario.
- Gmail se consulta incrementalmente mediante History y la cola reparte capacidad
  entre cuentas para evitar que una bandeja monopolice el worker.
- Una reconciliación diaria recorre en páginas de 100 los últimos siete días.
  Las tareas incrementales y reparadas se procesan antes que la carga histórica;
  redescubrir un ID no reactiva errores terminales.
- La importación inicial revisa hasta 90 días; una vez establecido el cursor,
  los cambios nuevos se incorporan sin cupo comercial y el exceso queda en cola.
- Los detalles vencidos se compactan; los registros mínimos antirrepetición se
  eliminan a los 120 días y las tareas finalizadas se limpian por lotes.
- El panel administrativo avisa desde 350 MB de base y las cargas históricas se
  detienen desde 425 MB, sin detener la sincronización incremental.
- La etapa gratuita es beta y de mejor esfuerzo. Se recomienda pasar a Pro al
  superar 25 usuarios activos, sostener una cola mayor a 30 minutos, proyectar
  más de 350.000 invocaciones mensuales o necesitar backups y disponibilidad
  garantizada.
- El autoagendado crea como máximo cinco eventos por ejecución y mantiene una
  guardia de veinte eventos internos activos por usuario y día. Los eventos
  descartados o eliminados no consumen esa guardia.
- IA realiza una sola petición por intento, con un máximo predeterminado de 300
  solicitudes, 80.000 tokens no cacheados y 20 correos históricos por día. Un
  429 o timeout admite un segundo y último intento al día siguiente.
- El programador de autoagenda reconstruye tareas Calendar ausentes para eventos
  futuros que sigan pendientes y tengan un Calendar principal activo.

## Calidad

```bash
npm run lint
npm run test
npm run build
npm run preview
```

La primera etapa de la aplicación Android vive en [`mobile/`](mobile/README.md).
Usa Material 3, Riverpod, GoRouter y Supabase Flutter; comparte el backend y las
políticas RLS del portal, pero no incluye funciones administrativas. Su
configuración, deep links, ejecución y limitaciones OAuth están documentados en
el README propio.

Las más de cien pruebas cubren normalización de fechas, confianza, prueba de 15 días,
multicuenta y límites por plan, reparto de cola para hasta 125 cuentas,
proyección de invocaciones, retención, RLS, extracción HTML, patrones,
Structured Outputs, timeout, reintentos, duplicados y formularios
administrativos.

## Publicación en GitHub Pages

Si cambian contratos SQL o Edge, pausar primero los cron afectados, aplicar la
migración, desplegar las funciones, ejecutar pruebas de humo y reanudar cron.
Publicar el frontend al final para que nunca consuma firmas RPC antiguas.

1. Confirmar que el repositorio se llame `AgenKin`; Vite usa `base: /AgenKin/`.
2. En GitHub → Settings → Pages elegir **GitHub Actions** como Source.
3. Revisar los cambios, hacer commit y push a `main` solo cuando estén aprobados.
4. El workflow ejecuta `npm ci`, lint, pruebas y build antes de publicar `dist`.
5. Configurar `APP_PUBLIC_URL` y las URLs OAuth con `https://kinoguerra.github.io/AgenKin/`.

La publicación automática se detiene ante cualquier fallo.

## Privacidad y eliminación

Consultar [Seguridad](docs/SEGURIDAD.md) y la política incluida en
`privacidad.html`. Durante la beta, la eliminación de cuenta se solicita al
propietario. Antes de un lanzamiento comercial debe completarse un canal de
soporte y, si el volumen lo justifica, automatizar el borrado autenticado.

## Limitaciones actuales

- Sin pasarela de pagos: planes y vencimientos se administran manualmente.
- Gmail requiere verificación y posiblemente evaluación de seguridad antes de un lanzamiento público.
- Las condiciones de privacidad y retención de Groq deben revisarse nuevamente
  antes de comercializar el servicio.
- GitHub Pages no permite todos los encabezados HTTP; la CSP se aplica mediante HTML.
- La automatización depende de Cron, Vault y las Edge Functions configuradas en Supabase; si falta alguno, el portal conserva el análisis manual.
- Supabase Free puede pausar el proyecto y no ofrece las garantías de continuidad necesarias para un servicio comercial.
- Los textos legales son una base técnica y requieren revisión profesional antes de comercializar.

## Próximos pasos

1. Completar la verificación pública de Google para `gmail.readonly`.
2. Revisar periódicamente límites, privacidad y retención del proveedor de IA.
3. Ejecutar migraciones en seco, advisors y pruebas RLS con dos usuarios antes
   de cada cambio de contratos.
4. Completar contacto, eliminación autoservicio y revisión legal.
5. Agregar conciliación avanzada de eventos antes de escalar.
