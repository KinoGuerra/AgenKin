-- Autoagendado autorizado por configuración personal, aprendizaje por descarte
-- y operaciones idempotentes de creación/eliminación en Google Calendar.

alter table public.correos_procesados
  add column if not exists dominio_remitente text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'correos_procesados_dominio_remitente_check'
      and conrelid = 'public.correos_procesados'::regclass
  ) then
    alter table public.correos_procesados
      add constraint correos_procesados_dominio_remitente_check
      check (
        dominio_remitente is null
        or dominio_remitente ~ '^[a-z0-9.-]{1,253}$'
      );
  end if;
end
$$;

create or replace function private.extraer_dominio_remitente(p_remitente text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(
    lower(
      (regexp_match(
        coalesce(p_remitente, ''),
        '@([a-z0-9.-]+\.[a-z]{2,})',
        'i'
      ))[1]
    ),
    ''
  )
$$;

revoke execute on function private.extraer_dominio_remitente(text)
  from public, anon, authenticated;

create or replace function private.normalizar_dominio_correo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.dominio_remitente := private.extraer_dominio_remitente(new.remitente);
  return new;
end
$$;

revoke execute on function private.normalizar_dominio_correo()
  from public, anon, authenticated;

drop trigger if exists correos_normalizar_dominio on public.correos_procesados;
create trigger correos_normalizar_dominio
before insert or update of remitente on public.correos_procesados
for each row execute function private.normalizar_dominio_correo();

update public.correos_procesados
set dominio_remitente = private.extraer_dominio_remitente(remitente)
where not detalle_compactado
  and dominio_remitente is distinct from private.extraer_dominio_remitente(remitente);

create table if not exists private.exclusiones_agenda_usuario (
  usuario_id uuid not null
    references public.perfiles(id) on delete cascade,
  dominio_remitente text not null
    check (dominio_remitente ~ '^[a-z0-9.-]{1,253}$'),
  huella_plantilla text not null
    check (huella_plantilla ~ '^[a-f0-9]{64}$'),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  primary key (usuario_id, dominio_remitente, huella_plantilla)
);

alter table private.exclusiones_agenda_usuario enable row level security;
revoke all on private.exclusiones_agenda_usuario
  from public, anon, authenticated;

alter table public.tareas_calendar
  add column if not exists operacion text not null default 'crear';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'tareas_calendar_operacion_check'
      and conrelid = 'public.tareas_calendar'::regclass
  ) then
    alter table public.tareas_calendar
      add constraint tareas_calendar_operacion_check
      check (operacion in ('crear', 'eliminar'));
  end if;
end
$$;

-- La creación interna es independiente de Google. Si Calendar está activo,
-- la misma transacción deja una tarea de creación idempotente.
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
  conexion_calendar_id uuid;
  v_tarea_id uuid;
  v_evento_creado boolean := false;
begin
  select c.id
  into conexion_calendar_id
  from public.conexiones_google c
  where c.usuario_id = p_usuario_id
    and c.es_calendar_principal
    and c.calendar_conectado
    and c.estado_conexion = 'activa'
  limit 1;

  select e.id into v_evento_id
  from public.eventos_calendar e
  where e.vencimiento_id = p_vencimiento_id
    and e.usuario_id = p_usuario_id;

  if v_evento_id is null then
    insert into public.eventos_calendar (
      usuario_id,
      vencimiento_id,
      conexion_google_id,
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
      conexion_calendar_id,
      null,
      null,
      p_fecha_evento,
      left(p_titulo, 160),
      left(coalesce(p_descripcion, ''), 1000),
      p_zona_horaria,
      p_es_dia_completo,
      least(greatest(coalesce(p_recordatorio_minutos, 1440), 0), 40320),
      case when conexion_calendar_id is null then 'no_conectado' else 'pendiente' end
    from public.vencimientos_detectados v
    where v.id = p_vencimiento_id
      and v.usuario_id = p_usuario_id
      and v.estado in ('pendiente', 'evento_creado')
    on conflict (vencimiento_id) do nothing
    returning id into v_evento_id;
    v_evento_creado := v_evento_id is not null;

    if v_evento_id is null then
      select e.id
      into v_evento_id
      from public.eventos_calendar e
      where e.vencimiento_id = p_vencimiento_id
        and e.usuario_id = p_usuario_id
        and e.estado_sincronizacion <> 'eliminado';
    end if;

    if v_evento_id is null then
      raise exception 'Vencimiento no encontrado';
    end if;

    if v_evento_creado then
      update public.vencimientos_detectados
      set estado = 'evento_creado'
      where id = p_vencimiento_id and usuario_id = p_usuario_id;

      insert into public.consumos_mensuales (usuario_id, periodo, eventos_creados)
      values (p_usuario_id, date_trunc('month', current_date)::date, 1)
      on conflict (usuario_id, periodo) do update
        set
          eventos_creados = public.consumos_mensuales.eventos_creados + 1,
          actualizado_en = now();
    end if;
  elsif conexion_calendar_id is not null then
    update public.eventos_calendar
    set
      conexion_google_id = conexion_calendar_id,
      estado_google = case
        when google_event_id is null then 'pendiente'
        else estado_google
      end
    where id = v_evento_id
      and estado_sincronizacion <> 'eliminado';
  end if;

  update public.conexiones_google
  set agenda_ultima_actualizacion_en = now()
  where usuario_id = p_usuario_id
    and gmail_conectado
    and estado_conexion = 'activa';

  if conexion_calendar_id is not null then
    insert into public.tareas_calendar (
      evento_id, usuario_id, operacion, estado, intentos, ultimo_error
    )
    values (v_evento_id, p_usuario_id, 'crear', 'pendiente', 0, null)
    on conflict (evento_id) do update
      set
        operacion = 'crear',
        estado = case
          when public.tareas_calendar.operacion = 'crear'
            and public.tareas_calendar.estado = 'completada'
            and exists (
              select 1
              from public.eventos_calendar e
              where e.id = v_evento_id and e.google_event_id is not null
            )
          then public.tareas_calendar.estado
          else 'pendiente'
        end,
        intentos = case
          when public.tareas_calendar.operacion = 'crear'
          then public.tareas_calendar.intentos
          else 0
        end,
        ultimo_error = null
    returning id into v_tarea_id;

    if exists (
      select 1
      from public.tareas_calendar tc
      where tc.id = v_tarea_id
        and tc.operacion = 'crear'
        and tc.estado = 'pendiente'
    ) and not exists (
      select 1
      from pgmq.q_calendar_sync q
      where (q.message->>'tarea_id')::uuid = v_tarea_id
        and coalesce(q.message->>'operacion', 'crear') = 'crear'
    ) then
      perform pgmq.send(
        'calendar_sync',
        jsonb_build_object(
          'tarea_id', v_tarea_id,
          'evento_id', v_evento_id,
          'usuario_id', p_usuario_id,
          'operacion', 'crear'
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

create or replace function public.encolar_eventos_calendar_usuario(
  p_usuario_id uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  conexion_calendar_id uuid;
  evento record;
  tarea_id uuid;
  total integer := 0;
begin
  select c.id
  into conexion_calendar_id
  from public.conexiones_google c
  where c.usuario_id = p_usuario_id
    and c.es_calendar_principal
    and c.calendar_conectado
    and c.estado_conexion = 'activa'
  limit 1;

  if conexion_calendar_id is null then
    return 0;
  end if;

  for evento in
    update public.eventos_calendar e
    set
      conexion_google_id = conexion_calendar_id,
      estado_google = 'pendiente',
      error_google = null
    where e.usuario_id = p_usuario_id
      and e.google_event_id is null
      and e.estado_sincronizacion <> 'eliminado'
      and e.fecha_evento >= current_date
    returning e.id
  loop
    insert into public.tareas_calendar (
      evento_id, usuario_id, operacion, estado, intentos, ultimo_error
    )
    values (evento.id, p_usuario_id, 'crear', 'pendiente', 0, null)
    on conflict (evento_id) do update
      set
        operacion = 'crear',
        estado = 'pendiente',
        intentos = 0,
        ultimo_error = null
    returning id into tarea_id;

    if not exists (
      select 1
      from pgmq.q_calendar_sync q
      where (q.message->>'tarea_id')::uuid = tarea_id
        and coalesce(q.message->>'operacion', 'crear') = 'crear'
    ) then
      perform pgmq.send(
        'calendar_sync',
        jsonb_build_object(
          'tarea_id', tarea_id,
          'evento_id', evento.id,
          'usuario_id', p_usuario_id,
          'operacion', 'crear'
        )
      );
      total := total + 1;
    end if;
  end loop;

  return total;
end
$$;

revoke execute on function public.encolar_eventos_calendar_usuario(uuid)
  from public, anon, authenticated;
grant execute on function public.encolar_eventos_calendar_usuario(uuid)
  to service_role;

-- El interruptor personal autoriza el autoagendado general. Las reglas de
-- ignorar se aplican antes, durante el análisis; los descartes se excluyen aquí.
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

create or replace function public.descartar_vencimiento(
  p_vencimiento_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario_id uuid := (select auth.uid());
  v_vencimiento public.vencimientos_detectados%rowtype;
  v_correo record;
  v_evento public.eventos_calendar%rowtype;
  v_tarea_id uuid;
  v_calendar_activo boolean := false;
begin
  if v_usuario_id is null then
    raise exception 'Sesion requerida';
  end if;
  if not (select private.usuario_habilitado()) then
    raise exception 'Cuenta o suscripcion no habilitada';
  end if;

  select *
  into v_vencimiento
  from public.vencimientos_detectados v
  where v.id = p_vencimiento_id
    and v.usuario_id = v_usuario_id
  for update;

  if v_vencimiento.id is null then
    raise exception 'Vencimiento no encontrado';
  end if;
  if v_vencimiento.estado = 'descartado' then
    return true;
  end if;
  if v_vencimiento.estado not in ('pendiente', 'evento_creado') then
    raise exception 'El vencimiento ya no puede descartarse';
  end if;

  select cp.dominio_remitente, cp.huella_plantilla
  into v_correo
  from public.correos_procesados cp
  where cp.id = v_vencimiento.correo_id
    and cp.usuario_id = v_usuario_id;

  if v_correo.dominio_remitente is not null
    and v_correo.huella_plantilla ~ '^[a-f0-9]{64}$' then
    insert into private.exclusiones_agenda_usuario (
      usuario_id, dominio_remitente, huella_plantilla
    )
    values (
      v_usuario_id,
      v_correo.dominio_remitente,
      v_correo.huella_plantilla
    )
    on conflict (usuario_id, dominio_remitente, huella_plantilla)
    do update set actualizado_en = now();
  end if;

  select e.*
  into v_evento
  from public.eventos_calendar e
  where e.vencimiento_id = v_vencimiento.id
    and e.usuario_id = v_usuario_id
  for update;

  if v_evento.id is not null then
    update public.eventos_calendar
    set
      estado_sincronizacion = 'eliminado',
      estado_google = case
        when conexion_google_id is null then 'no_conectado'
        else 'pendiente'
      end,
      error_google = null
    where id = v_evento.id;

    select exists (
      select 1
      from public.conexiones_google c
      where c.id = v_evento.conexion_google_id
        and c.usuario_id = v_usuario_id
        and c.calendar_conectado
        and c.es_calendar_principal
        and c.estado_conexion = 'activa'
    ) into v_calendar_activo;

    if v_calendar_activo then
      insert into public.tareas_calendar (
        evento_id, usuario_id, operacion, estado, intentos, ultimo_error
      )
      values (v_evento.id, v_usuario_id, 'eliminar', 'pendiente', 0, null)
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
            'evento_id', v_evento.id,
            'usuario_id', v_usuario_id,
            'operacion', 'eliminar'
          )
        );
      end if;
    end if;
  end if;

  update public.vencimientos_detectados
  set estado = 'descartado'
  where id = v_vencimiento.id
    and usuario_id = v_usuario_id;

  update public.conexiones_google
  set agenda_ultima_actualizacion_en = now()
  where usuario_id = v_usuario_id
    and estado_conexion = 'activa';

  return true;
end
$$;

revoke execute on function public.descartar_vencimiento(uuid)
  from public, anon;
grant execute on function public.descartar_vencimiento(uuid)
  to authenticated;

drop function if exists public.leer_tareas_calendar(integer);
create function public.leer_tareas_calendar(p_cantidad integer default 3)
returns table (
  msg_id bigint,
  read_ct integer,
  tarea_id uuid,
  evento_id uuid,
  usuario_id uuid,
  operacion text,
  intentos integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  mensaje record;
  v_tarea public.tareas_calendar%rowtype;
  v_operacion text;
begin
  for mensaje in
    select *
    from pgmq.read('calendar_sync', 180, least(greatest(p_cantidad, 1), 5))
  loop
    v_operacion := coalesce(mensaje.message->>'operacion', 'crear');

    update public.tareas_calendar t
    set estado = 'procesando'
    where t.id = (mensaje.message->>'tarea_id')::uuid
      and t.evento_id = (mensaje.message->>'evento_id')::uuid
      and t.usuario_id = (mensaje.message->>'usuario_id')::uuid
      and t.operacion = v_operacion
      and t.estado in ('pendiente', 'procesando')
    returning * into v_tarea;

    if v_tarea.id is null then
      perform pgmq.delete('calendar_sync', mensaje.msg_id);
      continue;
    end if;

    msg_id := mensaje.msg_id;
    read_ct := mensaje.read_ct;
    tarea_id := v_tarea.id;
    evento_id := v_tarea.evento_id;
    usuario_id := v_tarea.usuario_id;
    operacion := v_tarea.operacion;
    intentos := v_tarea.intentos;
    return next;
  end loop;
end
$$;

revoke execute on function public.leer_tareas_calendar(integer)
  from public, anon, authenticated;
grant execute on function public.leer_tareas_calendar(integer)
  to service_role;

drop function if exists public.finalizar_tarea_calendar(
  bigint, uuid, text, boolean
);
create function public.finalizar_tarea_calendar(
  p_msg_id bigint,
  p_tarea_id uuid,
  p_operacion text,
  p_error text default null,
  p_reintentar boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actualizada boolean := false;
begin
  update public.tareas_calendar
  set
    estado = case
      when p_reintentar then 'pendiente'
      when p_error is null then 'completada'
      else 'error'
    end,
    intentos = intentos + 1,
    ultimo_error = left(p_error, 100)
  where id = p_tarea_id
    and operacion = p_operacion
    and estado = 'procesando';
  v_actualizada := found;

  if not v_actualizada or not p_reintentar then
    perform pgmq.delete('calendar_sync', p_msg_id);
  end if;
end
$$;

revoke execute on function public.finalizar_tarea_calendar(
  bigint, uuid, text, text, boolean
) from public, anon, authenticated;
grant execute on function public.finalizar_tarea_calendar(
  bigint, uuid, text, text, boolean
) to service_role;
