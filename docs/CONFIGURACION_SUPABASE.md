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

Para la entrega inicial de notificaciones no aplicar todas las migraciones en
un único paso: seguir el orden de [Notificaciones](NOTIFICACIONES.md) y dejar la
migración de activación del Cron para después del despliegue de la función.

Las migraciones crean tipos, tablas, índices, triggers, funciones, permisos,
RLS, conexiones multicuenta, colas de Gmail/Calendar/Push y seis jobs globales. La
promoción del propietario a superadministrador es manual: ejecutar la
instrucción correspondiente después de que esa persona haya iniciado sesión al
menos una vez. Nunca guardar su correo en una migración publicada.

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
supabase functions deploy manage-web-push
supabase functions deploy process-notifications-scheduled --no-verify-jwt
```

El callback OAuth es público porque Google no envía un JWT de Supabase. Su
seguridad depende de un `state` aleatorio, almacenado como hash, de uso único
y con vencimiento. Las cinco funciones programadas tampoco validan JWT en el
gateway, pero rechazan toda llamada que no incluya el secreto interno de Cron.

Las funciones nuevas comparten módulos internos; una Edge Function no debe
invocar otra por cada correo o evento.

Antes de desplegar `process-gmail-queue`, configurar Groq según
[Configuración de Groq](CONFIGURACION_GROQ.md) o establecer
`AI_PROVIDER=none`. Toda API key debe existir únicamente como Supabase Secret.

## Activar la sincronización programada

Cron y `pg_net` sostienen cinco workers HTTP globales y un mantenimiento SQL:

- `agenkin-descubrir-gmail`: cada 5 minutos;
- `agenkin-procesar-gmail`: cada minuto;
- `agenkin-crear-eventos`: cada 2 minutos;
- `agenkin-procesar-calendar`: cada minuto;
- `agenkin-procesar-notificaciones`: cada minuto;
- `agenkin-mantenimiento-diario`: todos los días a las 03:43 UTC.

No se crea un cron por usuario o cuenta. Los cinco jobs HTTP exigen el secreto
interno; el mantenimiento invoca directamente una función privada.

Gmail mantiene un cursor History por conexión. La importación inicial revisa
hasta 90 días y avanza por páginas; después solo consulta cambios incrementales.
Las tareas SQL son la única fuente de verdad y se reparten circularmente entre
cuentas. Calendar utiliza mensajes versionados con `operacion: crear | eliminar`;
el worker procesa hasta tres por ejecución y evita que un mensaje viejo confirme
una operación reemplazada.

Cada conexión conserva además un cursor de reconciliación diaria de siete días.
Las tareas registran su origen y la lectura prioriza mensajes incrementales y
reparados. La capacidad máxima sólo cuenta IDs realmente nuevos: duplicados y
errores terminales no se reactivan al volver a aparecer en Gmail.

El presupuesto de IA vive en `private.consumo_ia_diario` y sólo se modifica por
RPC `SECURITY DEFINER` exclusivas de `service_role`. Los defaults son 300
solicitudes, 80.000 tokens no cacheados y 20 solicitudes históricas por día.

Antes de aplicar esa migración:

1. Generar un valor aleatorio largo para `CRON_SECRET`.
2. Guardarlo como Edge Function Secret con ese nombre.
3. Guardar el mismo valor en Vault con el nombre `agenkin_cron_secret`.
4. Guardar `https://kpqzwbhprqlapwhadejt.supabase.co` en Vault con el nombre
   `agenkin_project_url`.

Ingresar esos valores desde el Dashboard de Supabase; no escribir el secreto en
archivos, historial de shell, migraciones ni logs. La sincronización de Gmail se
activa al conectar la primera cuenta y el usuario puede pasar todas sus
conexiones a modo manual. La creación automática de eventos es un interruptor
separado y conserva el umbral elegido.

## Límites de la beta Free

- Diseñar para un máximo inicial de 25 usuarios activos y 125 cuentas Gmail.
- El descubridor reclama hasta 40 cuentas con concurrencia 4 y 120 segundos.
- El worker procesa hasta 20 tareas con concurrencia 4.
- El autoagendado crea hasta 5 eventos por ejecución y mantiene una guardia de
  20 eventos internos activos por usuario y día; los eliminados no cuentan.
- Calendar procesa hasta 3 tareas por ejecución y reintenta errores temporales.
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
7. Confirmar que `(Publicidad)` no cree vencimiento aunque incluya fecha o monto.
8. Probar autoagenda, descarte repetido y carrera entre creación/eliminación.
9. Verificar los estados `Sólo en Agenda`, `Google pendiente`, `Sincronizado` y
   `Error de Google`.
10. Simular compactación a 15/30 días, tombstones a 120 y limpieza de tareas.
11. Medir tablas e índices con `pg_total_relation_size`.

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
