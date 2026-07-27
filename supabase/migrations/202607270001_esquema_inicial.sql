-- Esquema inicial de AgenKin. Diseñado para ejecutarse de forma segura más de una vez.
create extension if not exists pgcrypto;

do $$ begin create type public.rol_usuario as enum ('usuario', 'superadministrador'); exception when duplicate_object then null; end $$;
do $$ begin create type public.estado_acceso as enum ('activo', 'suspendido', 'bloqueado', 'cancelado'); exception when duplicate_object then null; end $$;
do $$ begin create type public.estado_suscripcion as enum ('prueba', 'activa', 'pago_pendiente', 'suspendida', 'vencida', 'cancelada'); exception when duplicate_object then null; end $$;
do $$ begin create type public.estado_vencimiento as enum ('pendiente', 'confirmado', 'descartado', 'evento_creado', 'error'); exception when duplicate_object then null; end $$;
do $$ begin create type public.estado_conexion as enum ('desconectada', 'activa', 'token_vencido', 'error'); exception when duplicate_object then null; end $$;
do $$ begin create type public.estado_procesamiento as enum ('procesado', 'ignorado', 'error'); exception when duplicate_object then null; end $$;
do $$ begin create type public.estado_sincronizacion as enum ('creado', 'error', 'eliminado'); exception when duplicate_object then null; end $$;

create table if not exists public.planes (
  id uuid primary key default gen_random_uuid(),
  nombre text not null unique,
  descripcion text not null default '',
  precio numeric(12,2) not null default 0 check (precio >= 0),
  moneda char(3) not null default 'ARS',
  limite_correos_mensuales integer not null check (limite_correos_mensuales > 0),
  permite_automatizacion boolean not null default false,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

insert into public.planes (nombre, descripcion, precio, moneda, limite_correos_mensuales, permite_automatizacion)
values
  ('Prueba', 'Período inicial de evaluación por 15 días.', 0, 'ARS', 50, false),
  ('Básico', 'Organización personal de vencimientos.', 0, 'ARS', 300, false),
  ('Profesional', 'Mayor volumen y automatización futura.', 0, 'ARS', 1500, true)
on conflict (nombre) do update set
  descripcion = excluded.descripcion,
  limite_correos_mensuales = excluded.limite_correos_mensuales,
  permite_automatizacion = excluded.permite_automatizacion;

create table if not exists public.perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre_completo text not null default '',
  email text not null,
  avatar_url text,
  rol public.rol_usuario not null default 'usuario',
  estado_acceso public.estado_acceso not null default 'activo',
  fecha_registro timestamptz not null default now(),
  ultimo_acceso timestamptz,
  actualizado_en timestamptz not null default now()
);

create table if not exists public.suscripciones (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null unique references public.perfiles(id) on delete cascade,
  plan_id uuid not null references public.planes(id),
  estado public.estado_suscripcion not null default 'prueba',
  fecha_inicio timestamptz not null default now(),
  fecha_vencimiento timestamptz not null,
  renovacion_automatica boolean not null default false,
  fecha_ultimo_pago timestamptz,
  observaciones_internas text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  check (fecha_vencimiento >= fecha_inicio)
);

create table if not exists public.consumos_mensuales (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.perfiles(id) on delete cascade,
  periodo date not null check (periodo = date_trunc('month', periodo)::date),
  correos_procesados integer not null default 0 check (correos_procesados >= 0),
  eventos_creados integer not null default 0 check (eventos_creados >= 0),
  actualizado_en timestamptz not null default now(),
  unique (usuario_id, periodo)
);

create table if not exists public.conexiones_google (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null unique references public.perfiles(id) on delete cascade,
  google_email text,
  gmail_conectado boolean not null default false,
  calendar_conectado boolean not null default false,
  calendar_id text,
  refresh_token_cifrado text,
  token_iv text,
  fecha_ultima_sincronizacion timestamptz,
  estado_conexion public.estado_conexion not null default 'desconectada',
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  check (
    (refresh_token_cifrado is null and token_iv is null)
    or (refresh_token_cifrado is not null and token_iv is not null)
  )
);

create table if not exists public.correos_procesados (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.perfiles(id) on delete cascade,
  gmail_message_id text not null,
  gmail_thread_id text,
  remitente text not null default '',
  asunto text not null default '',
  fecha_correo timestamptz,
  categoria text not null default 'otro',
  relevante boolean not null default false,
  fecha_procesamiento timestamptz not null default now(),
  estado_procesamiento public.estado_procesamiento not null default 'procesado',
  error_procesamiento text,
  unique (usuario_id, gmail_message_id)
);

create table if not exists public.vencimientos_detectados (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.perfiles(id) on delete cascade,
  correo_id uuid not null references public.correos_procesados(id) on delete cascade,
  tipo text not null,
  titulo text not null check (char_length(titulo) between 1 and 160),
  descripcion text not null default '',
  fecha_vencimiento date not null,
  hora_vencimiento time,
  zona_horaria text not null default 'America/Argentina/Cordoba',
  confianza numeric(4,3) not null check (confianza between 0 and 1),
  explicacion text not null default '',
  estado public.estado_vencimiento not null default 'pendiente',
  requiere_revision boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table if not exists public.eventos_calendar (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.perfiles(id) on delete cascade,
  vencimiento_id uuid not null unique references public.vencimientos_detectados(id) on delete cascade,
  google_event_id text not null,
  calendar_id text not null,
  fecha_evento timestamptz not null,
  estado_sincronizacion public.estado_sincronizacion not null default 'creado',
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (usuario_id, google_event_id)
);

create table if not exists public.reglas_usuario (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null default auth.uid() references public.perfiles(id) on delete cascade,
  nombre text not null check (char_length(nombre) between 1 and 100),
  campo text not null check (campo in ('remitente', 'asunto')),
  operador text not null check (operador in ('contiene', 'igual')),
  valor text not null check (char_length(valor) between 1 and 200),
  accion text not null check (accion in ('priorizar', 'ignorar')),
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

create table if not exists public.auditoria_administrativa (
  id uuid primary key default gen_random_uuid(),
  administrador_id uuid not null references public.perfiles(id),
  usuario_afectado_id uuid references public.perfiles(id) on delete set null,
  accion text not null,
  detalle text,
  datos_anteriores jsonb,
  datos_nuevos jsonb,
  creado_en timestamptz not null default now()
);

create table if not exists public.oauth_states (
  hash_estado text primary key,
  usuario_id uuid not null references public.perfiles(id) on delete cascade,
  creado_en timestamptz not null default now(),
  vence_en timestamptz not null,
  usado_en timestamptz
);

create or replace function public.actualizar_marca_temporal()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.actualizado_en = now();
  return new;
end;
$$;

do $$
declare tabla text;
begin
  foreach tabla in array array[
    'planes', 'perfiles', 'suscripciones', 'consumos_mensuales',
    'conexiones_google', 'vencimientos_detectados', 'eventos_calendar'
  ] loop
    execute format('drop trigger if exists actualizar_marca_temporal on public.%I', tabla);
    execute format(
      'create trigger actualizar_marca_temporal before update on public.%I for each row execute function public.actualizar_marca_temporal()',
      tabla
    );
  end loop;
end $$;

create or replace function public.crear_usuario_inicial()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare plan_prueba uuid;
begin
  select id into plan_prueba from public.planes where nombre = 'Prueba' and activo limit 1;
  if plan_prueba is null then raise exception 'El plan Prueba no está configurado'; end if;

  insert into public.perfiles (id, nombre_completo, email, avatar_url, rol, estado_acceso)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
    coalesce(new.email, ''),
    new.raw_user_meta_data ->> 'avatar_url',
    'usuario',
    'activo'
  )
  on conflict (id) do nothing;

  insert into public.suscripciones (usuario_id, plan_id, estado, fecha_inicio, fecha_vencimiento)
  values (new.id, plan_prueba, 'prueba', now(), now() + interval '15 days')
  on conflict (usuario_id) do nothing;
  return new;
end;
$$;

drop trigger if exists crear_usuario_inicial on auth.users;
create trigger crear_usuario_inicial
after insert on auth.users
for each row execute function public.crear_usuario_inicial();

create or replace function public.es_superadministrador(usuario uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.perfiles
    where id = usuario and rol = 'superadministrador' and estado_acceso = 'activo'
  );
$$;

create or replace function public.usuario_habilitado(usuario uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.perfiles p
    join public.suscripciones s on s.usuario_id = p.id
    where p.id = usuario
      and p.estado_acceso = 'activo'
      and s.estado in ('prueba', 'activa')
      and s.fecha_vencimiento >= now()
  );
$$;

create or replace function public.registrar_ultimo_acceso()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.perfiles set ultimo_acceso = now() where id = auth.uid();
$$;

create or replace function public.obtener_panel_usuario()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'correos_procesados', coalesce(c.correos_procesados, 0),
    'eventos_creados', coalesce(c.eventos_creados, 0),
    'vencimientos_detectados', (select count(*) from public.vencimientos_detectados v where v.usuario_id = auth.uid()),
    'pendientes_revision', (select count(*) from public.vencimientos_detectados v where v.usuario_id = auth.uid() and v.estado = 'pendiente'),
    'suscripcion', jsonb_build_object(
      'plan', p.nombre,
      'estado', s.estado,
      'fecha_inicio', s.fecha_inicio,
      'fecha_vencimiento', s.fecha_vencimiento,
      'limite_correos_mensuales', p.limite_correos_mensuales
    )
  )
  from public.suscripciones s
  join public.planes p on p.id = s.plan_id
  left join public.consumos_mensuales c
    on c.usuario_id = s.usuario_id and c.periodo = date_trunc('month', current_date)::date
  where s.usuario_id = auth.uid();
$$;

create or replace function public.obtener_estado_conexion_google()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select jsonb_build_object(
        'conectado', estado_conexion = 'activa' and gmail_conectado and calendar_conectado,
        'google_email', google_email,
        'gmail_conectado', gmail_conectado,
        'calendar_conectado', calendar_conectado,
        'fecha_ultima_sincronizacion', fecha_ultima_sincronizacion,
        'estado_conexion', estado_conexion
      )
      from public.conexiones_google where usuario_id = auth.uid()
    ),
    '{"conectado": false, "estado_conexion": "desconectada"}'::jsonb
  );
$$;

create or replace function public.aplicar_accion_administrativa(
  p_administrador_id uuid,
  p_usuario_id uuid,
  p_accion text,
  p_plan_id uuid default null,
  p_fecha_vencimiento timestamptz default null,
  p_observacion text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  antes jsonb;
  despues jsonb;
begin
  if not public.es_superadministrador(p_administrador_id) then
    raise exception 'Acceso administrativo denegado';
  end if;
  if p_administrador_id = p_usuario_id and p_accion in ('bloquear', 'suspender', 'cancelar_suscripcion') then
    raise exception 'No puede restringir su propia cuenta';
  end if;

  select jsonb_build_object(
    'estado_acceso', p.estado_acceso,
    'plan_id', s.plan_id,
    'estado_suscripcion', s.estado,
    'fecha_vencimiento', s.fecha_vencimiento
  ) into antes
  from public.perfiles p join public.suscripciones s on s.usuario_id = p.id
  where p.id = p_usuario_id for update;
  if antes is null then raise exception 'Usuario no encontrado'; end if;

  case p_accion
    when 'activar' then update public.perfiles set estado_acceso = 'activo' where id = p_usuario_id;
    when 'desbloquear' then update public.perfiles set estado_acceso = 'activo' where id = p_usuario_id;
    when 'suspender' then update public.perfiles set estado_acceso = 'suspendido' where id = p_usuario_id;
    when 'bloquear' then update public.perfiles set estado_acceso = 'bloqueado' where id = p_usuario_id;
    when 'cambiar_plan' then
      if not exists (select 1 from public.planes where id = p_plan_id and activo) then raise exception 'Plan inválido'; end if;
      update public.suscripciones set plan_id = p_plan_id, estado = 'activa' where usuario_id = p_usuario_id;
    when 'extender_prueba' then
      if p_fecha_vencimiento is null or p_fecha_vencimiento <= now() then raise exception 'Fecha inválida'; end if;
      update public.suscripciones set fecha_vencimiento = p_fecha_vencimiento, estado = 'prueba' where usuario_id = p_usuario_id;
    when 'cambiar_vencimiento' then
      if p_fecha_vencimiento is null then raise exception 'Fecha inválida'; end if;
      update public.suscripciones set fecha_vencimiento = p_fecha_vencimiento where usuario_id = p_usuario_id;
    when 'cancelar_suscripcion' then update public.suscripciones set estado = 'cancelada', renovacion_automatica = false where usuario_id = p_usuario_id;
    when 'registrar_observacion' then update public.suscripciones set observaciones_internas = left(coalesce(p_observacion, ''), 1000) where usuario_id = p_usuario_id;
    else raise exception 'Acción no permitida';
  end case;

  select jsonb_build_object(
    'estado_acceso', p.estado_acceso,
    'plan_id', s.plan_id,
    'estado_suscripcion', s.estado,
    'fecha_vencimiento', s.fecha_vencimiento
  ) into despues
  from public.perfiles p join public.suscripciones s on s.usuario_id = p.id
  where p.id = p_usuario_id;

  insert into public.auditoria_administrativa (
    administrador_id, usuario_afectado_id, accion, detalle, datos_anteriores, datos_nuevos
  ) values (
    p_administrador_id, p_usuario_id, p_accion, left(p_observacion, 1000), antes, despues
  );
end;
$$;

create or replace function public.reservar_cupo_correo(p_usuario_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  limite integer;
  nuevos integer;
  periodo_actual date := date_trunc('month', current_date)::date;
begin
  select p.limite_correos_mensuales into limite
  from public.suscripciones s
  join public.planes p on p.id = s.plan_id
  join public.perfiles pe on pe.id = s.usuario_id
  where s.usuario_id = p_usuario_id
    and pe.estado_acceso = 'activo'
    and s.estado in ('prueba', 'activa')
    and s.fecha_vencimiento >= now()
  for update of s;
  if limite is null then return false; end if;

  insert into public.consumos_mensuales (usuario_id, periodo, correos_procesados)
  values (p_usuario_id, periodo_actual, 1)
  on conflict (usuario_id, periodo) do update
    set correos_procesados = public.consumos_mensuales.correos_procesados + 1
    where public.consumos_mensuales.correos_procesados < limite
  returning correos_procesados into nuevos;
  return nuevos is not null and nuevos <= limite;
end;
$$;

create or replace function public.incrementar_eventos_creados(p_usuario_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.consumos_mensuales (usuario_id, periodo, eventos_creados)
  values (p_usuario_id, date_trunc('month', current_date)::date, 1)
  on conflict (usuario_id, periodo) do update
    set eventos_creados = public.consumos_mensuales.eventos_creados + 1;
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
    'suspendidos', (select count(*) from public.perfiles where estado_acceso = 'suspendido'),
    'bloqueados', (select count(*) from public.perfiles where estado_acceso = 'bloqueado'),
    'vencidas', (select count(*) from public.suscripciones where estado = 'vencida' or fecha_vencimiento < now()),
    'correos', (select coalesce(sum(correos_procesados), 0) from public.consumos_mensuales where periodo = date_trunc('month', current_date)::date),
    'eventos', (select coalesce(sum(eventos_creados), 0) from public.consumos_mensuales where periodo = date_trunc('month', current_date)::date),
    'errores',
      (select count(*) from public.correos_procesados where estado_procesamiento = 'error' and fecha_procesamiento > now() - interval '7 days')
      + (select count(*) from public.conexiones_google where estado_conexion in ('error', 'token_vencido'))
  );
$$;

create index if not exists perfiles_email_idx on public.perfiles (lower(email));
create index if not exists perfiles_estado_idx on public.perfiles (estado_acceso);
create index if not exists suscripciones_estado_vencimiento_idx on public.suscripciones (estado, fecha_vencimiento);
create index if not exists consumos_usuario_periodo_idx on public.consumos_mensuales (usuario_id, periodo desc);
create index if not exists correos_usuario_fecha_idx on public.correos_procesados (usuario_id, fecha_correo desc);
create index if not exists correos_estado_idx on public.correos_procesados (estado_procesamiento);
create index if not exists vencimientos_usuario_estado_fecha_idx on public.vencimientos_detectados (usuario_id, estado, fecha_vencimiento);
create index if not exists eventos_usuario_fecha_idx on public.eventos_calendar (usuario_id, fecha_evento desc);
create index if not exists reglas_usuario_idx on public.reglas_usuario (usuario_id, activo);
create index if not exists auditoria_fecha_idx on public.auditoria_administrativa (creado_en desc);
create index if not exists oauth_states_vencimiento_idx on public.oauth_states (vence_en);

alter table public.planes enable row level security;
alter table public.perfiles enable row level security;
alter table public.suscripciones enable row level security;
alter table public.consumos_mensuales enable row level security;
alter table public.conexiones_google enable row level security;
alter table public.correos_procesados enable row level security;
alter table public.vencimientos_detectados enable row level security;
alter table public.eventos_calendar enable row level security;
alter table public.reglas_usuario enable row level security;
alter table public.auditoria_administrativa enable row level security;
alter table public.oauth_states enable row level security;

drop policy if exists "planes visibles" on public.planes;
create policy "planes visibles" on public.planes for select to authenticated using (activo);
drop policy if exists "perfil propio visible" on public.perfiles;
create policy "perfil propio visible" on public.perfiles for select to authenticated using (id = auth.uid());
drop policy if exists "consumo propio visible" on public.consumos_mensuales;
create policy "consumo propio visible" on public.consumos_mensuales for select to authenticated using (usuario_id = auth.uid());
drop policy if exists "correos propios visibles" on public.correos_procesados;
create policy "correos propios visibles" on public.correos_procesados for select to authenticated using (usuario_id = auth.uid());
drop policy if exists "vencimientos propios visibles" on public.vencimientos_detectados;
create policy "vencimientos propios visibles" on public.vencimientos_detectados for select to authenticated using (usuario_id = auth.uid());
drop policy if exists "vencimientos propios editables" on public.vencimientos_detectados;
create policy "vencimientos propios editables" on public.vencimientos_detectados for update to authenticated
  using (usuario_id = auth.uid() and public.usuario_habilitado())
  with check (usuario_id = auth.uid());
drop policy if exists "eventos propios visibles" on public.eventos_calendar;
create policy "eventos propios visibles" on public.eventos_calendar for select to authenticated using (usuario_id = auth.uid());
drop policy if exists "reglas propias visibles" on public.reglas_usuario;
create policy "reglas propias visibles" on public.reglas_usuario for select to authenticated using (usuario_id = auth.uid());
drop policy if exists "reglas propias creadas" on public.reglas_usuario;
create policy "reglas propias creadas" on public.reglas_usuario for insert to authenticated with check (usuario_id = auth.uid() and public.usuario_habilitado());
drop policy if exists "reglas propias editables" on public.reglas_usuario;
create policy "reglas propias editables" on public.reglas_usuario for update to authenticated using (usuario_id = auth.uid()) with check (usuario_id = auth.uid());
drop policy if exists "reglas propias eliminables" on public.reglas_usuario;
create policy "reglas propias eliminables" on public.reglas_usuario for delete to authenticated using (usuario_id = auth.uid());

revoke all on public.suscripciones, public.conexiones_google, public.auditoria_administrativa, public.oauth_states from anon, authenticated;
grant select on public.planes, public.perfiles, public.consumos_mensuales, public.correos_procesados, public.eventos_calendar to authenticated;
grant select, update on public.vencimientos_detectados to authenticated;
grant select, insert, update, delete on public.reglas_usuario to authenticated;
grant execute on function public.registrar_ultimo_acceso() to authenticated;
grant execute on function public.obtener_panel_usuario() to authenticated;
grant execute on function public.obtener_estado_conexion_google() to authenticated;
revoke execute on function public.aplicar_accion_administrativa(uuid, uuid, text, uuid, timestamptz, text) from public, anon, authenticated;
grant execute on function public.aplicar_accion_administrativa(uuid, uuid, text, uuid, timestamptz, text) to service_role;
revoke execute on function public.reservar_cupo_correo(uuid), public.incrementar_eventos_creados(uuid), public.metricas_administrativas() from public, anon, authenticated;
grant execute on function public.reservar_cupo_correo(uuid), public.incrementar_eventos_creados(uuid), public.metricas_administrativas() to service_role;
