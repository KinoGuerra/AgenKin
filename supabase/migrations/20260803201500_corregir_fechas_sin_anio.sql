-- Una fecha sin año no debe saltar casi doce meses sólo porque ya pasó unos
-- días respecto del correo. Se retiran los falsos positivos conocidos creados
-- por esa inferencia y se elimina su réplica de Calendar de forma idempotente.

do $$
declare
  v_candidato record;
  v_tarea_id uuid;
  v_calendar_activo boolean;
begin
  for v_candidato in
    select
      v.id as vencimiento_id,
      v.usuario_id,
      e.id as evento_id,
      e.conexion_google_id
    from public.vencimientos_detectados v
    join public.correos_procesados cp
      on cp.id = v.correo_id
      and cp.usuario_id = v.usuario_id
    left join public.eventos_calendar e
      on e.vencimiento_id = v.id
      and e.usuario_id = v.usuario_id
    where v.estado in ('pendiente', 'evento_creado')
      and cp.origen_analisis = 'local'
      and v.tipo = 'turno'
      and v.fecha_vencimiento
        > (cp.fecha_correo at time zone v.zona_horaria)::date + 180
      and cp.asunto ilike any (array[
        '%patch preview%',
        '%proceso de pago incompleto%',
        '%confirmación de tu pedido%',
        '%pedido ya fue enviado%'
      ])
    for update of v
  loop
    update public.vencimientos_detectados
    set
      estado = 'descartado',
      actualizado_en = now()
    where id = v_candidato.vencimiento_id
      and usuario_id = v_candidato.usuario_id;

    if v_candidato.evento_id is null then
      continue;
    end if;

    update public.eventos_calendar
    set
      estado_sincronizacion = 'eliminado',
      estado_google = case
        when conexion_google_id is null then 'no_conectado'
        else 'pendiente'
      end,
      error_google = null
    where id = v_candidato.evento_id
      and usuario_id = v_candidato.usuario_id;

    select exists (
      select 1
      from public.conexiones_google c
      where c.id = v_candidato.conexion_google_id
        and c.usuario_id = v_candidato.usuario_id
        and c.calendar_conectado
        and c.es_calendar_principal
        and c.estado_conexion = 'activa'
    ) into v_calendar_activo;

    if not v_calendar_activo then
      continue;
    end if;

    insert into public.tareas_calendar (
      evento_id,
      usuario_id,
      operacion,
      estado,
      intentos,
      ultimo_error
    )
    values (
      v_candidato.evento_id,
      v_candidato.usuario_id,
      'eliminar',
      'pendiente',
      0,
      null
    )
    on conflict (evento_id) do update
      set
        operacion = 'eliminar',
        estado = 'pendiente',
        intentos = 0,
        ultimo_error = null
    returning id into v_tarea_id;

    if not exists (
      select 1
      from pgmq.q_calendar_sync q
      where (q.message->>'tarea_id')::uuid = v_tarea_id
        and q.message->>'operacion' = 'eliminar'
    ) then
      perform pgmq.send(
        'calendar_sync',
        jsonb_build_object(
          'tarea_id', v_tarea_id,
          'evento_id', v_candidato.evento_id,
          'usuario_id', v_candidato.usuario_id,
          'operacion', 'eliminar'
        )
      );
    end if;
  end loop;

  update public.conexiones_google c
  set agenda_ultima_actualizacion_en = now()
  where exists (
    select 1
    from public.vencimientos_detectados v
    join public.correos_procesados cp
      on cp.id = v.correo_id
      and cp.usuario_id = v.usuario_id
    where v.usuario_id = c.usuario_id
      and v.estado = 'descartado'
      and cp.origen_analisis = 'local'
      and v.tipo = 'turno'
      and v.fecha_vencimiento
        > (cp.fecha_correo at time zone v.zona_horaria)::date + 180
      and cp.asunto ilike any (array[
        '%patch preview%',
        '%proceso de pago incompleto%',
        '%confirmación de tu pedido%',
        '%pedido ya fue enviado%'
      ])
  );
end
$$;
