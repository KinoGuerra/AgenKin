create extension if not exists pgmq;
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
begin
  if to_regclass('pgmq.q_gmail_sync') is null then
    perform pgmq.create('gmail_sync');
  end if;
end
$$;

-- Dependencias compartidas por la automatización y la Agenda.
alter table public.conexiones_google
  add column if not exists sincronizacion_automatica boolean not null default false,
  add column if not exists creacion_automatica_eventos boolean not null default false,
  add column if not exists umbral_confianza_automatica numeric(4,3) not null default 0.900,
  add column if not exists gmail_history_id text,
  add column if not exists gmail_history_objetivo text,
  add column if not exists gmail_page_token text,
  add column if not exists sincronizacion_inicial_completa boolean not null default false,
  add column if not exists proxima_sincronizacion timestamptz,
  add column if not exists ultima_sincronizacion_exitosa timestamptz,
  add column if not exists error_ultima_sincronizacion text;

create table if not exists public.tareas_correos_gmail (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.perfiles(id) on delete cascade,
  gmail_message_id text not null,
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'procesando', 'completada', 'error')),
  intentos integer not null default 0 check (intentos >= 0),
  ultimo_error text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (usuario_id, gmail_message_id)
);

-- Agenda interna, conexiones independientes y clasificación resumida.
do $$
begin
  if to_regclass('pgmq.q_calendar_sync') is null then
    perform pgmq.create('calendar_sync');
  end if;
end
$$;

alter table public.oauth_states
  add column if not exists servicio text;

update public.oauth_states
set servicio = 'todo'
where servicio is null;

alter table public.oauth_states
  alter column servicio set default 'todo',
  alter column servicio set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'oauth_states_servicio_check'
      and conrelid = 'public.oauth_states'::regclass
  ) then
    alter table public.oauth_states
      add constraint oauth_states_servicio_check
      check (servicio in ('gmail', 'calendar', 'todo'));
  end if;
end
$$;

alter table public.conexiones_google
  add column if not exists gmail_ultima_lectura_en timestamptz,
  add column if not exists calendar_ultima_sincronizacion_en timestamptz,
  add column if not exists agenda_ultima_actualizacion_en timestamptz;

alter table public.correos_procesados
  add column if not exists grupo_resumen text not null default 'otros',
  add column if not exists grupo_asignado_por text not null default 'migracion';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'correos_procesados_grupo_resumen_check'
      and conrelid = 'public.correos_procesados'::regclass
  ) then
    alter table public.correos_procesados
      add constraint correos_procesados_grupo_resumen_check
      check (grupo_resumen in ('tarjetas', 'servicios', 'suscripciones', 'turnos', 'otros'));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'correos_procesados_grupo_asignado_por_check'
      and conrelid = 'public.correos_procesados'::regclass
  ) then
    alter table public.correos_procesados
      add constraint correos_procesados_grupo_asignado_por_check
      check (grupo_asignado_por in ('ia', 'usuario', 'migracion'));
  end if;
end
$$;

update public.correos_procesados
set grupo_resumen = case
  when categoria = 'turno' then 'turnos'
  when categoria = 'renovacion' then 'suscripciones'
  else 'otros'
end,
grupo_asignado_por = 'migracion'
where grupo_asignado_por = 'migracion';

create index if not exists correos_usuario_grupo_procesado_idx
  on public.correos_procesados (usuario_id, grupo_resumen)
  where estado_procesamiento in ('procesado', 'ignorado');

alter table public.eventos_calendar
  alter column google_event_id drop not null,
  alter column calendar_id drop not null,
  add column if not exists titulo text not null default '',
  add column if not exists descripcion text not null default '',
  add column if not exists zona_horaria text not null default 'America/Argentina/Cordoba',
  add column if not exists es_dia_completo boolean not null default true,
  add column if not exists recordatorio_minutos integer not null default 1440
    check (recordatorio_minutos between 0 and 40320),
  add column if not exists estado_google text not null default 'no_conectado',
  add column if not exists error_google text,
  add column if not exists google_sincronizado_en timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'eventos_calendar_estado_google_check'
      and conrelid = 'public.eventos_calendar'::regclass
  ) then
    alter table public.eventos_calendar
      add constraint eventos_calendar_estado_google_check
      check (estado_google in ('no_conectado', 'pendiente', 'sincronizado', 'error'));
  end if;
end
$$;

update public.eventos_calendar e
set
  titulo = coalesce(nullif(e.titulo, ''), v.titulo),
  descripcion = coalesce(nullif(e.descripcion, ''), v.descripcion),
  zona_horaria = v.zona_horaria,
  es_dia_completo = v.hora_vencimiento is null,
  estado_google = case when e.google_event_id is null then 'pendiente' else 'sincronizado' end,
  google_sincronizado_en = case when e.google_event_id is not null then coalesce(e.google_sincronizado_en, e.creado_en) end
from public.vencimientos_detectados v
where v.id = e.vencimiento_id;

create index if not exists eventos_google_pendientes_idx
  on public.eventos_calendar (usuario_id, fecha_evento)
  where estado_google in ('pendiente', 'error') and estado_sincronizacion <> 'eliminado';

create table if not exists public.tareas_calendar (
  id uuid primary key default gen_random_uuid(),
  evento_id uuid not null unique references public.eventos_calendar(id) on delete cascade,
  usuario_id uuid not null references public.perfiles(id) on delete cascade,
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'procesando', 'completada', 'error')),
  intentos integer not null default 0 check (intentos >= 0),
  ultimo_error text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

drop trigger if exists actualizar_marca_temporal on public.tareas_calendar;
create trigger actualizar_marca_temporal
before update on public.tareas_calendar
for each row execute function public.actualizar_marca_temporal();

alter table public.tareas_calendar enable row level security;
revoke all on public.tareas_calendar from public, anon, authenticated;

create index if not exists tareas_calendar_estado_idx
  on public.tareas_calendar (estado, creado_en);

create or replace function public.actualizar_grupo_correo(
  correo_id uuid,
  grupo text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Sesión requerida';
  end if;
  if grupo not in ('tarjetas', 'servicios', 'suscripciones', 'turnos', 'otros') then
    raise exception 'Categoría inválida';
  end if;

  update public.correos_procesados
  set grupo_resumen = grupo, grupo_asignado_por = 'usuario'
  where id = correo_id and usuario_id = (select auth.uid());
  if not found then
    raise exception 'Correo no encontrado';
  end if;
end
$$;

revoke execute on function public.actualizar_grupo_correo(uuid, text) from public, anon;
grant execute on function public.actualizar_grupo_correo(uuid, text) to authenticated;

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
  evento_id uuid;
  calendar_activo boolean;
  tarea_id uuid;
begin
  select e.id into evento_id
  from public.eventos_calendar e
  where e.vencimiento_id = p_vencimiento_id and e.usuario_id = p_usuario_id;

  if evento_id is null then
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
    where v.id = p_vencimiento_id and v.usuario_id = p_usuario_id
    returning id into evento_id;

    if evento_id is null then
      raise exception 'Vencimiento no encontrado';
    end if;

    update public.vencimientos_detectados
    set estado = 'evento_creado'
    where id = p_vencimiento_id and usuario_id = p_usuario_id;

    insert into public.consumos_mensuales (usuario_id, periodo, eventos_creados)
    values (p_usuario_id, date_trunc('month', current_date)::date, 1)
    on conflict (usuario_id, periodo) do update
      set eventos_creados = public.consumos_mensuales.eventos_creados + 1;
  end if;

  update public.conexiones_google
  set agenda_ultima_actualizacion_en = now()
  where usuario_id = p_usuario_id;

  select c.calendar_conectado and c.estado_conexion = 'activa'
  into calendar_activo
  from public.conexiones_google c
  where c.usuario_id = p_usuario_id;

  if coalesce(calendar_activo, false) then
    insert into public.tareas_calendar (evento_id, usuario_id, estado)
    values (evento_id, p_usuario_id, 'pendiente')
    on conflict (evento_id) do update
      set estado = case
        when public.tareas_calendar.estado = 'completada' then public.tareas_calendar.estado
        else 'pendiente'
      end
    returning id into tarea_id;

    if exists (
      select 1 from public.tareas_calendar
      where id = tarea_id and estado = 'pendiente'
    ) and not exists (
      select 1
      from pgmq.q_calendar_sync q
      where (q.message->>'tarea_id')::uuid = tarea_id
    ) then
      perform pgmq.send(
        'calendar_sync',
        jsonb_build_object('tarea_id', tarea_id, 'evento_id', evento_id, 'usuario_id', p_usuario_id)
      );
    end if;
  end if;
  return evento_id;
end
$$;

create or replace function public.encolar_eventos_calendar_usuario(p_usuario_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  evento record;
  tarea_id uuid;
  total integer := 0;
begin
  for evento in
    select e.id
    from public.eventos_calendar e
    where e.usuario_id = p_usuario_id
      and e.google_event_id is null
      and e.estado_sincronizacion <> 'eliminado'
      and e.fecha_evento >= current_date
  loop
    insert into public.tareas_calendar (evento_id, usuario_id, estado)
    values (evento.id, p_usuario_id, 'pendiente')
    on conflict (evento_id) do update
      set estado = case
        when public.tareas_calendar.estado = 'completada' then 'pendiente'
        else public.tareas_calendar.estado
      end
    returning id into tarea_id;

    if not exists (
      select 1 from pgmq.q_calendar_sync q
      where (q.message->>'tarea_id')::uuid = tarea_id
    ) then
      perform pgmq.send(
        'calendar_sync',
        jsonb_build_object('tarea_id', tarea_id, 'evento_id', evento.id, 'usuario_id', p_usuario_id)
      );
      total := total + 1;
    end if;
  end loop;
  return total;
end
$$;

create or replace function public.leer_tareas_calendar(p_cantidad integer default 3)
returns table (
  msg_id bigint,
  read_ct integer,
  tarea_id uuid,
  evento_id uuid,
  usuario_id uuid,
  intentos integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  mensaje record;
begin
  for mensaje in
    select * from pgmq.read('calendar_sync', 180, least(greatest(p_cantidad, 1), 5))
  loop
    update public.tareas_calendar t
    set estado = 'procesando'
    where t.id = (mensaje.message->>'tarea_id')::uuid;

    msg_id := mensaje.msg_id;
    read_ct := mensaje.read_ct;
    tarea_id := (mensaje.message->>'tarea_id')::uuid;
    evento_id := (mensaje.message->>'evento_id')::uuid;
    usuario_id := (mensaje.message->>'usuario_id')::uuid;
    select t.intentos into intentos from public.tareas_calendar t where t.id = tarea_id;
    return next;
  end loop;
end
$$;

create or replace function public.finalizar_tarea_calendar(
  p_msg_id bigint,
  p_tarea_id uuid,
  p_error text default null,
  p_reintentar boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
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
  where id = p_tarea_id;

  if not p_reintentar then
    perform pgmq.delete('calendar_sync', p_msg_id);
  end if;
end
$$;

revoke execute on function public.registrar_evento_agenda(uuid, uuid, text, text, timestamptz, text, boolean, integer)
  from public, anon, authenticated;
revoke execute on function public.encolar_eventos_calendar_usuario(uuid)
  from public, anon, authenticated;
revoke execute on function public.leer_tareas_calendar(integer)
  from public, anon, authenticated;
revoke execute on function public.finalizar_tarea_calendar(bigint, uuid, text, boolean)
  from public, anon, authenticated;
grant execute on function public.registrar_evento_agenda(uuid, uuid, text, text, timestamptz, text, boolean, integer)
  to service_role;
grant execute on function public.encolar_eventos_calendar_usuario(uuid) to service_role;
grant execute on function public.leer_tareas_calendar(integer) to service_role;
grant execute on function public.finalizar_tarea_calendar(bigint, uuid, text, boolean) to service_role;

create or replace function private.obtener_panel_usuario()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'dias_usando_agenkin', greatest(
      1,
      (now() at time zone 'America/Argentina/Cordoba')::date
        - (p.fecha_registro at time zone 'America/Argentina/Cordoba')::date
        + 1
    ),
    'correos_analizados_total', (
      select count(*)
      from public.correos_procesados cp
      where cp.usuario_id = (select auth.uid())
        and cp.estado_procesamiento in ('procesado', 'ignorado')
    ),
    'categorias_resumen', jsonb_build_object(
      'tarjetas', count(*) filter (where cp.grupo_resumen = 'tarjetas'),
      'servicios', count(*) filter (where cp.grupo_resumen = 'servicios'),
      'suscripciones', count(*) filter (where cp.grupo_resumen = 'suscripciones'),
      'turnos', count(*) filter (where cp.grupo_resumen = 'turnos'),
      'otros', count(*) filter (where cp.grupo_resumen = 'otros')
    ),
    'eventos_creados', coalesce(cm.eventos_creados, 0),
    'vencimientos_detectados', (
      select count(*) from public.vencimientos_detectados v
      where v.usuario_id = (select auth.uid())
    ),
    'pendientes_revision', (
      select count(*) from public.vencimientos_detectados v
      where v.usuario_id = (select auth.uid()) and v.estado = 'pendiente'
    ),
    'suscripcion', jsonb_build_object(
      'plan', pl.nombre,
      'estado', s.estado,
      'fecha_inicio', s.fecha_inicio,
      'fecha_vencimiento', s.fecha_vencimiento,
      'limite_correos_mensuales', pl.limite_correos_mensuales,
      'correos_mes', coalesce(cm.correos_procesados, 0)
    )
  )
  from public.perfiles p
  join public.suscripciones s on s.usuario_id = p.id
  join public.planes pl on pl.id = s.plan_id
  left join public.consumos_mensuales cm
    on cm.usuario_id = p.id and cm.periodo = date_trunc('month', current_date)::date
  left join public.correos_procesados cp
    on cp.usuario_id = p.id and cp.estado_procesamiento in ('procesado', 'ignorado')
  where p.id = (select auth.uid())
  group by p.id, p.fecha_registro, s.id, pl.id, cm.id;
$$;

create or replace function private.obtener_estado_conexion_google()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select jsonb_build_object(
        'conectado', c.estado_conexion = 'activa' and (c.gmail_conectado or c.calendar_conectado),
        'google_email', c.google_email,
        'gmail_email', case when c.estado_conexion = 'activa' and c.gmail_conectado then c.google_email end,
        'calendar_email', case when c.estado_conexion = 'activa' and c.calendar_conectado then c.google_email end,
        'gmail_conectado', c.estado_conexion = 'activa' and c.gmail_conectado,
        'calendar_conectado', c.estado_conexion = 'activa' and c.calendar_conectado,
        'gmail_ultima_lectura_en', c.gmail_ultima_lectura_en,
        'calendar_ultima_sincronizacion_en', c.calendar_ultima_sincronizacion_en,
        'agenda_ultima_actualizacion_en', c.agenda_ultima_actualizacion_en,
        'fecha_ultima_sincronizacion', c.fecha_ultima_sincronizacion,
        'ultima_sincronizacion_exitosa', c.ultima_sincronizacion_exitosa,
        'estado_conexion', c.estado_conexion,
        'sincronizacion_automatica', c.sincronizacion_automatica,
        'creacion_automatica_eventos', c.creacion_automatica_eventos,
        'umbral_confianza_automatica', c.umbral_confianza_automatica,
        'error_ultima_sincronizacion', c.error_ultima_sincronizacion,
        'tareas_pendientes', (
          select count(*) from public.tareas_correos_gmail t
          where t.usuario_id = c.usuario_id and t.estado in ('pendiente', 'procesando')
        ),
        'tareas_error', (
          select count(*) from public.tareas_correos_gmail t
          where t.usuario_id = c.usuario_id and t.estado = 'error'
        )
      )
      from public.conexiones_google c
      where c.usuario_id = (select auth.uid())
    ),
    jsonb_build_object(
      'conectado', false,
      'gmail_email', null,
      'calendar_email', null,
      'gmail_conectado', false,
      'calendar_conectado', false,
      'estado_conexion', 'desconectada',
      'sincronizacion_automatica', false,
      'creacion_automatica_eventos', false,
      'tareas_pendientes', 0,
      'tareas_error', 0
    )
  );
$$;

do $$
declare
  trabajo record;
begin
  for trabajo in
    select jobid from cron.job where jobname = 'agenkin-procesar-calendar'
  loop
    perform cron.unschedule(trabajo.jobid);
  end loop;

  perform cron.schedule(
    'agenkin-procesar-calendar',
    '* * * * *',
    $tarea$
      select net.http_post(
        url := (
          select decrypted_secret from vault.decrypted_secrets
          where name = 'agenkin_project_url'
        ) || '/functions/v1/process-calendar-queue',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-agenkin-cron-secret', (
            select decrypted_secret from vault.decrypted_secrets
            where name = 'agenkin_cron_secret'
          )
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 120000
      );
    $tarea$
  );
end
$$;

alter table public.conexiones_google
  add column if not exists sincronizacion_automatica boolean not null default false,
  add column if not exists creacion_automatica_eventos boolean not null default false,
  add column if not exists umbral_confianza_automatica numeric(4,3) not null default 0.900,
  add column if not exists gmail_history_id text,
  add column if not exists gmail_history_objetivo text,
  add column if not exists gmail_page_token text,
  add column if not exists sincronizacion_inicial_completa boolean not null default false,
  add column if not exists proxima_sincronizacion timestamptz,
  add column if not exists ultima_sincronizacion_exitosa timestamptz,
  add column if not exists error_ultima_sincronizacion text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'conexiones_google_umbral_confianza_automatica_check'
      and conrelid = 'public.conexiones_google'::regclass
  ) then
    alter table public.conexiones_google
      add constraint conexiones_google_umbral_confianza_automatica_check
      check (umbral_confianza_automatica between 0.500 and 1.000);
  end if;
end
$$;

create table if not exists public.tareas_correos_gmail (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.perfiles(id) on delete cascade,
  gmail_message_id text not null,
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'procesando', 'completada', 'error')),
  intentos integer not null default 0 check (intentos >= 0),
  ultimo_error text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (usuario_id, gmail_message_id)
);

drop trigger if exists actualizar_marca_temporal on public.tareas_correos_gmail;
create trigger actualizar_marca_temporal
before update on public.tareas_correos_gmail
for each row execute function public.actualizar_marca_temporal();

create index if not exists tareas_correos_gmail_usuario_estado_idx
  on public.tareas_correos_gmail (usuario_id, estado, creado_en);

create index if not exists conexiones_google_proxima_automatica_idx
  on public.conexiones_google (proxima_sincronizacion)
  where sincronizacion_automatica and estado_conexion = 'activa';

create index if not exists vencimientos_automaticos_pendientes_idx
  on public.vencimientos_detectados (fecha_vencimiento, usuario_id)
  include (confianza, zona_horaria)
  where estado = 'pendiente' and not requiere_revision;

alter table public.tareas_correos_gmail enable row level security;
revoke all on public.tareas_correos_gmail from public, anon, authenticated;

create or replace function public.configurar_automatizacion_google(
  p_sincronizacion_automatica boolean,
  p_creacion_automatica_eventos boolean,
  p_umbral_confianza numeric default 0.900
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  resultado jsonb;
begin
  if (select auth.uid()) is null then
    raise exception 'Sesión requerida';
  end if;
  if p_umbral_confianza < 0.500 or p_umbral_confianza > 1.000 then
    raise exception 'Umbral de confianza inválido';
  end if;

  update public.conexiones_google
  set
    sincronizacion_automatica = p_sincronizacion_automatica or p_creacion_automatica_eventos,
    creacion_automatica_eventos = p_creacion_automatica_eventos,
    umbral_confianza_automatica = p_umbral_confianza,
    proxima_sincronizacion = case
      when p_sincronizacion_automatica or p_creacion_automatica_eventos then now()
      else null
    end,
    error_ultima_sincronizacion = null
  where usuario_id = (select auth.uid())
    and estado_conexion = 'activa'
    and gmail_conectado
  returning jsonb_build_object(
    'sincronizacion_automatica', sincronizacion_automatica,
    'creacion_automatica_eventos', creacion_automatica_eventos,
    'umbral_confianza_automatica', umbral_confianza_automatica
  ) into resultado;

  if resultado is null then
    raise exception 'Conectá Gmail antes de activar la automatización';
  end if;
  return resultado;
end
$$;

revoke execute on function public.configurar_automatizacion_google(boolean, boolean, numeric)
  from public, anon;
grant execute on function public.configurar_automatizacion_google(boolean, boolean, numeric)
  to authenticated;

create or replace function public.registrar_tareas_correos_gmail(
  p_usuario_id uuid,
  p_gmail_message_ids text[]
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  tarea record;
  total integer := 0;
begin
  for tarea in
    insert into public.tareas_correos_gmail (usuario_id, gmail_message_id)
    select p_usuario_id, identificador
    from unnest(p_gmail_message_ids) as identificador
    where identificador <> ''
    on conflict (usuario_id, gmail_message_id) do nothing
    returning id, usuario_id, gmail_message_id
  loop
    perform pgmq.send(
      'gmail_sync',
      jsonb_build_object(
        'tarea_id', tarea.id,
        'usuario_id', tarea.usuario_id,
        'gmail_message_id', tarea.gmail_message_id
      )
    );
    total := total + 1;
  end loop;
  return total;
end
$$;

create or replace function public.leer_tareas_correos_gmail(p_cantidad integer default 2)
returns table (
  msg_id bigint,
  read_ct integer,
  intentos integer,
  tarea_id uuid,
  usuario_id uuid,
  gmail_message_id text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  mensaje record;
begin
  for mensaje in
    select *
    from pgmq.read('gmail_sync', 240, least(greatest(p_cantidad, 1), 5))
  loop
    update public.tareas_correos_gmail t
    set estado = 'procesando'
    where t.id = (mensaje.message->>'tarea_id')::uuid;

    msg_id := mensaje.msg_id;
    read_ct := mensaje.read_ct;
    tarea_id := (mensaje.message->>'tarea_id')::uuid;
    usuario_id := (mensaje.message->>'usuario_id')::uuid;
    gmail_message_id := mensaje.message->>'gmail_message_id';
    select t.intentos
    into intentos
    from public.tareas_correos_gmail t
    where t.id = tarea_id;
    return next;
  end loop;
end
$$;

create or replace function public.finalizar_tarea_correo_gmail(
  p_msg_id bigint,
  p_tarea_id uuid,
  p_error text default null,
  p_reintentar boolean default false,
  p_retraso_segundos integer default 0,
  p_contar_intento boolean default true
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  tarea public.tareas_correos_gmail%rowtype;
begin
  if p_reintentar then
    update public.tareas_correos_gmail
    set
      estado = 'pendiente',
      intentos = intentos + case when p_contar_intento then 1 else 0 end,
      ultimo_error = left(coalesce(p_error, 'REINTENTO'), 100)
    where id = p_tarea_id
    returning * into tarea;

    if p_retraso_segundos > 0 and tarea.id is not null then
      perform pgmq.delete('gmail_sync', p_msg_id);
      perform pgmq.send(
        'gmail_sync',
        jsonb_build_object(
          'tarea_id', tarea.id,
          'usuario_id', tarea.usuario_id,
          'gmail_message_id', tarea.gmail_message_id
        ),
        least(greatest(p_retraso_segundos, 0), 604800)
      );
    end if;
    return;
  end if;

  update public.tareas_correos_gmail
  set
    estado = case when p_error is null then 'completada' else 'error' end,
    intentos = intentos + 1,
    ultimo_error = left(p_error, 100)
  where id = p_tarea_id;
  perform pgmq.delete('gmail_sync', p_msg_id);
end
$$;

create or replace function public.reclamar_sincronizaciones_google(p_limite integer default 3)
returns table (
  usuario_id uuid,
  refresh_token_cifrado text,
  token_iv text,
  gmail_history_id text,
  gmail_history_objetivo text,
  gmail_page_token text,
  sincronizacion_inicial_completa boolean
)
language sql
security definer
set search_path = ''
as $$
  with candidatas as (
    select c.id
    from public.conexiones_google c
    where c.sincronizacion_automatica
      and c.estado_conexion = 'activa'
      and c.gmail_conectado
      and c.refresh_token_cifrado is not null
      and c.token_iv is not null
      and (c.proxima_sincronizacion is null or c.proxima_sincronizacion <= now())
    order by c.proxima_sincronizacion nulls first, c.actualizado_en
    limit least(greatest(p_limite, 1), 10)
    for update skip locked
  ),
  actualizadas as (
    update public.conexiones_google c
    set proxima_sincronizacion = now() + interval '5 minutes'
    from candidatas
    where c.id = candidatas.id
    returning c.*
  )
  select
    a.usuario_id,
    a.refresh_token_cifrado,
    a.token_iv,
    a.gmail_history_id,
    a.gmail_history_objetivo,
    a.gmail_page_token,
    a.sincronizacion_inicial_completa
  from actualizadas a;
$$;

create or replace function public.obtener_eventos_automaticos_pendientes(p_limite integer default 5)
returns table (
  usuario_id uuid,
  vencimiento_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select v.usuario_id, v.id
  from public.vencimientos_detectados v
  join public.conexiones_google c on c.usuario_id = v.usuario_id
  join public.perfiles p on p.id = v.usuario_id
  where c.estado_conexion = 'activa'
    and c.creacion_automatica_eventos
    and v.estado = 'pendiente'
    and not v.requiere_revision
    and v.confianza >= c.umbral_confianza_automatica
    and v.fecha_vencimiento >= (now() at time zone v.zona_horaria)::date
    and p.estado_acceso = 'activo'
    and exists (
      select 1
      from public.suscripciones s
      where s.usuario_id = v.usuario_id
        and s.estado in ('prueba', 'activa')
        and s.fecha_vencimiento >= now()
    )
    and not exists (
      select 1
      from public.eventos_calendar e
      where e.vencimiento_id = v.id
    )
  order by v.fecha_vencimiento, v.creado_en
  limit least(greatest(p_limite, 1), 20);
$$;

create or replace function public.registrar_evento_calendar(
  p_usuario_id uuid,
  p_vencimiento_id uuid,
  p_google_event_id text,
  p_calendar_id text,
  p_fecha_evento timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  evento_insertado uuid;
begin
  insert into public.eventos_calendar (
    usuario_id,
    vencimiento_id,
    google_event_id,
    calendar_id,
    fecha_evento
  )
  select
    p_usuario_id,
    v.id,
    p_google_event_id,
    p_calendar_id,
    p_fecha_evento
  from public.vencimientos_detectados v
  where v.id = p_vencimiento_id
    and v.usuario_id = p_usuario_id
  on conflict (vencimiento_id) do nothing
  returning id into evento_insertado;

  if evento_insertado is null then
    if exists (
      select 1
      from public.eventos_calendar e
      where e.vencimiento_id = p_vencimiento_id
        and e.usuario_id = p_usuario_id
    ) then
      update public.vencimientos_detectados
      set estado = 'evento_creado'
      where id = p_vencimiento_id and usuario_id = p_usuario_id;
      return false;
    end if;
    raise exception 'Vencimiento no encontrado';
  end if;

  update public.vencimientos_detectados
  set estado = 'evento_creado'
  where id = p_vencimiento_id and usuario_id = p_usuario_id;

  insert into public.consumos_mensuales (usuario_id, periodo, eventos_creados)
  values (p_usuario_id, date_trunc('month', current_date)::date, 1)
  on conflict (usuario_id, periodo) do update
    set eventos_creados = public.consumos_mensuales.eventos_creados + 1;
  return true;
end
$$;

revoke execute on function public.registrar_tareas_correos_gmail(uuid, text[])
  from public, anon, authenticated;
revoke execute on function public.leer_tareas_correos_gmail(integer)
  from public, anon, authenticated;
revoke execute on function public.finalizar_tarea_correo_gmail(bigint, uuid, text, boolean, integer, boolean)
  from public, anon, authenticated;
revoke execute on function public.reclamar_sincronizaciones_google(integer)
  from public, anon, authenticated;
revoke execute on function public.obtener_eventos_automaticos_pendientes(integer)
  from public, anon, authenticated;
revoke execute on function public.registrar_evento_calendar(uuid, uuid, text, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.registrar_tareas_correos_gmail(uuid, text[]) to service_role;
grant execute on function public.leer_tareas_correos_gmail(integer) to service_role;
grant execute on function public.finalizar_tarea_correo_gmail(bigint, uuid, text, boolean, integer, boolean) to service_role;
grant execute on function public.reclamar_sincronizaciones_google(integer) to service_role;
grant execute on function public.obtener_eventos_automaticos_pendientes(integer) to service_role;
grant execute on function public.registrar_evento_calendar(uuid, uuid, text, text, timestamptz) to service_role;

create or replace function private.obtener_estado_conexion_google()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select jsonb_build_object(
        'conectado', c.estado_conexion = 'activa' and (c.gmail_conectado or c.calendar_conectado),
        'google_email', c.google_email,
        'gmail_email', case when c.estado_conexion = 'activa' and c.gmail_conectado then c.google_email end,
        'calendar_email', case when c.estado_conexion = 'activa' and c.calendar_conectado then c.google_email end,
        'gmail_conectado', c.estado_conexion = 'activa' and c.gmail_conectado,
        'calendar_conectado', c.estado_conexion = 'activa' and c.calendar_conectado,
        'gmail_ultima_lectura_en', c.gmail_ultima_lectura_en,
        'calendar_ultima_sincronizacion_en', c.calendar_ultima_sincronizacion_en,
        'agenda_ultima_actualizacion_en', c.agenda_ultima_actualizacion_en,
        'fecha_ultima_sincronizacion', c.fecha_ultima_sincronizacion,
        'ultima_sincronizacion_exitosa', c.ultima_sincronizacion_exitosa,
        'estado_conexion', c.estado_conexion,
        'sincronizacion_automatica', c.sincronizacion_automatica,
        'creacion_automatica_eventos', c.creacion_automatica_eventos,
        'umbral_confianza_automatica', c.umbral_confianza_automatica,
        'error_ultima_sincronizacion', c.error_ultima_sincronizacion,
        'tareas_pendientes', (
          select count(*)
          from public.tareas_correos_gmail t
          where t.usuario_id = c.usuario_id and t.estado in ('pendiente', 'procesando')
        ),
        'tareas_error', (
          select count(*)
          from public.tareas_correos_gmail t
          where t.usuario_id = c.usuario_id and t.estado = 'error'
        )
      )
      from public.conexiones_google c
      where c.usuario_id = (select auth.uid())
    ),
    jsonb_build_object(
      'conectado', false,
      'gmail_email', null,
      'calendar_email', null,
      'gmail_conectado', false,
      'calendar_conectado', false,
      'estado_conexion', 'desconectada',
      'sincronizacion_automatica', false,
      'creacion_automatica_eventos', false,
      'tareas_pendientes', 0,
      'tareas_error', 0
    )
  );
$$;

do $$
declare
  trabajo record;
begin
  for trabajo in
    select jobid
    from cron.job
    where jobname in (
      'agenkin-descubrir-gmail',
      'agenkin-procesar-gmail',
      'agenkin-crear-eventos'
    )
  loop
    perform cron.unschedule(trabajo.jobid);
  end loop;

  perform cron.schedule(
    'agenkin-descubrir-gmail',
    '*/5 * * * *',
    $tarea$
      select net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'agenkin_project_url'
        ) || '/functions/v1/sync-gmail-scheduled',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-agenkin-cron-secret', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'agenkin_cron_secret'
          )
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 30000
      );
    $tarea$
  );

  perform cron.schedule(
    'agenkin-procesar-gmail',
    '* * * * *',
    $tarea$
      select net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'agenkin_project_url'
        ) || '/functions/v1/process-gmail-queue',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-agenkin-cron-secret', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'agenkin_cron_secret'
          )
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 150000
      );
    $tarea$
  );

  perform cron.schedule(
    'agenkin-crear-eventos',
    '*/2 * * * *',
    $tarea$
      select net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'agenkin_project_url'
        ) || '/functions/v1/create-calendar-scheduled',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-agenkin-cron-secret', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'agenkin_cron_secret'
          )
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 120000
      );
    $tarea$
  );
end
$$;
