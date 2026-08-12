# Runbook de preproducción

## Alcance

El proyecto público actual funciona como preproducción para hasta 10 usuarios,
25 cuentas Gmail y un Calendar por usuario. El portal permanece abierto para
crear perfiles, pero Gmail y Calendar sólo pueden autorizarse desde cuentas
incluidas como testers en la pantalla de consentimiento de Google Cloud.

Usar exclusivamente cuentas dedicadas y mensajes sintéticos. Las direcciones
de los testers se administran fuera del repositorio y nunca se copian a código,
documentación, métricas o logs.

## Preparar testers en Google Cloud

1. Abrir Google Cloud Console → Google Auth Platform → Audience.
2. Mantener el estado de publicación en **Testing**.
3. Agregar las 25 cuentas dedicadas en **Test users**.
4. Confirmar que Gmail API y Google Calendar API siguen habilitadas.
5. Verificar los dos callbacks documentados en
   [Configuración de Google](CONFIGURACION_GOOGLE.md).

El modo Testing admite hasta 100 testers. Cuando se solicitan permisos distintos
de perfil básico, las autorizaciones y sus refresh tokens vencen a los 7 días;
durante esta etapa se debe ensayar también la reautorización semanal. El error
Google `403 access_denied` para una cuenta nueva indica primero que falta en la
lista de testers, no un fallo de AgenKin.

## Matriz y oleadas

La distribución objetivo cubre todos los límites comerciales:

| Usuarios | Gmail por usuario | Total Gmail |
|---:|---:|---:|
| 2 | 1 | 2 |
| 3 | 2 | 6 |
| 4 | 3 | 12 |
| 1 | 5 | 5 |
| **10** |  | **25** |

- Oleada 1: **5 usuarios / 10 Gmail**.
- Oleada 2: **10 usuarios / 25 Gmail**.

Antes de la segunda oleada, revisar que la primera no tenga tareas disponibles
con más de 30 minutos, cruces de usuario ni duplicados funcionales.

## Control operativo

El panel de Administración separa las demoras de alertas, Gmail y Calendar.
Los reintentos de IA cuyo `disponible_en` todavía está en el futuro no cuentan
como atraso. Una conexión con token vencido genera una advertencia de
reautorización sin desconectar ni borrar la Agenda interna.

Consultas agregadas para el operador:

```sql
select public.metricas_administrativas();
select public.metricas_notificaciones_push();

select jobname, schedule, active
from cron.job
where jobname like 'agenkin-%'
order by jobname;
```

No consultar ni exportar cuerpos, tokens, endpoints Push, candidatos con
contexto o direcciones de testers. Si una cola supera 30 minutos:

1. Confirmar si el job correspondiente está activo y si sus últimas respuestas
   son `2xx`.
2. Revisar el código operativo seguro, sin imprimir payloads ni secretos.
3. Identificar si el atraso es Gmail, Calendar o alertas; una cuenta defectuosa
   no debe detener las demás.
4. Detener sólo el Cron afectado si repite errores. Para notificaciones, Agenda,
   Gmail y Calendar pueden continuar activos.
5. Corregir mediante una migración hacia adelante y reanudar el job.

Umbrales vigentes:

- aviso de cola: más de 30 minutos;
- aviso de almacenamiento: 350 MB;
- detener sólo cargas históricas: 425 MB;
- revisar paso a Supabase Pro: más de 25 usuarios, cola sostenida o proyección
  superior al límite operativo acordado.

Los seis jobs actuales proyectan aproximadamente **159.870 ejecuciones por mes**:
tres workers cada minuto, creación de eventos cada dos minutos, descubrimiento
cada cinco minutos y mantenimiento diario.

## Prueba de carga

En cada oleada:

1. Conectar simultáneamente el último espacio disponible de cada plan.
2. Confirmar que las 25 Gmail caben en una ejecución del descubridor global.
3. Inyectar **500 correos sintéticos** que cubran fechas, duplicados entre
   cuentas, remitentes no autenticados y casos que requieren segundo intento de IA.
4. Verificar History incremental y que no se reinicie la importación de 90 días.
5. Crear 10 eventos internos y confirmar que Calendar drene la cola en menos de
   5 minutos, con un solo Calendar principal por usuario.
6. Desconectar y reautorizar una cuenta; Agenda debe permanecer intacta.
7. Ejecutar pruebas de propiedad con dos usuarios y confirmar ausencia de
   lecturas o escrituras cruzadas.

Criterios de aceptación:

- ninguna tarea disponible permanece más de 30 minutos;
- los 500 correos terminan sin pérdidas ni cruces de usuario;
- no hay duplicados por `conexion_google_id + gmail_message_id`;
- Calendar procesa los 10 eventos en menos de 5 minutos;
- una cuenta con error no bloquea a las demás;
- la base permanece por debajo de 350 MB.

## Advisors y excepciones controladas

Antes y después de cada oleada, ejecutar los advisors de seguridad y
rendimiento. Las RPC autenticadas `SECURITY DEFINER` son excepciones
intencionales únicamente cuando fijan `search_path`, obtienen la identidad del
JWT, validan propiedad y acceso activo y revocan permisos de `PUBLIC` y `anon`.
No se habilitan escrituras directas para reemplazarlas.

La protección contra contraseñas filtradas no interviene en este portal porque
el registro por correo y contraseña está deshabilitado y el acceso usa Google.

## Rollback

Si vuelve a fallar la entrega interna, desactivar sólo
`agenkin-procesar-notificaciones`. No eliminar alertas ni historial. Aplicar la
corrección con otra migración, desplegar el worker, validar dos ciclos y reactivar
el Cron. Gmail, Calendar y Agenda no dependen de ese envío.
