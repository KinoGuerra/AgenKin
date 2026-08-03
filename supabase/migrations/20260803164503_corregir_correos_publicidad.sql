-- Corrige únicamente la marca explícita del asunto. El lote queda acotado para
-- mantener corta la migración incluso si vuelve a ejecutarse sobre una beta más grande.
set local lock_timeout = '5s';
set local statement_timeout = '30s';

create temporary table publicidad_corregida on commit drop as
select
  cp.id as correo_id,
  cp.usuario_id,
  cp.grupo_resumen as grupo_anterior,
  cp.origen_analisis as origen_anterior,
  cp.estado_procesamiento::text as estado_anterior,
  date_trunc('month', cp.fecha_procesamiento)::date as periodo,
  cp.metricas_registradas_en is not null as metricas_registradas
from public.correos_procesados cp
where cp.asunto ~* '\([[:space:]]*publicidad[[:space:]]*\)'
  and (
    cp.categoria <> 'promocion'
    or cp.grupo_resumen <> 'otros'
    or cp.relevante
    or cp.estado_procesamiento::text <> 'procesado'
    or cp.error_procesamiento is not null
    or cp.origen_analisis <> 'local'
    or cp.patron_id is not null
    or cp.huella_funcional is not null
    or cp.duplicado_funcional
  )
order by cp.fecha_procesamiento, cp.id
limit 1000;

-- Conserva los totales mensuales, pero mueve el grupo y el origen que quedaron
-- atribuidos a una clasificación incorrecta.
with deltas as (
  select
    usuario_id,
    periodo,
    count(*) filter (where grupo_anterior = 'tarjetas')::integer as tarjetas,
    count(*) filter (where grupo_anterior = 'servicios')::integer as servicios,
    count(*) filter (where grupo_anterior = 'suscripciones')::integer as suscripciones,
    count(*) filter (where grupo_anterior = 'turnos')::integer as turnos,
    count(*) filter (where grupo_anterior <> 'otros')::integer as hacia_otros,
    count(*) filter (where origen_anterior = 'regla')::integer as reglas,
    count(*) filter (
      where origen_anterior in ('patron_personal', 'patron_global')
    )::integer as patrones,
    count(*) filter (
      where origen_anterior in ('ia', 'migracion')
    )::integer as ia
  from publicidad_corregida
  where metricas_registradas
    and estado_anterior in ('procesado', 'ignorado')
  group by usuario_id, periodo
)
update public.consumos_mensuales consumo
set
  grupo_tarjetas = greatest(0, consumo.grupo_tarjetas - deltas.tarjetas),
  grupo_servicios = greatest(0, consumo.grupo_servicios - deltas.servicios),
  grupo_suscripciones = greatest(
    0,
    consumo.grupo_suscripciones - deltas.suscripciones
  ),
  grupo_turnos = greatest(0, consumo.grupo_turnos - deltas.turnos),
  grupo_otros = consumo.grupo_otros + deltas.hacia_otros,
  origen_regla = greatest(0, consumo.origen_regla - deltas.reglas),
  origen_patron = greatest(0, consumo.origen_patron - deltas.patrones),
  origen_ia = greatest(0, consumo.origen_ia - deltas.ia),
  actualizado_en = now()
from deltas
where consumo.usuario_id = deltas.usuario_id
  and consumo.periodo = deltas.periodo;

-- El cambio de estado se hace antes de soltar patron_id para que el trigger
-- existente devuelva a observación cualquier patrón que produjo el falso positivo.
update public.vencimientos_detectados vencimiento
set estado = 'descartado'
from publicidad_corregida correccion
where vencimiento.correo_id = correccion.correo_id
  and vencimiento.usuario_id = correccion.usuario_id
  and vencimiento.estado::text <> 'descartado';

do $$
declare
  evento record;
  tarea_id uuid;
begin
  for evento in
    select
      e.id,
      e.usuario_id,
      e.conexion_google_id
    from public.eventos_calendar e
    join public.vencimientos_detectados v on v.id = e.vencimiento_id
    join publicidad_corregida correccion on correccion.correo_id = v.correo_id
    where e.estado_sincronizacion::text <> 'eliminado'
    for update of e
  loop
    update public.eventos_calendar
    set
      estado_sincronizacion = 'eliminado',
      estado_google = case
        when evento.conexion_google_id is null then 'no_conectado'
        else 'pendiente'
      end,
      error_google = null
    where id = evento.id;

    if exists (
      select 1
      from public.conexiones_google conexion
      where conexion.id = evento.conexion_google_id
        and conexion.usuario_id = evento.usuario_id
        and conexion.calendar_conectado
        and conexion.es_calendar_principal
        and conexion.estado_conexion::text = 'activa'
    ) then
      insert into public.tareas_calendar (
        evento_id,
        usuario_id,
        operacion,
        estado,
        intentos,
        ultimo_error
      )
      values (evento.id, evento.usuario_id, 'eliminar', 'pendiente', 0, null)
      on conflict (evento_id) do update
        set
          operacion = 'eliminar',
          estado = 'pendiente',
          intentos = 0,
          ultimo_error = null
      returning id into tarea_id;

      if not exists (
        select 1
        from pgmq.q_calendar_sync cola
        where (cola.message->>'tarea_id')::uuid = tarea_id
          and cola.message->>'operacion' = 'eliminar'
      ) then
        perform pgmq.send(
          'calendar_sync',
          jsonb_build_object(
            'tarea_id', tarea_id,
            'evento_id', evento.id,
            'usuario_id', evento.usuario_id,
            'operacion', 'eliminar'
          )
        );
      end if;
    end if;
  end loop;
end
$$;

update public.correos_procesados correo
set
  categoria = 'promocion',
  grupo_resumen = 'otros',
  grupo_asignado_por = 'local',
  relevante = false,
  estado_procesamiento = 'procesado',
  error_procesamiento = null,
  origen_analisis = 'local',
  patron_id = null,
  huella_funcional = null,
  duplicado_funcional = false
from publicidad_corregida correccion
where correo.id = correccion.correo_id
  and correo.usuario_id = correccion.usuario_id;

update public.conexiones_google conexion
set agenda_ultima_actualizacion_en = now()
where exists (
  select 1
  from publicidad_corregida correccion
  where correccion.usuario_id = conexion.usuario_id
);
