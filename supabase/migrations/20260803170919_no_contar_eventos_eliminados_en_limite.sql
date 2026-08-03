-- Los descartes no consumen el límite diario: dejaron de ser eventos de Agenda.
create or replace function public.crear_eventos_automaticos_pendientes(
  p_limite integer default 5
)
returns table (
  evento_id uuid,
  usuario_id uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidato record;
  v_creados integer := 0;
  v_limite integer := least(greatest(p_limite, 1), 5);
  v_inicio_dia timestamptz := (
    (now() at time zone 'America/Argentina/Cordoba')::date
      at time zone 'America/Argentina/Cordoba'
  );
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('agenkin_eventos_automaticos')
  );

  for candidato in
    select
      v.usuario_id,
      v.id as vencimiento_id,
      v.titulo,
      v.descripcion,
      v.fecha_vencimiento,
      v.hora_vencimiento,
      v.zona_horaria
    from public.vencimientos_detectados v
    join public.correos_procesados cp on cp.id = v.correo_id
    join public.perfiles pe on pe.id = v.usuario_id
    join public.suscripciones s on s.usuario_id = v.usuario_id
    join public.planes pl on pl.id = s.plan_id
    where v.estado = 'pendiente'
      and not v.requiere_revision
      and v.fecha_vencimiento >= (now() at time zone v.zona_horaria)::date
      and cp.dominio_remitente is not null
      and cp.huella_plantilla ~ '^[a-f0-9]{64}$'
      and pe.estado_acceso = 'activo'
      and s.estado in ('prueba', 'activa')
      and s.fecha_vencimiento >= now()
      and pl.activo
      and exists (
        select 1
        from public.conexiones_google c
        where c.usuario_id = v.usuario_id
          and c.estado_conexion = 'activa'
          and c.gmail_conectado
          and c.creacion_automatica_eventos
          and v.confianza >= c.umbral_confianza_automatica
      )
      and not exists (
        select 1
        from private.exclusiones_agenda_usuario x
        where x.usuario_id = v.usuario_id
          and x.dominio_remitente = cp.dominio_remitente
          and x.huella_plantilla = cp.huella_plantilla
      )
      and not exists (
        select 1
        from public.eventos_calendar e
        where e.vencimiento_id = v.id
      )
    order by v.fecha_vencimiento, v.creado_en
    limit 200
    for update of v skip locked
  loop
    exit when v_creados >= v_limite;
    continue when (
      select count(*)
      from public.eventos_calendar e
      where e.usuario_id = candidato.usuario_id
        and e.creado_en >= v_inicio_dia
        and e.estado_sincronizacion <> 'eliminado'
    ) >= 20;

    evento_id := public.registrar_evento_agenda(
      candidato.usuario_id,
      candidato.vencimiento_id,
      candidato.titulo,
      candidato.descripcion,
      (
        candidato.fecha_vencimiento
          + coalesce(candidato.hora_vencimiento, time '12:00')
      ) at time zone candidato.zona_horaria,
      candidato.zona_horaria,
      candidato.hora_vencimiento is null,
      1440
    );
    usuario_id := candidato.usuario_id;
    v_creados := v_creados + 1;
    return next;
  end loop;
end
$$;

revoke execute on function public.crear_eventos_automaticos_pendientes(integer)
  from public, anon, authenticated;
grant execute on function public.crear_eventos_automaticos_pendientes(integer)
  to service_role;
