-- La hora del aviso previo es una preferencia privada y sólo afecta agenda futura.

alter table public.perfiles
  add column if not exists hora_notificacion_previa smallint not null default 9;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'perfiles_hora_notificacion_previa_valida'
      and conrelid = 'public.perfiles'::regclass
  ) then
    alter table public.perfiles
      add constraint perfiles_hora_notificacion_previa_valida
      check (hora_notificacion_previa between 0 and 23);
  end if;
end
$$;

create or replace function public.reconciliar_notificaciones_eventos(
  p_limite integer default 40
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_evento record;
  v_tipo text;
  v_fecha_local date;
  v_programada timestamptz;
  v_total integer := 0;
  v_limite integer := least(greatest(coalesce(p_limite, 40), 1), 40);
begin
  for v_evento in
    select
      e.id,
      e.usuario_id,
      e.fecha_evento,
      e.titulo,
      e.es_dia_completo,
      e.estado_sincronizacion,
      e.version_notificacion,
      p.recibir_notificaciones,
      p.notificar_dia_previo,
      p.notificar_dia_vencimiento,
      p.hora_notificacion_previa,
      p.zona_horaria_notificaciones
    from public.eventos_calendar e
    join public.perfiles p on p.id = e.usuario_id
    where e.version_notificacion > e.version_notificacion_programada
    order by e.actualizado_en, e.id
    limit v_limite
    for update of e skip locked
  loop
    update public.notificaciones n
    set estado = 'cancelada', cancelada_en = now()
    where n.evento_id = v_evento.id
      and n.estado = 'programada'
      and (
        not v_evento.recibir_notificaciones
        or v_evento.estado_sincronizacion = 'eliminado'
        or not private.evento_notificacion_atendible(
          v_evento.fecha_evento,
          v_evento.es_dia_completo,
          v_evento.zona_horaria_notificaciones
        )
        or (n.tipo = 'dia_previo' and not v_evento.notificar_dia_previo)
        or (n.tipo = 'dia_vencimiento' and not v_evento.notificar_dia_vencimiento)
      );

    if v_evento.recibir_notificaciones
      and v_evento.estado_sincronizacion <> 'eliminado'
      and private.evento_notificacion_atendible(
        v_evento.fecha_evento,
        v_evento.es_dia_completo,
        v_evento.zona_horaria_notificaciones
      ) then
      v_fecha_local := (v_evento.fecha_evento at time zone v_evento.zona_horaria_notificaciones)::date;
      foreach v_tipo in array array['dia_previo', 'dia_vencimiento']
      loop
        continue when v_tipo = 'dia_previo' and not v_evento.notificar_dia_previo;
        continue when v_tipo = 'dia_vencimiento' and not v_evento.notificar_dia_vencimiento;

        v_programada := (
          (v_fecha_local - case when v_tipo = 'dia_previo' then 1 else 0 end)
            + case
              when v_tipo = 'dia_previo' then make_time(v_evento.hora_notificacion_previa, 0, 0)
              else time '09:00'
            end
        ) at time zone v_evento.zona_horaria_notificaciones;
        if v_programada < now() then v_programada := now(); end if;

        insert into public.notificaciones (
          usuario_id, evento_id, tipo, estado, version_evento,
          titulo, mensaje, programada_para,
          entregada_en, leida_en, cancelada_en
        ) values (
          v_evento.usuario_id,
          v_evento.id,
          v_tipo,
          'programada',
          v_evento.version_notificacion,
          left(
            case when v_tipo = 'dia_previo' then 'Mañana: ' else 'Hoy: ' end
              || coalesce(nullif(v_evento.titulo, ''), 'Evento de Agenda'),
            240
          ),
          'Revisá el compromiso en tu Agenda.',
          v_programada,
          null,
          null,
          null
        )
        on conflict (evento_id, tipo) do update set
          usuario_id = excluded.usuario_id,
          estado = 'programada',
          version_evento = excluded.version_evento,
          titulo = excluded.titulo,
          mensaje = excluded.mensaje,
          programada_para = excluded.programada_para,
          entregada_en = null,
          leida_en = null,
          cancelada_en = null
        where public.notificaciones.estado <> 'entregada';
      end loop;
    end if;

    update public.eventos_calendar
    set version_notificacion_programada = v_evento.version_notificacion
    where id = v_evento.id
      and usuario_id = v_evento.usuario_id;
    v_total := v_total + 1;
  end loop;
  return v_total;
end
$$;

revoke execute on function public.reconciliar_notificaciones_eventos(integer)
  from public, anon, authenticated;
grant execute on function public.reconciliar_notificaciones_eventos(integer)
  to service_role;

drop function if exists public.actualizar_preferencias_notificacion(
  boolean, boolean, boolean, text
);

create function public.actualizar_preferencias_notificacion(
  p_recibir boolean,
  p_dia_previo boolean,
  p_dia_vencimiento boolean,
  p_zona_horaria text,
  p_hora_previa smallint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario_id uuid := (select auth.uid());
  v_zona text := nullif(btrim(coalesce(p_zona_horaria, '')), '');
  v_recibir boolean := coalesce(p_recibir, false);
  v_dia_previo boolean := coalesce(p_recibir, false) and coalesce(p_dia_previo, false);
  v_dia_vencimiento boolean := coalesce(p_recibir, false) and coalesce(p_dia_vencimiento, false);
begin
  if v_usuario_id is null then raise exception 'Sesión requerida'; end if;
  if not (select private.usuario_habilitado()) then
    raise exception 'Cuenta o suscripción no habilitada';
  end if;
  if v_zona is null or not exists (
    select 1 from pg_catalog.pg_timezone_names z where z.name = v_zona
  ) then raise exception 'Zona horaria inválida'; end if;
  if p_hora_previa is null or p_hora_previa not between 0 and 23 then
    raise exception 'Hora de aviso inválida';
  end if;

  update public.perfiles
  set recibir_notificaciones = v_recibir,
      notificar_dia_previo = v_dia_previo,
      notificar_dia_vencimiento = v_dia_vencimiento,
      zona_horaria_notificaciones = v_zona,
      hora_notificacion_previa = p_hora_previa
  where id = v_usuario_id;

  update public.eventos_calendar
  set version_notificacion = version_notificacion + 1
  where usuario_id = v_usuario_id
    and estado_sincronizacion <> 'eliminado'
    and private.evento_notificacion_atendible(
      fecha_evento, es_dia_completo, v_zona
    );

  update public.notificaciones
  set estado = 'cancelada', cancelada_en = now()
  where usuario_id = v_usuario_id
    and estado = 'programada'
    and (
      not v_recibir
      or (tipo = 'dia_previo' and not v_dia_previo)
      or (tipo = 'dia_vencimiento' and not v_dia_vencimiento)
    );

  return jsonb_build_object(
    'recibir_notificaciones', v_recibir,
    'notificar_dia_previo', v_dia_previo,
    'notificar_dia_vencimiento', v_dia_vencimiento,
    'hora_notificacion_previa', p_hora_previa,
    'zona_horaria', v_zona
  );
end
$$;

revoke execute on function public.actualizar_preferencias_notificacion(
  boolean, boolean, boolean, text, smallint
) from public, anon;
grant execute on function public.actualizar_preferencias_notificacion(
  boolean, boolean, boolean, text, smallint
) to authenticated;

notify pgrst, 'reload schema';
