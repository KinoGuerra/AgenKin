-- Un compromiso manual pertenece al usuario, pero no a un correo.
alter table public.vencimientos_detectados
  alter column correo_id drop not null;

create or replace function private.crear_evento_manual(
  p_titulo text,
  p_descripcion text,
  p_fecha date,
  p_hora time default null,
  p_recordatorio_minutos integer default 1440
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario_id uuid := (select auth.uid());
  v_titulo text := btrim(coalesce(p_titulo, ''));
  v_descripcion text := coalesce(p_descripcion, '');
  v_zona_horaria text := 'America/Argentina/Cordoba';
  v_fecha_evento timestamptz;
  v_vencimiento_id uuid;
  v_evento_id uuid;
  v_google_estado text;
begin
  if v_usuario_id is null then
    raise exception 'Sesión requerida';
  end if;
  if not (select private.usuario_habilitado()) then
    raise exception 'Cuenta o suscripción no habilitada';
  end if;
  if char_length(v_titulo) not between 1 and 160 then
    raise exception 'El título debe tener entre 1 y 160 caracteres';
  end if;
  if char_length(v_descripcion) > 1000 then
    raise exception 'La descripción no puede superar los 1000 caracteres';
  end if;
  if p_fecha is null then
    raise exception 'La fecha es obligatoria';
  end if;
  if p_recordatorio_minutos is null
    or p_recordatorio_minutos not between 0 and 40320 then
    raise exception 'Recordatorio inválido';
  end if;

  v_fecha_evento := (
    p_fecha + coalesce(p_hora, time '12:00')
  ) at time zone v_zona_horaria;

  if p_fecha < (now() at time zone v_zona_horaria)::date
    or (p_hora is not null and v_fecha_evento <= now()) then
    raise exception 'La fecha y hora del evento ya pasaron';
  end if;

  insert into public.vencimientos_detectados (
    usuario_id,
    correo_id,
    tipo,
    titulo,
    descripcion,
    fecha_vencimiento,
    hora_vencimiento,
    zona_horaria,
    confianza,
    explicacion,
    estado,
    requiere_revision
  )
  values (
    v_usuario_id,
    null,
    'compromiso',
    v_titulo,
    v_descripcion,
    p_fecha,
    p_hora,
    v_zona_horaria,
    1,
    'Evento agregado manualmente por el usuario.',
    'pendiente',
    false
  )
  returning id into v_vencimiento_id;

  v_evento_id := public.registrar_evento_agenda(
    v_usuario_id,
    v_vencimiento_id,
    v_titulo,
    v_descripcion,
    v_fecha_evento,
    v_zona_horaria,
    p_hora is null,
    p_recordatorio_minutos
  );

  select e.estado_google
  into v_google_estado
  from public.eventos_calendar e
  where e.id = v_evento_id
    and e.usuario_id = v_usuario_id;

  return jsonb_build_object(
    'agenda_event_id', v_evento_id,
    'google_estado', v_google_estado
  );
end
$$;

revoke execute on function private.crear_evento_manual(
  text, text, date, time, integer
) from public, anon, authenticated;
grant execute on function private.crear_evento_manual(
  text, text, date, time, integer
) to authenticated;

create or replace function public.crear_evento_manual(
  p_titulo text,
  p_descripcion text,
  p_fecha date,
  p_hora time default null,
  p_recordatorio_minutos integer default 1440
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.crear_evento_manual(
    p_titulo,
    p_descripcion,
    p_fecha,
    p_hora,
    p_recordatorio_minutos
  );
$$;

revoke execute on function public.crear_evento_manual(
  text, text, date, time, integer
) from public, anon, authenticated;
grant execute on function public.crear_evento_manual(
  text, text, date, time, integer
) to authenticated;
