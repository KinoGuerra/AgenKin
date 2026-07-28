create or replace function public.registrar_evento_agenda(
  p_usuario_id uuid,
  p_vencimiento_id uuid,
  p_titulo text,
  p_descripcion text,
  p_fecha_evento timestamptz,
  p_zona_horaria text,
  p_es_dia_completo boolean,
  p_recordatorio_minutos integer
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_evento_id uuid;
  v_calendar_activo boolean;
  v_tarea_id uuid;
begin
  select e.id into v_evento_id
  from public.eventos_calendar e
  where e.vencimiento_id = p_vencimiento_id
    and e.usuario_id = p_usuario_id;

  if v_evento_id is null then
    insert into public.eventos_calendar (
      usuario_id,
      vencimiento_id,
      google_event_id,
      calendar_id,
      fecha_evento,
      titulo,
      descripcion,
      zona_horaria,
      es_dia_completo,
      recordatorio_minutos,
      estado_google
    )
    select
      p_usuario_id,
      v.id,
      null,
      null,
      p_fecha_evento,
      left(p_titulo, 160),
      left(coalesce(p_descripcion, ''), 1000),
      p_zona_horaria,
      p_es_dia_completo,
      least(greatest(coalesce(p_recordatorio_minutos, 1440), 0), 40320),
      case when coalesce(c.calendar_conectado, false) then 'pendiente' else 'no_conectado' end
    from public.vencimientos_detectados v
    left join public.conexiones_google c on c.usuario_id = v.usuario_id
    where v.id = p_vencimiento_id
      and v.usuario_id = p_usuario_id
    returning id into v_evento_id;

    if v_evento_id is null then
      raise exception 'Vencimiento no encontrado';
    end if;

    update public.vencimientos_detectados
    set estado = 'evento_creado'
    where id = p_vencimiento_id
      and usuario_id = p_usuario_id;

    insert into public.consumos_mensuales (usuario_id, periodo, eventos_creados)
    values (p_usuario_id, date_trunc('month', current_date)::date, 1)
    on conflict (usuario_id, periodo) do update
      set eventos_creados = public.consumos_mensuales.eventos_creados + 1;
  end if;

  update public.conexiones_google
  set agenda_ultima_actualizacion_en = now()
  where usuario_id = p_usuario_id;

  select c.calendar_conectado and c.estado_conexion = 'activa'
  into v_calendar_activo
  from public.conexiones_google c
  where c.usuario_id = p_usuario_id;

  if coalesce(v_calendar_activo, false) then
    insert into public.tareas_calendar (evento_id, usuario_id, estado)
    values (v_evento_id, p_usuario_id, 'pendiente')
    on conflict (evento_id) do update
      set estado = case
        when public.tareas_calendar.estado = 'completada' then public.tareas_calendar.estado
        else 'pendiente'
      end
    returning id into v_tarea_id;

    if exists (
      select 1
      from public.tareas_calendar t
      where t.id = v_tarea_id
        and t.estado = 'pendiente'
    ) and not exists (
      select 1
      from pgmq.q_calendar_sync q
      where (q.message->>'tarea_id')::uuid = v_tarea_id
    ) then
      perform pgmq.send(
        'calendar_sync',
        jsonb_build_object(
          'tarea_id', v_tarea_id,
          'evento_id', v_evento_id,
          'usuario_id', p_usuario_id
        )
      );
    end if;
  end if;
  return v_evento_id;
end
$$;

revoke execute on function public.registrar_evento_agenda(
  uuid, uuid, text, text, timestamptz, text, boolean, integer
) from public, anon, authenticated;
grant execute on function public.registrar_evento_agenda(
  uuid, uuid, text, text, timestamptz, text, boolean, integer
) to service_role;
