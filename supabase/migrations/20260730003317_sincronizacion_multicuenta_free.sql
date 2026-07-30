-- Sincronización multicuenta optimizada para la beta en Supabase Free.
-- La Agenda interna sigue siendo la fuente principal y los cuerpos de correo
-- nunca se persisten.

-- Los workers se reanudan en una migración posterior, después de desplegar
-- las Edge Functions compatibles con este esquema.
do $$
declare
  trabajo record;
begin
  for trabajo in
    select jobid
    from cron.job
    where jobname in (
      'agenkin-crear-eventos',
      'agenkin-descubrir-gmail',
      'agenkin-limpiar-oauth-states',
      'agenkin-procesar-calendar',
      'agenkin-procesar-gmail'
    )
  loop
    perform cron.unschedule(trabajo.jobid);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------
-- Planes: el límite comercial pasa de mensajes a cuentas Gmail.
-- ---------------------------------------------------------------------------

alter table public.planes
  add column if not exists limite_cuentas_gmail integer not null default 1,
  add column if not exists es_interno boolean not null default false,
  add column if not exists visible_publico boolean not null default true;

do $$
begin
  if exists (select 1 from public.planes where nombre = 'Profesional')
    and not exists (select 1 from public.planes where nombre = 'Pro') then
    update public.planes set nombre = 'Pro' where nombre = 'Profesional';
  end if;
end
$$;

insert into public.planes (
  nombre,
  descripcion,
  precio,
  moneda,
  limite_correos_mensuales,
  limite_cuentas_gmail,
  permite_automatizacion,
  es_interno,
  visible_publico,
  activo
)
values
  ('Prueba', 'Período inicial con una cuenta Gmail.', 0, 'ARS', 2147483647, 1, true, false, true, true),
  ('Básico', 'Sincronización personal con una cuenta Gmail.', 0, 'ARS', 2147483647, 1, true, false, true, true),
  ('Dúo', 'Sincronización de dos cuentas Gmail.', 0, 'ARS', 2147483647, 2, true, false, true, true),
  ('Pro', 'Sincronización de hasta tres cuentas Gmail.', 0, 'ARS', 2147483647, 3, true, false, true, true),
  ('Ultra', 'Sincronización de hasta cinco cuentas Gmail.', 0, 'ARS', 2147483647, 5, true, false, true, true),
  ('AgenKin', 'Plan interno equivalente a Pro.', 0, 'ARS', 2147483647, 3, true, true, false, true)
on conflict (nombre) do update set
  descripcion = excluded.descripcion,
  precio = excluded.precio,
  moneda = excluded.moneda,
  limite_correos_mensuales = excluded.limite_correos_mensuales,
  limite_cuentas_gmail = excluded.limite_cuentas_gmail,
  permite_automatizacion = excluded.permite_automatizacion,
  es_interno = excluded.es_interno,
  visible_publico = excluded.visible_publico,
  activo = excluded.activo,
  actualizado_en = now();

comment on column public.planes.limite_correos_mensuales is
  'Columna heredada sin efecto comercial. AgenKin limita cuentas Gmail, no mensajes.';
comment on column public.planes.limite_cuentas_gmail is
  'Cantidad máxima de cuentas Gmail activas que puede conectar el usuario.';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'planes_limite_cuentas_gmail_check'
      and conrelid = 'public.planes'::regclass
  ) then
    alter table public.planes
      add constraint planes_limite_cuentas_gmail_check
      check (limite_cuentas_gmail between 1 and 5);
  end if;
end
$$;

create or replace function private.validar_cupo_al_cambiar_plan()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_limite integer;
  v_usadas integer;
begin
  if new.plan_id is not distinct from old.plan_id then
    return new;
  end if;

  select p.limite_cuentas_gmail
  into v_limite
  from public.planes p
  where p.id = new.plan_id
    and p.activo;
  if v_limite is null then
    raise exception 'PLAN_INVALIDO';
  end if;

  select count(*)
  into v_usadas
  from public.conexiones_google c
  where c.usuario_id = new.usuario_id
    and c.gmail_conectado
    and c.estado_conexion = 'activa';
  if v_usadas > v_limite then
    raise exception 'CUENTAS_GMAIL_EXCEDEN_NUEVO_PLAN';
  end if;

  return new;
end
$$;

revoke execute on function private.validar_cupo_al_cambiar_plan()
  from public, anon, authenticated;

drop trigger if exists suscripciones_validar_cupo_plan
  on public.suscripciones;
create trigger suscripciones_validar_cupo_plan
before update of plan_id on public.suscripciones
for each row execute function private.validar_cupo_al_cambiar_plan();

-- ---------------------------------------------------------------------------
-- Identidad estable de Google y asociaciones multicuenta.
-- ---------------------------------------------------------------------------

alter table public.conexiones_google
  add column if not exists google_subject_id text,
  add column if not exists es_calendar_principal boolean not null default false,
  add column if not exists ultima_solicitud_manual_en timestamptz;

update public.conexiones_google
set google_subject_id = 'legacy:' || id::text
where google_subject_id is null or btrim(google_subject_id) = '';

update public.conexiones_google
set es_calendar_principal = true
where calendar_conectado
  and estado_conexion = 'activa'
  and not exists (
    select 1
    from public.conexiones_google otra
    where otra.usuario_id = conexiones_google.usuario_id
      and otra.es_calendar_principal
  );

alter table public.conexiones_google
  alter column google_subject_id set not null;

alter table public.conexiones_google
  drop constraint if exists conexiones_google_usuario_id_key;

create unique index if not exists conexiones_google_usuario_subject_uidx
  on public.conexiones_google (usuario_id, google_subject_id);
create unique index if not exists conexiones_google_id_usuario_uidx
  on public.conexiones_google (id, usuario_id);
create unique index if not exists correos_procesados_id_usuario_uidx
  on public.correos_procesados (id, usuario_id);
create unique index if not exists vencimientos_id_usuario_uidx
  on public.vencimientos_detectados (id, usuario_id);
create unique index if not exists eventos_calendar_id_usuario_uidx
  on public.eventos_calendar (id, usuario_id);

create unique index if not exists conexiones_google_calendar_principal_uidx
  on public.conexiones_google (usuario_id)
  where es_calendar_principal and calendar_conectado and estado_conexion = 'activa';

create index if not exists conexiones_google_usuario_gmail_idx
  on public.conexiones_google (usuario_id, creado_en)
  where gmail_conectado and estado_conexion = 'activa';

alter table public.oauth_states
  add column if not exists conexion_google_id uuid
    references public.conexiones_google(id) on delete cascade;

alter table public.correos_procesados
  add column if not exists conexion_google_id uuid
    references public.conexiones_google(id) on delete restrict,
  add column if not exists origen_analisis text not null default 'ia',
  add column if not exists patron_id uuid,
  add column if not exists huella_plantilla text,
  add column if not exists tokens_entrada integer,
  add column if not exists tokens_cache integer,
  add column if not exists tokens_salida integer,
  add column if not exists duracion_ia_ms integer,
  add column if not exists metricas_registradas_en timestamptz,
  add column if not exists detalle_compactado boolean not null default false;

alter table public.tareas_correos_gmail
  add column if not exists conexion_google_id uuid
    references public.conexiones_google(id) on delete cascade,
  add column if not exists disponible_en timestamptz not null default now(),
  add column if not exists reclamada_en timestamptz;

alter table public.eventos_calendar
  add column if not exists conexion_google_id uuid
    references public.conexiones_google(id) on delete set null;

with conexiones_elegidas as (
  select distinct on (usuario_id) usuario_id, id
  from public.conexiones_google
  order by usuario_id, gmail_conectado desc, creado_en
)
update public.correos_procesados correo
set conexion_google_id = elegida.id
from conexiones_elegidas elegida
where elegida.usuario_id = correo.usuario_id
  and correo.conexion_google_id is null;

with conexiones_elegidas as (
  select distinct on (usuario_id) usuario_id, id
  from public.conexiones_google
  order by usuario_id, gmail_conectado desc, creado_en
)
update public.tareas_correos_gmail tarea
set conexion_google_id = elegida.id
from conexiones_elegidas elegida
where elegida.usuario_id = tarea.usuario_id
  and tarea.conexion_google_id is null;

with calendarios_elegidos as (
  select distinct on (usuario_id) usuario_id, id
  from public.conexiones_google
  order by usuario_id, es_calendar_principal desc, calendar_conectado desc, creado_en
)
update public.eventos_calendar evento
set conexion_google_id = elegida.id
from calendarios_elegidos elegida
where elegida.usuario_id = evento.usuario_id
  and evento.google_event_id is not null
  and evento.conexion_google_id is null;

do $$
begin
  if exists (
    select 1
    from public.correos_procesados
    where conexion_google_id is null
  ) then
    raise exception 'MIGRACION_ABORTADA_CORREOS_SIN_CONEXION';
  end if;
  if exists (
    select 1
    from public.tareas_correos_gmail
    where conexion_google_id is null
  ) then
    raise exception 'MIGRACION_ABORTADA_TAREAS_SIN_CONEXION';
  end if;
end
$$;

alter table public.correos_procesados
  alter column conexion_google_id set not null;
alter table public.tareas_correos_gmail
  alter column conexion_google_id set not null;

alter table public.correos_procesados
  drop constraint if exists correos_procesados_conexion_google_id_fkey;
alter table public.correos_procesados
  add constraint correos_procesados_conexion_google_id_fkey
  foreign key (conexion_google_id)
  references public.conexiones_google(id) on delete cascade;

do $$
begin
  if exists (
    select 1
    from public.correos_procesados cp
    join public.conexiones_google c on c.id = cp.conexion_google_id
    where cp.usuario_id <> c.usuario_id
  ) or exists (
    select 1
    from public.tareas_correos_gmail t
    join public.conexiones_google c on c.id = t.conexion_google_id
    where t.usuario_id <> c.usuario_id
  ) or exists (
    select 1
    from public.eventos_calendar e
    join public.conexiones_google c on c.id = e.conexion_google_id
    where e.usuario_id <> c.usuario_id
  ) or exists (
    select 1
    from public.oauth_states o
    join public.conexiones_google c on c.id = o.conexion_google_id
    where o.usuario_id <> c.usuario_id
  ) or exists (
    select 1
    from public.vencimientos_detectados v
    join public.correos_procesados cp on cp.id = v.correo_id
    where v.usuario_id <> cp.usuario_id
  ) or exists (
    select 1
    from public.eventos_calendar e
    join public.vencimientos_detectados v on v.id = e.vencimiento_id
    where e.usuario_id <> v.usuario_id
  ) or exists (
    select 1
    from public.tareas_calendar tc
    join public.eventos_calendar e on e.id = tc.evento_id
    where tc.usuario_id <> e.usuario_id
  ) then
    raise exception 'MIGRACION_ABORTADA_ASOCIACION_DE_OTRO_USUARIO';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'correos_conexion_usuario_fkey'
  ) then
    alter table public.correos_procesados
      add constraint correos_conexion_usuario_fkey
      foreign key (conexion_google_id, usuario_id)
      references public.conexiones_google(id, usuario_id) on delete cascade;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'tareas_gmail_conexion_usuario_fkey'
  ) then
    alter table public.tareas_correos_gmail
      add constraint tareas_gmail_conexion_usuario_fkey
      foreign key (conexion_google_id, usuario_id)
      references public.conexiones_google(id, usuario_id) on delete cascade;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'eventos_conexion_usuario_fkey'
  ) then
    alter table public.eventos_calendar
      add constraint eventos_conexion_usuario_fkey
      foreign key (conexion_google_id, usuario_id)
      references public.conexiones_google(id, usuario_id)
      on delete set null (conexion_google_id);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'oauth_states_conexion_usuario_fkey'
  ) then
    alter table public.oauth_states
      add constraint oauth_states_conexion_usuario_fkey
      foreign key (conexion_google_id, usuario_id)
      references public.conexiones_google(id, usuario_id) on delete cascade;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'vencimientos_correo_usuario_fkey'
  ) then
    alter table public.vencimientos_detectados
      add constraint vencimientos_correo_usuario_fkey
      foreign key (correo_id, usuario_id)
      references public.correos_procesados(id, usuario_id) on delete cascade;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'eventos_vencimiento_usuario_fkey'
  ) then
    alter table public.eventos_calendar
      add constraint eventos_vencimiento_usuario_fkey
      foreign key (vencimiento_id, usuario_id)
      references public.vencimientos_detectados(id, usuario_id) on delete cascade;
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'tareas_calendar_evento_usuario_fkey'
  ) then
    alter table public.tareas_calendar
      add constraint tareas_calendar_evento_usuario_fkey
      foreign key (evento_id, usuario_id)
      references public.eventos_calendar(id, usuario_id) on delete cascade;
  end if;
end
$$;

alter table public.correos_procesados
  drop constraint if exists correos_procesados_usuario_id_gmail_message_id_key;
alter table public.tareas_correos_gmail
  drop constraint if exists tareas_correos_gmail_usuario_id_gmail_message_id_key;

create unique index if not exists correos_conexion_mensaje_uidx
  on public.correos_procesados (conexion_google_id, gmail_message_id);
create unique index if not exists tareas_gmail_conexion_mensaje_uidx
  on public.tareas_correos_gmail (conexion_google_id, gmail_message_id);
create index if not exists tareas_gmail_disponibles_idx
  on public.tareas_correos_gmail (disponible_en, creado_en)
  where estado in ('pendiente', 'procesando');
create index if not exists eventos_calendar_conexion_idx
  on public.eventos_calendar (conexion_google_id, fecha_evento)
  where estado_sincronizacion <> 'eliminado';
create index if not exists correos_procesamiento_retencion_idx
  on public.correos_procesados (fecha_procesamiento, id);
create index if not exists correos_patron_id_idx
  on public.correos_procesados (patron_id)
  where patron_id is not null;
create index if not exists vencimientos_retencion_idx
  on public.vencimientos_detectados (fecha_vencimiento, id);
create index if not exists tareas_gmail_retencion_idx
  on public.tareas_correos_gmail (actualizado_en, id)
  where estado in ('completada', 'error');
create index if not exists tareas_calendar_retencion_idx
  on public.tareas_calendar (actualizado_en, id)
  where estado in ('completada', 'error');
create index if not exists eventos_calendar_usuario_creado_idx
  on public.eventos_calendar (usuario_id, creado_en);
create index if not exists oauth_states_conexion_idx
  on public.oauth_states (conexion_google_id)
  where conexion_google_id is not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'conexiones_google_subject_check'
      and conrelid = 'public.conexiones_google'::regclass
  ) then
    alter table public.conexiones_google
      add constraint conexiones_google_subject_check
      check (char_length(google_subject_id) between 1 and 255);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'correos_procesados_origen_analisis_check'
      and conrelid = 'public.correos_procesados'::regclass
  ) then
    alter table public.correos_procesados
      add constraint correos_procesados_origen_analisis_check
      check (origen_analisis in ('regla', 'patron_personal', 'patron_global', 'ia', 'migracion'));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'correos_procesados_metricas_check'
      and conrelid = 'public.correos_procesados'::regclass
  ) then
    alter table public.correos_procesados
      add constraint correos_procesados_metricas_check
      check (
        (tokens_entrada is null or tokens_entrada >= 0)
        and (tokens_cache is null or tokens_cache >= 0)
        and (tokens_salida is null or tokens_salida >= 0)
        and (duracion_ia_ms is null or duracion_ia_ms >= 0)
        and (
          huella_plantilla is null
          or huella_plantilla ~ '^[a-f0-9]{64}$'
        )
      );
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Patrones declarativos. No se guardan regex ni XPath ejecutables.
-- ---------------------------------------------------------------------------

create table if not exists public.patrones_correo (
  id uuid primary key default gen_random_uuid(),
  alcance text not null check (alcance in ('personal', 'global')),
  usuario_id uuid references public.perfiles(id) on delete cascade,
  dominio_remitente text not null check (char_length(dominio_remitente) between 1 and 253),
  huella_plantilla text not null check (char_length(huella_plantilla) between 16 and 128),
  selector_fecha integer not null check (selector_fecha between 0 and 20),
  selector_monto integer check (selector_monto between 0 and 20),
  clasificacion jsonb not null default '{}'::jsonb,
  estado text not null default 'aprendizaje'
    check (estado in ('aprendizaje', 'activo', 'observacion', 'pausado')),
  evidencias integer not null default 0 check (evidencias >= 0),
  coincidencias integer not null default 0 check (coincidencias >= 0),
  usuarios_evidencia integer not null default 0 check (usuarios_evidencia >= 0),
  validaciones_sombra integer not null default 0 check (validaciones_sombra >= 0),
  discrepancias integer not null default 0 check (discrepancias >= 0),
  ultimo_uso_en timestamptz,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  check (
    (alcance = 'personal' and usuario_id is not null)
    or (alcance = 'global' and usuario_id is null)
  )
);

alter table public.patrones_correo enable row level security;
revoke all on public.patrones_correo from public, anon, authenticated;
grant all on public.patrones_correo to service_role;

create unique index if not exists patrones_correo_personal_uidx
  on public.patrones_correo (usuario_id, dominio_remitente, huella_plantilla)
  where alcance = 'personal';
create unique index if not exists patrones_correo_global_uidx
  on public.patrones_correo (dominio_remitente, huella_plantilla)
  where alcance = 'global';
create index if not exists patrones_correo_busqueda_idx
  on public.patrones_correo (dominio_remitente, huella_plantilla, alcance, estado);
create index if not exists patrones_correo_retencion_idx
  on public.patrones_correo (actualizado_en, id)
  where alcance = 'personal'
    and estado in ('aprendizaje', 'observacion', 'pausado');

alter table public.correos_procesados
  drop constraint if exists correos_procesados_patron_id_fkey;
alter table public.correos_procesados
  add constraint correos_procesados_patron_id_fkey
  foreign key (patron_id) references public.patrones_correo(id) on delete set null;

drop trigger if exists actualizar_marca_temporal on public.patrones_correo;
create trigger actualizar_marca_temporal
before update on public.patrones_correo
for each row execute function public.actualizar_marca_temporal();

-- ---------------------------------------------------------------------------
-- Métricas históricas compactas.
-- ---------------------------------------------------------------------------

alter table public.consumos_mensuales
  add column if not exists grupo_tarjetas integer not null default 0,
  add column if not exists grupo_servicios integer not null default 0,
  add column if not exists grupo_suscripciones integer not null default 0,
  add column if not exists grupo_turnos integer not null default 0,
  add column if not exists grupo_otros integer not null default 0,
  add column if not exists origen_regla integer not null default 0,
  add column if not exists origen_patron integer not null default 0,
  add column if not exists origen_ia integer not null default 0,
  add column if not exists tokens_entrada bigint not null default 0,
  add column if not exists tokens_cache bigint not null default 0,
  add column if not exists tokens_salida bigint not null default 0,
  add column if not exists errores_procesamiento integer not null default 0;

insert into public.consumos_mensuales (
  usuario_id,
  periodo,
  correos_procesados,
  grupo_tarjetas,
  grupo_servicios,
  grupo_suscripciones,
  grupo_turnos,
  grupo_otros,
  origen_regla,
  origen_patron,
  origen_ia,
  tokens_entrada,
  tokens_cache,
  tokens_salida,
  errores_procesamiento
)
select
  cp.usuario_id,
  date_trunc('month', cp.fecha_procesamiento)::date,
  count(*) filter (where cp.estado_procesamiento in ('procesado', 'ignorado')),
  count(*) filter (where cp.estado_procesamiento in ('procesado', 'ignorado') and cp.grupo_resumen = 'tarjetas'),
  count(*) filter (where cp.estado_procesamiento in ('procesado', 'ignorado') and cp.grupo_resumen = 'servicios'),
  count(*) filter (where cp.estado_procesamiento in ('procesado', 'ignorado') and cp.grupo_resumen = 'suscripciones'),
  count(*) filter (where cp.estado_procesamiento in ('procesado', 'ignorado') and cp.grupo_resumen = 'turnos'),
  count(*) filter (where cp.estado_procesamiento in ('procesado', 'ignorado') and cp.grupo_resumen = 'otros'),
  count(*) filter (where cp.estado_procesamiento in ('procesado', 'ignorado') and cp.origen_analisis = 'regla'),
  count(*) filter (where cp.estado_procesamiento in ('procesado', 'ignorado') and cp.origen_analisis in ('patron_personal', 'patron_global')),
  count(*) filter (where cp.estado_procesamiento in ('procesado', 'ignorado') and cp.origen_analisis in ('ia', 'migracion')),
  coalesce(sum(cp.tokens_entrada), 0),
  coalesce(sum(cp.tokens_cache), 0),
  coalesce(sum(cp.tokens_salida), 0),
  count(*) filter (where cp.estado_procesamiento = 'error')
from public.correos_procesados cp
group by cp.usuario_id, date_trunc('month', cp.fecha_procesamiento)::date
on conflict (usuario_id, periodo) do update set
  correos_procesados = greatest(
    public.consumos_mensuales.correos_procesados,
    excluded.correos_procesados
  ),
  grupo_tarjetas = greatest(public.consumos_mensuales.grupo_tarjetas, excluded.grupo_tarjetas),
  grupo_servicios = greatest(public.consumos_mensuales.grupo_servicios, excluded.grupo_servicios),
  grupo_suscripciones = greatest(public.consumos_mensuales.grupo_suscripciones, excluded.grupo_suscripciones),
  grupo_turnos = greatest(public.consumos_mensuales.grupo_turnos, excluded.grupo_turnos),
  grupo_otros = greatest(public.consumos_mensuales.grupo_otros, excluded.grupo_otros),
  origen_regla = greatest(public.consumos_mensuales.origen_regla, excluded.origen_regla),
  origen_patron = greatest(public.consumos_mensuales.origen_patron, excluded.origen_patron),
  origen_ia = greatest(public.consumos_mensuales.origen_ia, excluded.origen_ia),
  tokens_entrada = greatest(public.consumos_mensuales.tokens_entrada, excluded.tokens_entrada),
  tokens_cache = greatest(public.consumos_mensuales.tokens_cache, excluded.tokens_cache),
  tokens_salida = greatest(public.consumos_mensuales.tokens_salida, excluded.tokens_salida),
  errores_procesamiento = greatest(
    public.consumos_mensuales.errores_procesamiento,
    excluded.errores_procesamiento
  ),
  actualizado_en = now();

update public.correos_procesados
set metricas_registradas_en = coalesce(
  metricas_registradas_en,
  fecha_procesamiento
)
where estado_procesamiento in ('procesado', 'ignorado');

create or replace function public.registrar_consumo_correo(
  p_usuario_id uuid,
  p_grupo text,
  p_origen text,
  p_estado text,
  p_tokens_entrada integer default 0,
  p_tokens_cache integer default 0,
  p_tokens_salida integer default 0
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_grupo not in ('tarjetas', 'servicios', 'suscripciones', 'turnos', 'otros') then
    raise exception 'Grupo inválido';
  end if;
  if p_origen not in ('regla', 'patron_personal', 'patron_global', 'ia', 'migracion') then
    raise exception 'Origen inválido';
  end if;
  if p_estado not in ('procesado', 'ignorado', 'error') then
    raise exception 'Estado inválido';
  end if;

  insert into public.consumos_mensuales (
    usuario_id,
    periodo,
    correos_procesados,
    grupo_tarjetas,
    grupo_servicios,
    grupo_suscripciones,
    grupo_turnos,
    grupo_otros,
    origen_regla,
    origen_patron,
    origen_ia,
    tokens_entrada,
    tokens_cache,
    tokens_salida,
    errores_procesamiento
  )
  values (
    p_usuario_id,
    date_trunc('month', current_date)::date,
    case when p_estado in ('procesado', 'ignorado') then 1 else 0 end,
    case when p_estado in ('procesado', 'ignorado') and p_grupo = 'tarjetas' then 1 else 0 end,
    case when p_estado in ('procesado', 'ignorado') and p_grupo = 'servicios' then 1 else 0 end,
    case when p_estado in ('procesado', 'ignorado') and p_grupo = 'suscripciones' then 1 else 0 end,
    case when p_estado in ('procesado', 'ignorado') and p_grupo = 'turnos' then 1 else 0 end,
    case when p_estado in ('procesado', 'ignorado') and p_grupo = 'otros' then 1 else 0 end,
    case when p_estado in ('procesado', 'ignorado') and p_origen = 'regla' then 1 else 0 end,
    case
      when p_estado in ('procesado', 'ignorado')
        and p_origen in ('patron_personal', 'patron_global')
      then 1 else 0
    end,
    case
      when p_estado in ('procesado', 'ignorado')
        and p_origen in ('ia', 'migracion')
      then 1 else 0
    end,
    greatest(coalesce(p_tokens_entrada, 0), 0),
    greatest(coalesce(p_tokens_cache, 0), 0),
    greatest(coalesce(p_tokens_salida, 0), 0),
    case when p_estado = 'error' then 1 else 0 end
  )
  on conflict (usuario_id, periodo) do update set
    correos_procesados = public.consumos_mensuales.correos_procesados
      + excluded.correos_procesados,
    grupo_tarjetas = public.consumos_mensuales.grupo_tarjetas + excluded.grupo_tarjetas,
    grupo_servicios = public.consumos_mensuales.grupo_servicios + excluded.grupo_servicios,
    grupo_suscripciones = public.consumos_mensuales.grupo_suscripciones
      + excluded.grupo_suscripciones,
    grupo_turnos = public.consumos_mensuales.grupo_turnos + excluded.grupo_turnos,
    grupo_otros = public.consumos_mensuales.grupo_otros + excluded.grupo_otros,
    origen_regla = public.consumos_mensuales.origen_regla + excluded.origen_regla,
    origen_patron = public.consumos_mensuales.origen_patron + excluded.origen_patron,
    origen_ia = public.consumos_mensuales.origen_ia + excluded.origen_ia,
    tokens_entrada = public.consumos_mensuales.tokens_entrada + excluded.tokens_entrada,
    tokens_cache = public.consumos_mensuales.tokens_cache + excluded.tokens_cache,
    tokens_salida = public.consumos_mensuales.tokens_salida + excluded.tokens_salida,
    errores_procesamiento = public.consumos_mensuales.errores_procesamiento
      + excluded.errores_procesamiento,
    actualizado_en = now();
end
$$;

revoke execute on function public.registrar_consumo_correo(
  uuid, text, text, text, integer, integer, integer
) from public, anon, authenticated;
grant execute on function public.registrar_consumo_correo(
  uuid, text, text, text, integer, integer, integer
) to service_role;

create or replace function public.registrar_evidencia_patron(
  p_usuario_id uuid,
  p_dominio_remitente text,
  p_huella_plantilla text,
  p_selector_fecha integer,
  p_selector_monto integer,
  p_clasificacion jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  patron_personal public.patrones_correo%rowtype;
  total_evidencias integer;
  total_usuarios integer;
  clasificacion_segura jsonb;
begin
  if nullif(btrim(p_dominio_remitente), '') is null
    or p_dominio_remitente !~ '^[a-z0-9.-]{1,253}$'
    or p_huella_plantilla !~ '^[a-f0-9]{64}$'
    or p_selector_fecha not between 0 and 20
    or (p_selector_monto is not null and p_selector_monto not between 0 and 20)
    or coalesce(p_clasificacion->>'categoria', '') not in (
      'factura', 'pago', 'entrega', 'renovacion', 'turno',
      'reunion', 'respuesta', 'documentacion', 'promocion',
      'irrelevante', 'otro'
    )
    or coalesce(p_clasificacion->>'grupo_resumen', '') not in (
      'tarjetas', 'servicios', 'suscripciones', 'turnos', 'otros'
    )
    or coalesce(p_clasificacion->>'tipo', '') not in (
      'vencimiento', 'pago', 'entrega', 'reunion', 'turno',
      'renovacion', 'respuesta', 'documentacion', 'otro'
    ) then
    raise exception 'PATRON_INVALIDO';
  end if;

  clasificacion_segura := jsonb_build_object(
    'categoria', p_clasificacion->>'categoria',
    'grupo_resumen', p_clasificacion->>'grupo_resumen',
    'tipo', p_clasificacion->>'tipo',
    'entidad', nullif(left(coalesce(p_clasificacion->>'entidad', ''), 120), '')
  );

  insert into public.patrones_correo (
    alcance,
    usuario_id,
    dominio_remitente,
    huella_plantilla,
    selector_fecha,
    selector_monto,
    clasificacion,
    estado,
    evidencias,
    coincidencias,
    usuarios_evidencia
  )
  values (
    'personal',
    p_usuario_id,
    p_dominio_remitente,
    p_huella_plantilla,
    p_selector_fecha,
    p_selector_monto,
    clasificacion_segura,
    'aprendizaje',
    1,
    1,
    1
  )
  on conflict (
    usuario_id,
    dominio_remitente,
    huella_plantilla
  ) where alcance = 'personal'
  do update set
    selector_fecha = excluded.selector_fecha,
    selector_monto = excluded.selector_monto,
    clasificacion = excluded.clasificacion,
    evidencias = public.patrones_correo.evidencias + 1,
    coincidencias = case
      when public.patrones_correo.selector_fecha = excluded.selector_fecha
        and public.patrones_correo.selector_monto is not distinct from excluded.selector_monto
        and public.patrones_correo.clasificacion = excluded.clasificacion
      then public.patrones_correo.coincidencias + 1
      else 1
    end,
    estado = case
      when public.patrones_correo.selector_fecha = excluded.selector_fecha
        and public.patrones_correo.selector_monto is not distinct from excluded.selector_monto
        and public.patrones_correo.clasificacion = excluded.clasificacion
        and public.patrones_correo.coincidencias + 1 >= 3
      then 'activo'
      when public.patrones_correo.selector_fecha = excluded.selector_fecha
        and public.patrones_correo.selector_monto is not distinct from excluded.selector_monto
        and public.patrones_correo.clasificacion = excluded.clasificacion
      then 'aprendizaje'
      else 'observacion'
    end,
    actualizado_en = now()
  returning * into patron_personal;

  select
    coalesce(sum(p.coincidencias), 0)::integer,
    count(distinct p.usuario_id)::integer
  into total_evidencias, total_usuarios
  from public.patrones_correo p
  where p.alcance = 'personal'
    and p.estado = 'activo'
    and p.dominio_remitente = patron_personal.dominio_remitente
    and p.huella_plantilla = patron_personal.huella_plantilla
    and p.selector_fecha = patron_personal.selector_fecha
    and p.selector_monto is not distinct from patron_personal.selector_monto
    and p.clasificacion = patron_personal.clasificacion;

  if total_evidencias >= 10 and total_usuarios >= 3 then
    insert into public.patrones_correo (
      alcance,
      usuario_id,
      dominio_remitente,
      huella_plantilla,
      selector_fecha,
      selector_monto,
      clasificacion,
      estado,
      evidencias,
      coincidencias,
      usuarios_evidencia
    )
    values (
      'global',
      null,
      patron_personal.dominio_remitente,
      patron_personal.huella_plantilla,
      patron_personal.selector_fecha,
      patron_personal.selector_monto,
      patron_personal.clasificacion - 'entidad',
      'activo',
      total_evidencias,
      total_evidencias,
      total_usuarios
    )
    on conflict (
      dominio_remitente,
      huella_plantilla
    ) where alcance = 'global'
    do update set
      selector_fecha = excluded.selector_fecha,
      selector_monto = excluded.selector_monto,
      clasificacion = excluded.clasificacion,
      estado = 'activo',
      evidencias = excluded.evidencias,
      coincidencias = excluded.coincidencias,
      usuarios_evidencia = excluded.usuarios_evidencia,
      actualizado_en = now();
  end if;

  return patron_personal.id;
end
$$;

revoke execute on function public.registrar_evidencia_patron(
  uuid, text, text, integer, integer, jsonb
) from public, anon, authenticated;
grant execute on function public.registrar_evidencia_patron(
  uuid, text, text, integer, integer, jsonb
) to service_role;

create or replace function public.registrar_validacion_patron(
  p_patron_id uuid,
  p_coincide boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.patrones_correo
  set
    validaciones_sombra = validaciones_sombra + 1,
    discrepancias = discrepancias + case when p_coincide then 0 else 1 end,
    coincidencias = coincidencias + case when p_coincide then 1 else 0 end,
    estado = case when p_coincide then estado else 'observacion' end,
    ultimo_uso_en = now()
  where id = p_patron_id;
end
$$;

revoke execute on function public.registrar_validacion_patron(uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.registrar_validacion_patron(uuid, boolean)
  to service_role;

-- El callback OAuth usa esta única operación transaccional. El bloqueo sobre
-- la suscripción impide superar el plan con callbacks simultáneos.
create or replace function public.registrar_conexion_google_oauth(
  p_usuario_id uuid,
  p_servicio text,
  p_google_subject_id text,
  p_google_email text,
  p_conexion_id uuid default null,
  p_refresh_token_cifrado text default null,
  p_token_iv text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  limite integer;
  usadas integer;
  conexion public.conexiones_google%rowtype;
  conexion_resultado uuid;
  modo_automatico boolean;
begin
  if p_servicio not in ('gmail', 'calendar') then
    raise exception 'SERVICIO_GOOGLE_INVALIDO';
  end if;
  if nullif(btrim(p_google_subject_id), '') is null
    or nullif(btrim(p_google_email), '') is null then
    raise exception 'IDENTIDAD_GOOGLE_INVALIDA';
  end if;

  select pl.limite_cuentas_gmail
  into limite
  from public.suscripciones s
  join public.planes pl on pl.id = s.plan_id
  join public.perfiles pe on pe.id = s.usuario_id
  where s.usuario_id = p_usuario_id
    and s.estado in ('prueba', 'activa')
    and s.fecha_vencimiento >= now()
    and pl.activo
    and pe.estado_acceso = 'activo'
  for update of s;

  if limite is null then
    raise exception 'CUENTA_O_SUSCRIPCION_INHABILITADA';
  end if;

  if p_servicio = 'gmail' then
    select *
    into conexion
    from public.conexiones_google
    where usuario_id = p_usuario_id
      and google_subject_id = p_google_subject_id
    for update;

    if conexion.id is null then
      select *
      into conexion
      from public.conexiones_google
      where usuario_id = p_usuario_id
        and google_subject_id like 'legacy:%'
        and lower(google_email) = lower(p_google_email)
      order by creado_en
      limit 1
      for update;

      if conexion.id is not null then
        update public.conexiones_google
        set google_subject_id = p_google_subject_id
        where id = conexion.id;
      end if;
    end if;

    select count(*)
    into usadas
    from public.conexiones_google
    where usuario_id = p_usuario_id
      and gmail_conectado
      and estado_conexion = 'activa'
      and (conexion.id is null or id <> conexion.id);

    if (
      conexion.id is null
      or not (
        conexion.gmail_conectado
        and conexion.estado_conexion = 'activa'
      )
    ) and usadas >= limite then
      raise exception 'CUPO_CUENTAS_GMAIL';
    end if;
    if conexion.id is not null
      and (
        coalesce(p_refresh_token_cifrado, conexion.refresh_token_cifrado) is null
        or coalesce(p_token_iv, conexion.token_iv) is null
      ) then
      raise exception 'GOOGLE_REFRESH_TOKEN_REQUERIDO';
    end if;

    if conexion.id is null then
      select coalesce(
        bool_or(c.sincronizacion_automatica),
        true
      )
      into modo_automatico
      from public.conexiones_google c
      where c.usuario_id = p_usuario_id
        and c.gmail_conectado
        and c.estado_conexion = 'activa';
    else
      modo_automatico := conexion.sincronizacion_automatica;
    end if;

    if conexion.id is null then
      if p_refresh_token_cifrado is null or p_token_iv is null then
        raise exception 'GOOGLE_REFRESH_TOKEN_REQUERIDO';
      end if;
      insert into public.conexiones_google (
        usuario_id,
        google_subject_id,
        google_email,
        gmail_conectado,
        calendar_conectado,
        refresh_token_cifrado,
        token_iv,
        estado_conexion,
        sincronizacion_automatica,
        proxima_sincronizacion
      )
      values (
        p_usuario_id,
        p_google_subject_id,
        lower(p_google_email),
        true,
        false,
        p_refresh_token_cifrado,
        p_token_iv,
        'activa',
        modo_automatico,
        case when modo_automatico then now() else null end
      )
      returning id into conexion_resultado;
    else
      update public.conexiones_google
      set
        google_email = lower(p_google_email),
        gmail_conectado = true,
        refresh_token_cifrado = coalesce(
          p_refresh_token_cifrado,
          public.conexiones_google.refresh_token_cifrado
        ),
        token_iv = coalesce(p_token_iv, public.conexiones_google.token_iv),
        estado_conexion = 'activa',
        sincronizacion_automatica = modo_automatico,
        proxima_sincronizacion = case
          when modo_automatico then now()
          else null
        end,
        error_ultima_sincronizacion = null
      where id = conexion.id
      returning id into conexion_resultado;
    end if;
  else
    if p_conexion_id is null then
      raise exception 'CONEXION_GMAIL_REQUERIDA';
    end if;

    select *
    into conexion
    from public.conexiones_google
    where id = p_conexion_id
      and usuario_id = p_usuario_id
    for update;

    if conexion.id is null
      or not conexion.gmail_conectado
      or conexion.estado_conexion <> 'activa' then
      raise exception 'CONEXION_GMAIL_REQUERIDA';
    end if;
    if conexion.google_subject_id <> p_google_subject_id then
      if conexion.google_subject_id like 'legacy:%'
        and lower(conexion.google_email) = lower(p_google_email) then
        update public.conexiones_google
        set google_subject_id = p_google_subject_id
        where id = conexion.id;
      else
        raise exception 'CUENTA_CALENDAR_DISTINTA';
      end if;
    end if;

    update public.conexiones_google
    set
      calendar_conectado = false,
      es_calendar_principal = false,
      calendar_id = null
    where usuario_id = p_usuario_id
      and id <> conexion.id
      and calendar_conectado;

    update public.conexiones_google
    set
      google_email = lower(p_google_email),
      calendar_conectado = true,
      es_calendar_principal = true,
      refresh_token_cifrado = coalesce(
        p_refresh_token_cifrado,
        public.conexiones_google.refresh_token_cifrado
      ),
      token_iv = coalesce(p_token_iv, public.conexiones_google.token_iv),
      estado_conexion = 'activa'
    where id = conexion.id
    returning id into conexion_resultado;

    update public.eventos_calendar
    set
      conexion_google_id = conexion_resultado,
      estado_google = 'pendiente',
      error_google = null
    where usuario_id = p_usuario_id
      and google_event_id is null
      and estado_sincronizacion <> 'eliminado';
  end if;

  return conexion_resultado;
end
$$;

revoke execute on function public.registrar_conexion_google_oauth(
  uuid, text, text, text, uuid, text, text
) from public, anon, authenticated;
grant execute on function public.registrar_conexion_google_oauth(
  uuid, text, text, text, uuid, text, text
) to service_role;

create or replace function public.estado_capacidad_agenkin()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'bytes_base', pg_database_size(current_database()),
    'megabytes_base', round(pg_database_size(current_database()) / 1024.0 / 1024.0, 2),
    'alerta_almacenamiento', pg_database_size(current_database()) >= 350 * 1024 * 1024,
    'detener_carga_historica', pg_database_size(current_database()) >= 425 * 1024 * 1024
  );
$$;

revoke execute on function public.estado_capacidad_agenkin()
  from public, anon, authenticated;
grant execute on function public.estado_capacidad_agenkin() to service_role;

-- ---------------------------------------------------------------------------
-- Consultas del portal y automatización multicuenta.
-- ---------------------------------------------------------------------------

create or replace function private.obtener_estado_conexion_google()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with suscripcion as (
    select pl.limite_cuentas_gmail
    from public.suscripciones s
    join public.planes pl on pl.id = s.plan_id
    where s.usuario_id = (select auth.uid())
    limit 1
  ),
  cuentas as (
    select
      c.id,
      c.google_email,
      c.estado_conexion,
      c.gmail_conectado,
      c.calendar_conectado,
      c.es_calendar_principal,
      c.gmail_ultima_lectura_en,
      c.calendar_ultima_sincronizacion_en,
      c.agenda_ultima_actualizacion_en,
      c.ultima_sincronizacion_exitosa,
      c.sincronizacion_automatica,
      c.creacion_automatica_eventos,
      c.umbral_confianza_automatica,
      c.error_ultima_sincronizacion,
      c.creado_en
    from public.conexiones_google c
    where c.usuario_id = (select auth.uid())
  ),
  resumen as (
    select
      count(*) filter (
        where gmail_conectado and estado_conexion = 'activa'
      )::integer as usadas,
      coalesce(bool_or(
        sincronizacion_automatica
        and gmail_conectado
        and estado_conexion = 'activa'
      ), false) as automatica,
      coalesce(bool_or(
        creacion_automatica_eventos
        and gmail_conectado
        and estado_conexion = 'activa'
      ), false) as eventos_automaticos,
      coalesce(max(umbral_confianza_automatica), 0.900) as umbral,
      max(gmail_ultima_lectura_en) as ultima_lectura,
      max(agenda_ultima_actualizacion_en) as ultima_agenda,
      max(ultima_sincronizacion_exitosa) as ultima_exitosa
    from cuentas
  ),
  calendar as (
    select *
    from cuentas
    where es_calendar_principal
      and calendar_conectado
      and estado_conexion = 'activa'
    limit 1
  )
  select jsonb_build_object(
    'gmail', jsonb_build_object(
      'usadas', coalesce((select usadas from resumen), 0),
      'limite', coalesce((select limite_cuentas_gmail from suscripcion), 1),
      'cuentas', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'id', c.id,
            'email', c.google_email,
            'conectado', c.gmail_conectado and c.estado_conexion = 'activa',
            'estado', c.estado_conexion,
            'ultima_lectura_en', c.gmail_ultima_lectura_en,
            'ultima_sincronizacion_exitosa', c.ultima_sincronizacion_exitosa,
            'calendar_activo', c.es_calendar_principal and c.calendar_conectado,
            'sincronizacion_automatica', c.sincronizacion_automatica,
            'error_ultima_sincronizacion', c.error_ultima_sincronizacion,
            'tareas_pendientes', (
              select count(*)
              from public.tareas_correos_gmail t
              where t.conexion_google_id = c.id
                and t.estado in ('pendiente', 'procesando')
            ),
            'tareas_error', (
              select count(*)
              from public.tareas_correos_gmail t
              where t.conexion_google_id = c.id and t.estado = 'error'
            )
          )
          order by c.creado_en
        )
        from cuentas c
        where c.gmail_conectado and c.estado_conexion = 'activa'
      ), '[]'::jsonb)
    ),
    'calendar', jsonb_build_object(
      'conexion_id', (select id from calendar),
      'email', (select google_email from calendar),
      'conectado', exists (select 1 from calendar),
      'ultima_sincronizacion_en', (
        select calendar_ultima_sincronizacion_en from calendar
      )
    ),
    'sincronizacion_automatica', coalesce((select automatica from resumen), false),
    'creacion_automatica_eventos', coalesce(
      (select eventos_automaticos from resumen),
      false
    ),
    'umbral_confianza_automatica', coalesce((select umbral from resumen), 0.900),
    'gmail_ultima_lectura_en', (select ultima_lectura from resumen),
    'agenda_ultima_actualizacion_en', (select ultima_agenda from resumen),
    'ultima_sincronizacion_exitosa', (select ultima_exitosa from resumen),
    'tareas_pendientes', (
      select count(*)
      from public.tareas_correos_gmail t
      where t.usuario_id = (select auth.uid())
        and t.estado in ('pendiente', 'procesando')
    ),
    'tareas_error', (
      select count(*)
      from public.tareas_correos_gmail t
      where t.usuario_id = (select auth.uid()) and t.estado = 'error'
    )
  );
$$;

revoke execute on function private.obtener_estado_conexion_google()
  from public, anon;
grant execute on function private.obtener_estado_conexion_google()
  to authenticated;

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
    'correos_analizados_total', coalesce((
      select sum(cm_total.correos_procesados)
      from public.consumos_mensuales cm_total
      where cm_total.usuario_id = p.id
    ), 0),
    'correos_analizados_hoy', (
      select count(*)
      from public.correos_procesados cp_hoy
      where cp_hoy.usuario_id = p.id
        and cp_hoy.estado_procesamiento in ('procesado', 'ignorado')
        and cp_hoy.fecha_procesamiento >= (
          (now() at time zone 'America/Argentina/Cordoba')::date
            at time zone 'America/Argentina/Cordoba'
        )
        and cp_hoy.fecha_procesamiento < (
          ((now() at time zone 'America/Argentina/Cordoba')::date + 1)
            at time zone 'America/Argentina/Cordoba'
        )
    ),
    'categorias_resumen', jsonb_build_object(
      'tarjetas', coalesce((
        select sum(cm_grupo.grupo_tarjetas)
        from public.consumos_mensuales cm_grupo
        where cm_grupo.usuario_id = p.id
      ), 0),
      'servicios', coalesce((
        select sum(cm_grupo.grupo_servicios)
        from public.consumos_mensuales cm_grupo
        where cm_grupo.usuario_id = p.id
      ), 0),
      'suscripciones', coalesce((
        select sum(cm_grupo.grupo_suscripciones)
        from public.consumos_mensuales cm_grupo
        where cm_grupo.usuario_id = p.id
      ), 0),
      'turnos', coalesce((
        select sum(cm_grupo.grupo_turnos)
        from public.consumos_mensuales cm_grupo
        where cm_grupo.usuario_id = p.id
      ), 0),
      'otros', coalesce((
        select sum(cm_grupo.grupo_otros)
        from public.consumos_mensuales cm_grupo
        where cm_grupo.usuario_id = p.id
      ), 0)
    ),
    'avisos_del_dia', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', v.id,
          'grupo_resumen', coalesce(cp_aviso.grupo_resumen, 'otros'),
          'entidad', v.entidad,
          'monto', v.monto,
          'titulo', v.titulo,
          'estado', v.estado
        )
        order by v.hora_vencimiento nulls last, v.creado_en
      )
      from public.vencimientos_detectados v
      left join public.correos_procesados cp_aviso
        on cp_aviso.id = v.correo_id
        and cp_aviso.usuario_id = v.usuario_id
      where v.usuario_id = p.id
        and v.fecha_vencimiento = (
          now() at time zone 'America/Argentina/Cordoba'
        )::date
        and v.estado <> 'descartado'
    ), '[]'::jsonb),
    'eventos_creados', coalesce((
      select sum(cm_eventos.eventos_creados)
      from public.consumos_mensuales cm_eventos
      where cm_eventos.usuario_id = p.id
    ), 0),
    'vencimientos_detectados', (
      select count(*)
      from public.vencimientos_detectados v
      where v.usuario_id = p.id
    ),
    'pendientes_revision', (
      select count(*)
      from public.vencimientos_detectados v
      where v.usuario_id = p.id and v.estado = 'pendiente'
    ),
    'suscripcion', jsonb_build_object(
      'plan', pl.nombre,
      'estado', s.estado,
      'fecha_inicio', s.fecha_inicio,
      'fecha_vencimiento', s.fecha_vencimiento,
      'limite_cuentas_gmail', pl.limite_cuentas_gmail,
      'cuentas_gmail_usadas', (
        select count(*)
        from public.conexiones_google c
        where c.usuario_id = p.id
          and c.gmail_conectado
          and c.estado_conexion = 'activa'
      ),
      'permite_automatizacion', pl.permite_automatizacion,
      'es_interno', pl.es_interno,
      'solicitud_mejora_pendiente', case
        when pl.es_interno then false
        else exists (
          select 1
          from public.solicitudes_mejora_plan smp
          where smp.usuario_id = p.id and smp.estado = 'pendiente'
        )
      end
    )
  )
  from public.perfiles p
  join public.suscripciones s on s.usuario_id = p.id
  join public.planes pl on pl.id = s.plan_id
  where p.id = (select auth.uid());
$$;

revoke execute on function private.obtener_panel_usuario() from public, anon;
grant execute on function private.obtener_panel_usuario() to authenticated;

create or replace function private.configurar_automatizacion_google(
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
  solicita_automatizacion boolean :=
    p_sincronizacion_automatica or p_creacion_automatica_eventos;
  actualizadas integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Sesión requerida';
  end if;
  if p_umbral_confianza < 0.500 or p_umbral_confianza > 1.000 then
    raise exception 'Umbral de confianza inválido';
  end if;
  if solicita_automatizacion and not (select private.usuario_habilitado()) then
    raise exception 'Cuenta o suscripción no habilitada';
  end if;

  update public.conexiones_google
  set
    sincronizacion_automatica = solicita_automatizacion,
    creacion_automatica_eventos = p_creacion_automatica_eventos,
    umbral_confianza_automatica = p_umbral_confianza,
    proxima_sincronizacion = case when solicita_automatizacion then now() else null end,
    error_ultima_sincronizacion = null
  where usuario_id = (select auth.uid())
    and estado_conexion = 'activa'
    and gmail_conectado;

  get diagnostics actualizadas = row_count;
  if actualizadas = 0 then
    raise exception 'Conectá Gmail antes de configurar la automatización';
  end if;

  return jsonb_build_object(
    'sincronizacion_automatica', solicita_automatizacion,
    'creacion_automatica_eventos', p_creacion_automatica_eventos,
    'umbral_confianza_automatica', p_umbral_confianza,
    'cuentas_actualizadas', actualizadas
  );
end
$$;

revoke execute on function private.configurar_automatizacion_google(
  boolean, boolean, numeric
) from public, anon;
grant execute on function private.configurar_automatizacion_google(
  boolean, boolean, numeric
) to authenticated;

-- Todas las cuentas heredadas quedan en automático, pero el usuario puede
-- cambiar a modo manual desde el portal.
update public.conexiones_google c
set
  sincronizacion_automatica = true,
  proxima_sincronizacion = coalesce(c.proxima_sincronizacion, now())
where c.gmail_conectado
  and c.estado_conexion = 'activa'
  and exists (
    select 1
    from public.perfiles pe
    join public.suscripciones s on s.usuario_id = pe.id
    join public.planes pl on pl.id = s.plan_id
    where pe.id = c.usuario_id
      and pe.estado_acceso = 'activo'
      and s.estado in ('prueba', 'activa')
      and s.fecha_vencimiento >= now()
      and pl.activo
  );

-- ---------------------------------------------------------------------------
-- Cola Gmail durable y justa. Se usa la tabla existente como única fuente de
-- verdad para evitar duplicar cada tarea en PGMQ.
-- ---------------------------------------------------------------------------

update public.tareas_correos_gmail
set
  estado = 'pendiente',
  reclamada_en = null,
  disponible_en = now()
where estado = 'procesando'
  and reclamada_en is null;

create or replace function public.registrar_tareas_correos_gmail(
  p_usuario_id uuid,
  p_conexion_google_id uuid,
  p_gmail_message_ids text[]
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  total integer;
  abiertas integer;
begin
  if not exists (
    select 1
    from public.conexiones_google c
    where c.id = p_conexion_google_id
      and c.usuario_id = p_usuario_id
      and c.gmail_conectado
      and c.estado_conexion = 'activa'
  ) then
    raise exception 'CONEXION_GMAIL_INVALIDA';
  end if;

  if coalesce(cardinality(p_gmail_message_ids), 0) > 50 then
    raise exception 'LOTE_GMAIL_DEMASIADO_GRANDE';
  end if;

  -- ponytail: un bloqueo global breve basta para la beta; separar por shard
  -- solamente si la contención de inserción llega a ser medible.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('agenkin_cola_gmail')
  );
  select count(*)
  into abiertas
  from public.tareas_correos_gmail
  where estado in ('pendiente', 'procesando');

  if abiertas + coalesce(cardinality(p_gmail_message_ids), 0) > 500 then
    raise exception 'COLA_GMAIL_SATURADA';
  end if;

  with insertadas as (
    insert into public.tareas_correos_gmail (
      usuario_id,
      conexion_google_id,
      gmail_message_id,
      estado,
      disponible_en
    )
    select
      p_usuario_id,
      p_conexion_google_id,
      identificador,
      'pendiente',
      now()
    from (
      select distinct btrim(valor) as identificador
      from unnest(coalesce(p_gmail_message_ids, array[]::text[])) as valor
    ) ids
    where identificador ~ '^[A-Za-z0-9_-]{1,128}$'
    on conflict (conexion_google_id, gmail_message_id) do update set
      estado = 'pendiente',
      intentos = 0,
      ultimo_error = null,
      disponible_en = now(),
      reclamada_en = null
    where public.tareas_correos_gmail.estado = 'error'
    returning 1
  )
  select count(*) into total from insertadas;

  return coalesce(total, 0);
end
$$;

revoke execute on function public.registrar_tareas_correos_gmail(
  uuid, uuid, text[]
) from public, anon, authenticated;
grant execute on function public.registrar_tareas_correos_gmail(
  uuid, uuid, text[]
) to service_role;

drop function if exists public.registrar_tareas_correos_gmail(uuid, text[]);

create or replace function public.reclamar_sincronizaciones_manuales(
  p_usuario_id uuid,
  p_conexion_ids uuid[] default null
)
returns table (
  conexion_google_id uuid,
  usuario_id uuid,
  google_email text,
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
  with elegidas as (
    select c.id
    from public.conexiones_google c
    where c.usuario_id = p_usuario_id
      and c.gmail_conectado
      and c.estado_conexion = 'activa'
      and c.refresh_token_cifrado is not null
      and c.token_iv is not null
      and (
        coalesce(cardinality(p_conexion_ids), 0) = 0
        or c.id = any(p_conexion_ids)
      )
      and (
        c.ultima_solicitud_manual_en is null
        or c.ultima_solicitud_manual_en <= now() - interval '60 seconds'
      )
    order by c.creado_en
    limit 5
    for update of c skip locked
  ),
  actualizadas as (
    update public.conexiones_google c
    set ultima_solicitud_manual_en = now()
    from elegidas e
    where c.id = e.id
    returning c.*
  )
  select
    a.id,
    a.usuario_id,
    a.google_email,
    a.refresh_token_cifrado,
    a.token_iv,
    a.gmail_history_id,
    a.gmail_history_objetivo,
    a.gmail_page_token,
    a.sincronizacion_inicial_completa
  from actualizadas a
  order by a.creado_en;
$$;

revoke execute on function public.reclamar_sincronizaciones_manuales(
  uuid, uuid[]
) from public, anon, authenticated;
grant execute on function public.reclamar_sincronizaciones_manuales(
  uuid, uuid[]
) to service_role;

drop function if exists public.leer_tareas_correos_gmail(integer);

create function public.leer_tareas_correos_gmail(p_cantidad integer default 20)
returns table (
  tarea_id uuid,
  intentos integer,
  usuario_id uuid,
  conexion_google_id uuid,
  gmail_message_id text
)
language sql
security definer
set search_path = ''
as $$
  with ordenadas as (
    select
      t.id,
      row_number() over (
        partition by t.conexion_google_id
        order by t.disponible_en, t.creado_en
      ) as ronda
    from public.tareas_correos_gmail t
    where (
      t.estado = 'pendiente'
      and t.disponible_en <= now()
    ) or (
      t.estado = 'procesando'
      and (
        t.reclamada_en is null
        or t.reclamada_en < now() - interval '10 minutes'
      )
    )
  ),
  elegidas as (
    select t.id
    from public.tareas_correos_gmail t
    join ordenadas o on o.id = t.id
    order by o.ronda, t.disponible_en, t.creado_en
    limit least(greatest(p_cantidad, 1), 20)
    for update of t skip locked
  ),
  reclamadas as (
    update public.tareas_correos_gmail t
    set
      estado = 'procesando',
      reclamada_en = now()
    from elegidas e
    where t.id = e.id
    returning t.id, t.intentos, t.usuario_id, t.conexion_google_id, t.gmail_message_id
  )
  select
    r.id,
    r.intentos,
    r.usuario_id,
    r.conexion_google_id,
    r.gmail_message_id
  from reclamadas r;
$$;

revoke execute on function public.leer_tareas_correos_gmail(integer)
  from public, anon, authenticated;
grant execute on function public.leer_tareas_correos_gmail(integer)
  to service_role;

drop function if exists public.finalizar_tarea_correo_gmail(
  bigint, uuid, text, boolean, integer, boolean
);

create function public.finalizar_tarea_correo_gmail(
  p_tarea_id uuid,
  p_error text default null,
  p_reintentar boolean default false,
  p_retraso_segundos integer default 0
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tarea public.tareas_correos_gmail%rowtype;
  v_correo public.correos_procesados%rowtype;
begin
  select *
  into v_tarea
  from public.tareas_correos_gmail t
  where t.id = p_tarea_id
    and t.estado = 'procesando'
  for update;
  if v_tarea.id is null then
    return;
  end if;

  if not p_reintentar and p_error is not null then
    select *
    into v_correo
    from public.correos_procesados cp
    where cp.usuario_id = v_tarea.usuario_id
      and cp.conexion_google_id = v_tarea.conexion_google_id
      and cp.gmail_message_id = v_tarea.gmail_message_id
    for update;

    if v_correo.id is not null
      and v_correo.metricas_registradas_en is null then
      perform public.registrar_consumo_correo(
        v_tarea.usuario_id,
        'otros',
        'ia',
        'error',
        coalesce(v_correo.tokens_entrada, 0),
        coalesce(v_correo.tokens_cache, 0),
        coalesce(v_correo.tokens_salida, 0)
      );
      update public.correos_procesados
      set metricas_registradas_en = now()
      where id = v_correo.id;
    end if;
  end if;

  update public.tareas_correos_gmail
  set
    estado = case
      when p_reintentar then 'pendiente'
      when p_error is null then 'completada'
      else 'error'
    end,
    intentos = intentos + 1,
    ultimo_error = left(p_error, 100),
    disponible_en = case
      when p_reintentar
        then now() + make_interval(
          secs => least(greatest(coalesce(p_retraso_segundos, 0), 0), 604800)
        )
      else disponible_en
    end,
    reclamada_en = null
  where id = v_tarea.id;
end
$$;

revoke execute on function public.finalizar_tarea_correo_gmail(
  uuid, text, boolean, integer
) from public, anon, authenticated;
grant execute on function public.finalizar_tarea_correo_gmail(
  uuid, text, boolean, integer
) to service_role;

create or replace function public.finalizar_correo_analizado(
  p_tarea_id uuid,
  p_correo_id uuid,
  p_usuario_id uuid,
  p_conexion_google_id uuid,
  p_resultado jsonb
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conexion_id uuid;
  v_tarea public.tareas_correos_gmail%rowtype;
  v_correo public.correos_procesados%rowtype;
  v_estado text := p_resultado->>'estado';
  v_grupo text := p_resultado->>'grupo_resumen';
  v_origen text := p_resultado->>'origen_analisis';
  v_categoria text := p_resultado->>'categoria';
  v_vencimiento jsonb := p_resultado->'vencimiento';
begin
  if jsonb_typeof(p_resultado) <> 'object'
    or v_estado not in ('procesado', 'ignorado')
    or v_grupo not in ('tarjetas', 'servicios', 'suscripciones', 'turnos', 'otros')
    or v_origen not in ('regla', 'patron_personal', 'patron_global', 'ia', 'migracion')
    or v_categoria not in (
      'factura', 'pago', 'entrega', 'renovacion', 'turno',
      'reunion', 'respuesta', 'documentacion', 'promocion',
      'irrelevante', 'otro'
    )
    or coalesce(jsonb_typeof(v_vencimiento), 'null') not in ('object', 'null')
    or (
      jsonb_typeof(v_vencimiento) = 'object'
      and (
        v_estado <> 'procesado'
        or coalesce(v_vencimiento->>'tipo', '') not in (
          'vencimiento', 'pago', 'entrega', 'reunion', 'turno',
          'renovacion', 'respuesta', 'documentacion', 'otro'
        )
        or coalesce(v_vencimiento->>'fecha', '') !~ '^\d{4}-\d{2}-\d{2}$'
        or coalesce(v_vencimiento->>'confianza', '') !~ '^(0(\.\d+)?|1(\.0+)?)$'
      )
    ) then
    raise exception 'RESULTADO_CORREO_INVALIDO';
  end if;

  -- Mismo orden de bloqueo que la desconexión: conexión y luego tarea.
  select c.id
  into v_conexion_id
  from public.conexiones_google c
  where c.id = p_conexion_google_id
    and c.usuario_id = p_usuario_id
    and c.gmail_conectado
    and c.estado_conexion = 'activa'
  for share;
  if v_conexion_id is null then
    return false;
  end if;

  select *
  into v_tarea
  from public.tareas_correos_gmail t
  where t.id = p_tarea_id
  for update;
  if v_tarea.id is null
    or v_tarea.estado <> 'procesando'
    or v_tarea.usuario_id <> p_usuario_id
    or v_tarea.conexion_google_id <> p_conexion_google_id then
    return false;
  end if;

  select *
  into v_correo
  from public.correos_procesados cp
  where cp.id = p_correo_id
    and cp.usuario_id = p_usuario_id
    and cp.conexion_google_id = p_conexion_google_id
    and cp.gmail_message_id = v_tarea.gmail_message_id
  for update;
  if v_correo.id is null
    or v_correo.estado_procesamiento <> 'error'
    or v_correo.error_procesamiento <> 'PROCESAMIENTO_EN_CURSO' then
    return false;
  end if;

  update public.correos_procesados cp
  set
    gmail_thread_id = nullif(left(p_resultado->>'gmail_thread_id', 255), ''),
    remitente = left(coalesce(p_resultado->>'remitente', ''), 500),
    asunto = left(coalesce(p_resultado->>'asunto', ''), 500),
    fecha_correo = nullif(p_resultado->>'fecha_correo', '')::timestamptz,
    categoria = v_categoria,
    grupo_resumen = v_grupo,
    grupo_asignado_por = case
      when p_resultado->>'grupo_asignado_por' in ('ia', 'migracion', 'usuario')
      then p_resultado->>'grupo_asignado_por'
      else 'ia'
    end,
    relevante = coalesce((p_resultado->>'relevante')::boolean, false),
    estado_procesamiento = v_estado::public.estado_procesamiento,
    error_procesamiento = null,
    fecha_procesamiento = now(),
    origen_analisis = v_origen,
    patron_id = nullif(p_resultado->>'patron_id', '')::uuid,
    huella_plantilla = nullif(left(p_resultado->>'huella_plantilla', 128), ''),
    tokens_entrada = nullif(p_resultado->>'tokens_entrada', '')::integer,
    tokens_cache = nullif(p_resultado->>'tokens_cache', '')::integer,
    tokens_salida = nullif(p_resultado->>'tokens_salida', '')::integer,
    duracion_ia_ms = nullif(p_resultado->>'duracion_ia_ms', '')::integer,
    detalle_compactado = false
  where cp.id = p_correo_id;

  if jsonb_typeof(v_vencimiento) = 'object' then
    insert into public.vencimientos_detectados (
      usuario_id,
      correo_id,
      tipo,
      titulo,
      descripcion,
      entidad,
      monto,
      fecha_vencimiento,
      hora_vencimiento,
      zona_horaria,
      confianza,
      explicacion,
      requiere_revision
    )
    values (
      p_usuario_id,
      p_correo_id,
      left(coalesce(v_vencimiento->>'tipo', 'otro'), 50),
      left(coalesce(v_vencimiento->>'titulo', 'Fecha detectada'), 160),
      left(coalesce(v_vencimiento->>'descripcion', ''), 1000),
      nullif(left(v_vencimiento->>'entidad', 120), ''),
      nullif(v_vencimiento->>'monto', '')::numeric,
      (v_vencimiento->>'fecha')::date,
      nullif(v_vencimiento->>'hora', '')::time,
      coalesce(
        nullif(v_vencimiento->>'zona_horaria', ''),
        'America/Argentina/Cordoba'
      ),
      (v_vencimiento->>'confianza')::numeric,
      left(coalesce(v_vencimiento->>'explicacion', ''), 500),
      coalesce((v_vencimiento->>'requiere_revision')::boolean, true)
    )
    on conflict (correo_id) do update set
      tipo = excluded.tipo,
      titulo = excluded.titulo,
      descripcion = excluded.descripcion,
      entidad = excluded.entidad,
      monto = excluded.monto,
      fecha_vencimiento = excluded.fecha_vencimiento,
      hora_vencimiento = excluded.hora_vencimiento,
      zona_horaria = excluded.zona_horaria,
      confianza = excluded.confianza,
      explicacion = excluded.explicacion,
      requiere_revision = excluded.requiere_revision;
  else
    delete from public.vencimientos_detectados
    where correo_id = p_correo_id
      and usuario_id = p_usuario_id;
  end if;

  if v_correo.metricas_registradas_en is null then
    perform public.registrar_consumo_correo(
      p_usuario_id,
      v_grupo,
      v_origen,
      v_estado,
      coalesce((p_resultado->>'tokens_entrada')::integer, 0),
      coalesce((p_resultado->>'tokens_cache')::integer, 0),
      coalesce((p_resultado->>'tokens_salida')::integer, 0)
    );
    update public.correos_procesados
    set metricas_registradas_en = now()
    where id = p_correo_id;
  end if;

  update public.tareas_correos_gmail
  set
    estado = 'completada',
    intentos = intentos + 1,
    ultimo_error = null,
    reclamada_en = null
  where id = p_tarea_id;

  return true;
end
$$;

revoke execute on function public.finalizar_correo_analizado(
  uuid, uuid, uuid, uuid, jsonb
) from public, anon, authenticated;
grant execute on function public.finalizar_correo_analizado(
  uuid, uuid, uuid, uuid, jsonb
) to service_role;

create or replace function public.liberar_tareas_correos_gmail(
  p_tarea_ids uuid[]
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  total integer;
begin
  update public.tareas_correos_gmail
  set
    estado = 'pendiente',
    reclamada_en = null,
    disponible_en = now()
  where id = any(coalesce(p_tarea_ids, array[]::uuid[]))
    and estado = 'procesando';
  get diagnostics total = row_count;
  return total;
end
$$;

revoke execute on function public.liberar_tareas_correos_gmail(uuid[])
  from public, anon, authenticated;
grant execute on function public.liberar_tareas_correos_gmail(uuid[])
  to service_role;

drop function if exists public.reclamar_sincronizaciones_google(integer);

create function public.reclamar_sincronizaciones_google(p_limite integer default 40)
returns table (
  conexion_google_id uuid,
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
    join public.perfiles pe on pe.id = c.usuario_id
    join public.suscripciones s on s.usuario_id = c.usuario_id
    join public.planes pl on pl.id = s.plan_id
    where c.sincronizacion_automatica
      and c.estado_conexion = 'activa'
      and c.gmail_conectado
      and c.refresh_token_cifrado is not null
      and c.token_iv is not null
      and (c.proxima_sincronizacion is null or c.proxima_sincronizacion <= now())
      and pe.estado_acceso = 'activo'
      and s.estado in ('prueba', 'activa')
      and s.fecha_vencimiento >= now()
      and pl.activo
    order by c.proxima_sincronizacion nulls first, c.actualizado_en
    limit least(greatest(p_limite, 1), 40)
    for update of c skip locked
  ),
  actualizadas as (
    update public.conexiones_google c
    set proxima_sincronizacion = now() + interval '5 minutes'
    from candidatas
    where c.id = candidatas.id
    returning c.*
  )
  select
    a.id,
    a.usuario_id,
    a.refresh_token_cifrado,
    a.token_iv,
    a.gmail_history_id,
    a.gmail_history_objetivo,
    a.gmail_page_token,
    a.sincronizacion_inicial_completa
  from actualizadas a;
$$;

revoke execute on function public.reclamar_sincronizaciones_google(integer)
  from public, anon, authenticated;
grant execute on function public.reclamar_sincronizaciones_google(integer)
  to service_role;

-- La creación interna es independiente de Google. Solo se encola la réplica
-- cuando existe una cuenta Calendar principal.
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
    on conflict (vencimiento_id) do nothing
    returning id into v_evento_id;
    v_evento_creado := v_evento_id is not null;

    if v_evento_id is null then
      select e.id
      into v_evento_id
      from public.eventos_calendar e
      where e.vencimiento_id = p_vencimiento_id
        and e.usuario_id = p_usuario_id;
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
    where id = v_evento_id;
  end if;

  update public.conexiones_google
  set agenda_ultima_actualizacion_en = now()
  where usuario_id = p_usuario_id
    and gmail_conectado
    and estado_conexion = 'activa';

  if conexion_calendar_id is not null then
    insert into public.tareas_calendar (evento_id, usuario_id, estado)
    values (v_evento_id, p_usuario_id, 'pendiente')
    on conflict (evento_id) do update
      set estado = case
        when public.tareas_calendar.estado = 'completada'
          and exists (
            select 1
            from public.eventos_calendar e
            where e.id = v_evento_id and e.google_event_id is not null
          )
        then public.tareas_calendar.estado
        else 'pendiente'
      end
    returning id into v_tarea_id;

    if exists (
      select 1
      from public.tareas_calendar tc
      where tc.id = v_tarea_id and tc.estado = 'pendiente'
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
    insert into public.tareas_calendar (evento_id, usuario_id, estado)
    values (evento.id, p_usuario_id, 'pendiente')
    on conflict (evento_id) do update
      set estado = 'pendiente', ultimo_error = null
    returning id into tarea_id;

    if not exists (
      select 1
      from pgmq.q_calendar_sync q
      where (q.message->>'tarea_id')::uuid = tarea_id
    ) then
      perform pgmq.send(
        'calendar_sync',
        jsonb_build_object(
          'tarea_id', tarea_id,
          'evento_id', evento.id,
          'usuario_id', p_usuario_id
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

drop function if exists public.obtener_eventos_automaticos_pendientes(integer);

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
      and exists (
        select 1
        from public.reglas_usuario r
        where r.usuario_id = v.usuario_id
          and r.activo
          and r.accion = 'priorizar'
          and (
            (
              r.operador = 'igual'
              and lower(
                case r.campo
                  when 'remitente' then coalesce(cp.remitente, '')
                  else coalesce(cp.asunto, '')
                end
              ) = lower(r.valor)
            )
            or (
              r.operador = 'contiene'
              and strpos(
                lower(
                  case r.campo
                    when 'remitente' then coalesce(cp.remitente, '')
                    else coalesce(cp.asunto, '')
                  end
                ),
                lower(r.valor)
              ) > 0
            )
          )
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

create or replace function public.actualizar_grupo_correo(
  correo_id uuid,
  grupo text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  correo public.correos_procesados%rowtype;
begin
  if (select auth.uid()) is null then
    raise exception 'Sesión requerida';
  end if;
  if not (select private.usuario_habilitado()) then
    raise exception 'Cuenta o suscripcion no habilitada';
  end if;
  if grupo not in ('tarjetas', 'servicios', 'suscripciones', 'turnos', 'otros') then
    raise exception 'Categoría inválida';
  end if;

  select *
  into correo
  from public.correos_procesados
  where id = correo_id
    and usuario_id = (select auth.uid())
    and not detalle_compactado
  for update;

  if correo.id is null then
    raise exception 'Correo no encontrado o detalle ya compactado';
  end if;
  if correo.grupo_resumen = grupo then
    return;
  end if;

  update public.correos_procesados
  set grupo_resumen = grupo, grupo_asignado_por = 'usuario'
  where id = correo.id;

  if correo.estado_procesamiento in ('procesado', 'ignorado') then
    update public.consumos_mensuales
    set
      grupo_tarjetas = greatest(
        0,
        grupo_tarjetas
          - case when correo.grupo_resumen = 'tarjetas' then 1 else 0 end
          + case when grupo = 'tarjetas' then 1 else 0 end
      ),
      grupo_servicios = greatest(
        0,
        grupo_servicios
          - case when correo.grupo_resumen = 'servicios' then 1 else 0 end
          + case when grupo = 'servicios' then 1 else 0 end
      ),
      grupo_suscripciones = greatest(
        0,
        grupo_suscripciones
          - case when correo.grupo_resumen = 'suscripciones' then 1 else 0 end
          + case when grupo = 'suscripciones' then 1 else 0 end
      ),
      grupo_turnos = greatest(
        0,
        grupo_turnos
          - case when correo.grupo_resumen = 'turnos' then 1 else 0 end
          + case when grupo = 'turnos' then 1 else 0 end
      ),
      grupo_otros = greatest(
        0,
        grupo_otros
          - case when correo.grupo_resumen = 'otros' then 1 else 0 end
          + case when grupo = 'otros' then 1 else 0 end
      ),
      actualizado_en = now()
    where usuario_id = correo.usuario_id
      and periodo = date_trunc('month', correo.fecha_procesamiento)::date;
  end if;

  if correo.patron_id is not null then
    update public.patrones_correo
    set
      estado = 'observacion',
      discrepancias = discrepancias + 1
    where id = correo.patron_id;
  end if;
end
$$;

revoke execute on function public.actualizar_grupo_correo(uuid, text)
  from public, anon;
grant execute on function public.actualizar_grupo_correo(uuid, text)
  to authenticated;

drop policy if exists "vencimientos propios editables"
  on public.vencimientos_detectados;

create or replace function public.descartar_vencimiento(
  p_vencimiento_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_estado public.estado_vencimiento;
begin
  if (select auth.uid()) is null then
    raise exception 'Sesion requerida';
  end if;
  if not (select private.usuario_habilitado()) then
    raise exception 'Cuenta o suscripcion no habilitada';
  end if;

  select v.estado
  into v_estado
  from public.vencimientos_detectados v
  where v.id = p_vencimiento_id
    and v.usuario_id = (select auth.uid())
  for update;

  if v_estado is null then
    raise exception 'Vencimiento no encontrado';
  end if;
  if v_estado = 'descartado' then
    return true;
  end if;
  if v_estado <> 'pendiente' then
    raise exception 'El vencimiento ya no puede descartarse';
  end if;

  update public.vencimientos_detectados
  set estado = 'descartado'
  where id = p_vencimiento_id
    and usuario_id = (select auth.uid());
  return true;
end
$$;

revoke execute on function public.descartar_vencimiento(uuid)
  from public, anon;
grant execute on function public.descartar_vencimiento(uuid)
  to authenticated;

create or replace function private.observar_patron_al_descartar()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.estado = 'descartado' and old.estado is distinct from new.estado then
    update public.patrones_correo patron
    set
      estado = 'observacion',
      discrepancias = discrepancias + 1
    from public.correos_procesados correo
    where correo.id = new.correo_id
      and correo.patron_id = patron.id;
  end if;
  return new;
end
$$;

revoke execute on function private.observar_patron_al_descartar()
  from public, anon, authenticated;

drop trigger if exists vencimientos_observar_patron on public.vencimientos_detectados;
create trigger vencimientos_observar_patron
after update of estado on public.vencimientos_detectados
for each row execute function private.observar_patron_al_descartar();

-- ---------------------------------------------------------------------------
-- Retención en lotes acotados. Compactar no altera métricas históricas.
-- ---------------------------------------------------------------------------

create or replace function private.ejecutar_mantenimiento_agenkin()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  compactados integer := 0;
  vencimientos_eliminados integer := 0;
  tombstones_eliminados integer := 0;
  tareas_eliminadas integer := 0;
  tareas_calendar_eliminadas integer := 0;
  patrones_eliminados integer := 0;
  filas integer := 0;
begin
  for lote in 1..5 loop
  with candidatas as (
    select cp.id
    from public.correos_procesados cp
    left join public.vencimientos_detectados v on v.correo_id = cp.id
    where not cp.detalle_compactado
      and (
        (
          v.id is not null
          and v.fecha_vencimiento < current_date - 15
        )
        or (
          v.id is null
          and cp.fecha_procesamiento < now() - interval '30 days'
        )
      )
    order by cp.fecha_procesamiento
    limit 1000
  )
  update public.correos_procesados cp
  set
    gmail_thread_id = null,
    remitente = '',
    asunto = '',
    fecha_correo = null,
    categoria = 'otro',
    grupo_resumen = 'otros',
    relevante = false,
    error_procesamiento = null,
    origen_analisis = 'migracion',
    patron_id = null,
    huella_plantilla = null,
    tokens_entrada = null,
    tokens_cache = null,
    tokens_salida = null,
    duracion_ia_ms = null,
    detalle_compactado = true
  from candidatas
  where cp.id = candidatas.id;
  get diagnostics filas = row_count;
  compactados := compactados + filas;
  exit when filas < 1000;
  end loop;

  for lote in 1..5 loop
  with candidatas as (
    select v.id
    from public.vencimientos_detectados v
    where v.fecha_vencimiento < current_date - 15
    order by v.fecha_vencimiento
    limit 1000
  )
  delete from public.vencimientos_detectados v
  using candidatas
  where v.id = candidatas.id;
  get diagnostics filas = row_count;
  vencimientos_eliminados := vencimientos_eliminados + filas;
  exit when filas < 1000;
  end loop;

  for lote in 1..5 loop
  with candidatas as (
    select cp.id
    from public.correos_procesados cp
    where cp.fecha_procesamiento < now() - interval '120 days'
      and not exists (
        select 1
        from public.vencimientos_detectados v
        where v.correo_id = cp.id
      )
    order by cp.fecha_procesamiento
    limit 1000
  )
  delete from public.correos_procesados cp
  using candidatas
  where cp.id = candidatas.id;
  get diagnostics filas = row_count;
  tombstones_eliminados := tombstones_eliminados + filas;
  exit when filas < 1000;
  end loop;

  for lote in 1..5 loop
  with candidatas as (
    select t.id
    from public.tareas_correos_gmail t
    where (
      t.estado = 'completada'
      and t.actualizado_en < now() - interval '48 hours'
    ) or (
      t.estado = 'error'
      and t.actualizado_en < now() - interval '30 days'
    )
    order by t.actualizado_en
    limit 1000
  )
  delete from public.tareas_correos_gmail t
  using candidatas
  where t.id = candidatas.id;
  get diagnostics filas = row_count;
  tareas_eliminadas := tareas_eliminadas + filas;
  exit when filas < 1000;
  end loop;

  for lote in 1..5 loop
  delete from public.tareas_calendar
  where id in (
    select id
    from public.tareas_calendar
    where (
      estado = 'completada'
      and actualizado_en < now() - interval '48 hours'
    ) or (
      estado = 'error'
      and actualizado_en < now() - interval '30 days'
    )
    order by actualizado_en
    limit 1000
  );
  get diagnostics filas = row_count;
  tareas_calendar_eliminadas := tareas_calendar_eliminadas + filas;
  exit when filas < 1000;
  end loop;

  for lote in 1..5 loop
    delete from public.patrones_correo
    where id in (
      select id
      from public.patrones_correo
      where alcance = 'personal'
        and estado in ('aprendizaje', 'observacion', 'pausado')
        and actualizado_en < now() - interval '90 days'
      order by actualizado_en
      limit 1000
    );
    get diagnostics filas = row_count;
    patrones_eliminados := patrones_eliminados + filas;
    exit when filas < 1000;
  end loop;

  delete from public.oauth_states
  where hash_estado in (
    select hash_estado
    from public.oauth_states
    where vence_en < now() - interval '1 day'
       or usado_en < now() - interval '1 day'
    order by vence_en
    limit 1000
  );

  return jsonb_build_object(
    'correos_compactados', compactados,
    'vencimientos_eliminados', vencimientos_eliminados,
    'tombstones_eliminados', tombstones_eliminados,
    'tareas_eliminadas', tareas_eliminadas,
    'tareas_calendar_eliminadas', tareas_calendar_eliminadas,
    'patrones_eliminados', patrones_eliminados
  );
end
$$;

revoke execute on function private.ejecutar_mantenimiento_agenkin()
  from public, anon, authenticated;
grant execute on function private.ejecutar_mantenimiento_agenkin()
  to service_role;

do $$
declare
  trabajo record;
begin
  for trabajo in
    select jobid from cron.job where jobname = 'agenkin-mantenimiento-diario'
  loop
    perform cron.unschedule(trabajo.jobid);
  end loop;

  perform cron.schedule(
    'agenkin-mantenimiento-diario',
    '43 3 * * *',
    $tarea$select private.ejecutar_mantenimiento_agenkin();$tarea$
  );
end
$$;

create or replace function public.metricas_administrativas()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'registrados', (select count(*) from public.perfiles),
    'activos', (select count(*) from public.perfiles where estado_acceso = 'activo'),
    'prueba', (select count(*) from public.suscripciones where estado = 'prueba'),
    'suspendidos', (
      select count(*) from public.perfiles where estado_acceso = 'suspendido'
    ),
    'bloqueados', (
      select count(*) from public.perfiles where estado_acceso = 'bloqueado'
    ),
    'vencidas', (
      select count(*)
      from public.suscripciones
      where estado = 'vencida' or fecha_vencimiento < now()
    ),
    'correos', (
      select coalesce(sum(correos_procesados), 0)
      from public.consumos_mensuales
      where periodo = date_trunc('month', current_date)::date
    ),
    'eventos', (
      select coalesce(sum(eventos_creados), 0)
      from public.consumos_mensuales
      where periodo = date_trunc('month', current_date)::date
    ),
    'cuentas_gmail', (
      select count(*)
      from public.conexiones_google
      where gmail_conectado and estado_conexion = 'activa'
    ),
    'errores',
      (
        select count(*)
        from public.correos_procesados
        where estado_procesamiento = 'error'
          and fecha_procesamiento > now() - interval '7 days'
      )
      + (
        select count(*)
        from public.conexiones_google
        where estado_conexion in ('error', 'token_vencido')
      ),
    'bytes_base', pg_database_size(current_database()),
    'alerta_almacenamiento', pg_database_size(current_database()) >= 350 * 1024 * 1024,
    'detener_carga_historica', pg_database_size(current_database()) >= 425 * 1024 * 1024
  );
$$;

revoke execute on function public.metricas_administrativas()
  from public, anon, authenticated;
grant execute on function public.metricas_administrativas() to service_role;

create or replace function private.validar_solicitud_mejora_plan()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.suscripciones s
    join public.planes p on p.id = s.plan_id
    where s.usuario_id = new.usuario_id
      and p.es_interno
  ) then
    raise exception 'El plan interno no admite solicitudes de mejora';
  end if;
  return new;
end
$$;

revoke execute on function private.validar_solicitud_mejora_plan()
  from public, anon, authenticated;

drop trigger if exists solicitudes_mejora_bloquear_plan_interno
  on public.solicitudes_mejora_plan;
create trigger solicitudes_mejora_bloquear_plan_interno
before insert on public.solicitudes_mejora_plan
for each row execute function private.validar_solicitud_mejora_plan();

drop policy if exists "solicitudes_mejora_propias_insert"
  on public.solicitudes_mejora_plan;
create policy "solicitudes_mejora_propias_insert"
on public.solicitudes_mejora_plan
for insert
to authenticated
with check (
  (select auth.uid()) = usuario_id
  and estado = 'pendiente'
  and (select private.usuario_habilitado())
);

drop function if exists public.reservar_cupo_correo(uuid);
drop function if exists public.liberar_cupo_correo(uuid);
drop function if exists public.incrementar_eventos_creados(uuid);
drop function if exists public.registrar_evento_calendar(
  uuid, uuid, text, text, timestamptz
);

-- Tablas internas explícitamente fuera de Data API para roles de usuario.
revoke all on all tables in schema public
  from public, anon, authenticated;
revoke all on all sequences in schema public
  from public, anon, authenticated;
revoke execute on all functions in schema public
  from public, anon, authenticated;

alter default privileges for role postgres in schema public
  revoke all on tables from public, anon, authenticated;
alter default privileges for role postgres in schema public
  revoke all on sequences from public, anon, authenticated;
alter default privileges for role postgres in schema public
  revoke execute on functions from public, anon, authenticated;

grant usage on schema public to anon, authenticated;
grant select on table
  public.perfiles,
  public.correos_procesados,
  public.vencimientos_detectados,
  public.eventos_calendar,
  public.reglas_usuario
to authenticated;
grant insert, delete on table public.reglas_usuario to authenticated;
grant insert on table public.solicitudes_mejora_plan to authenticated;

grant execute on function public.registrar_ultimo_acceso()
  to authenticated;
grant execute on function public.obtener_panel_usuario()
  to authenticated;
grant execute on function public.obtener_estado_conexion_google()
  to authenticated;
grant execute on function public.configurar_automatizacion_google(
  boolean, boolean, numeric
) to authenticated;
grant execute on function public.actualizar_grupo_correo(uuid, text)
  to authenticated;
grant execute on function public.descartar_vencimiento(uuid)
  to authenticated;

grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;
