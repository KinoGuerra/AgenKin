-- Suscripciones cifradas y cola durable de Web Push.

alter table public.notificaciones
  add constraint notificaciones_id_usuario_key unique (id, usuario_id);

alter table public.consumos_mensuales
  add column if not exists alertas_entregadas integer not null default 0,
  add column if not exists push_exitosos integer not null default 0,
  add column if not exists push_reintentos integer not null default 0,
  add column if not exists push_terminales integer not null default 0;

create table public.suscripciones_push_web (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.perfiles(id) on delete cascade,
  endpoint_hash text not null unique
    check (endpoint_hash ~ '^[0-9a-f]{64}$'),
  datos_cifrados text not null check (octet_length(datos_cifrados) between 1 and 12000),
  iv text not null check (octet_length(iv) between 1 and 128),
  activa boolean not null default true,
  desactivada_en timestamptz,
  motivo_desactivacion text check (
    motivo_desactivacion is null
    or motivo_desactivacion in ('usuario', 'preferencias', 'expirada', 'terminal')
  ),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (id, usuario_id)
);

create index suscripciones_push_usuario_activas_idx
  on public.suscripciones_push_web (usuario_id, id)
  where activa;
create index suscripciones_push_usuario_idx
  on public.suscripciones_push_web (usuario_id);

drop trigger if exists actualizar_marca_temporal on public.suscripciones_push_web;
create trigger actualizar_marca_temporal
before update on public.suscripciones_push_web
for each row execute function public.actualizar_marca_temporal();

alter table public.suscripciones_push_web enable row level security;
revoke all on public.suscripciones_push_web from public, anon, authenticated;

create table public.entregas_push_web (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.perfiles(id) on delete cascade,
  notificacion_id uuid not null,
  suscripcion_id uuid not null,
  version_evento bigint not null check (version_evento > 0),
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'procesando', 'reintento', 'exitosa', 'terminal', 'cancelada')),
  intentos integer not null default 0 check (intentos between 0 and 4),
  disponible_en timestamptz not null default now(),
  reclamada_en timestamptz,
  finalizada_en timestamptz,
  codigo_error text check (codigo_error is null or char_length(codigo_error) <= 64),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  constraint entregas_push_notificacion_fkey
    foreign key (notificacion_id, usuario_id)
    references public.notificaciones(id, usuario_id) on delete cascade,
  constraint entregas_push_suscripcion_fkey
    foreign key (suscripcion_id, usuario_id)
    references public.suscripciones_push_web(id, usuario_id) on delete cascade,
  unique (notificacion_id, suscripcion_id, version_evento)
);

create index entregas_push_disponibles_idx
  on public.entregas_push_web (disponible_en, id)
  where estado in ('pendiente', 'reintento');
create index entregas_push_suscripcion_idx
  on public.entregas_push_web (suscripcion_id);
create index entregas_push_notificacion_idx
  on public.entregas_push_web (notificacion_id);
create index entregas_push_usuario_idx
  on public.entregas_push_web (usuario_id, creado_en desc);

drop trigger if exists actualizar_marca_temporal on public.entregas_push_web;
create trigger actualizar_marca_temporal
before update on public.entregas_push_web
for each row execute function public.actualizar_marca_temporal();

alter table public.entregas_push_web enable row level security;
revoke all on public.entregas_push_web from public, anon, authenticated;

create or replace function public.registrar_suscripcion_push_web(
  p_usuario_id uuid,
  p_endpoint_hash text,
  p_datos_cifrados text,
  p_iv text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existente public.suscripciones_push_web%rowtype;
  v_id uuid;
begin
  if p_usuario_id is null
    or coalesce(p_endpoint_hash, '') !~ '^[0-9a-f]{64}$'
    or octet_length(coalesce(p_datos_cifrados, '')) not between 1 and 12000
    or octet_length(coalesce(p_iv, '')) not between 1 and 128 then
    raise exception 'SUSCRIPCION_PUSH_INVALIDA';
  end if;
  if not exists (
    select 1 from public.perfiles p
    where p.id = p_usuario_id and p.estado_acceso = 'activo'
  ) then raise exception 'USUARIO_NO_HABILITADO'; end if;

  select * into v_existente
  from public.suscripciones_push_web s
  where s.endpoint_hash = p_endpoint_hash
  for update;

  if v_existente.id is not null and v_existente.usuario_id <> p_usuario_id then
    raise exception 'SUSCRIPCION_OTRO_USUARIO';
  end if;

  if v_existente.id is null then
    insert into public.suscripciones_push_web (
      usuario_id, endpoint_hash, datos_cifrados, iv
    ) values (
      p_usuario_id, p_endpoint_hash, p_datos_cifrados, p_iv
    ) returning id into v_id;
  else
    update public.suscripciones_push_web
    set datos_cifrados = p_datos_cifrados,
        iv = p_iv,
        activa = true,
        desactivada_en = null,
        motivo_desactivacion = null
    where id = v_existente.id
    returning id into v_id;
  end if;
  return v_id;
end
$$;

revoke execute on function public.registrar_suscripcion_push_web(uuid, text, text, text)
  from public, anon, authenticated;
grant execute on function public.registrar_suscripcion_push_web(uuid, text, text, text)
  to service_role;

create or replace function public.desactivar_suscripcion_push_web(
  p_usuario_id uuid,
  p_endpoint_hash text,
  p_motivo text default 'usuario'
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_id uuid;
begin
  if p_motivo not in ('usuario', 'preferencias', 'expirada', 'terminal') then
    raise exception 'MOTIVO_PUSH_INVALIDO';
  end if;
  update public.suscripciones_push_web
  set activa = false,
      desactivada_en = coalesce(desactivada_en, now()),
      motivo_desactivacion = p_motivo
  where usuario_id = p_usuario_id
    and endpoint_hash = p_endpoint_hash
    and activa
  returning id into v_id;

  if v_id is not null then
    update public.entregas_push_web
    set estado = 'cancelada', finalizada_en = now(), codigo_error = 'SUSCRIPCION_INACTIVA'
    where suscripcion_id = v_id
      and estado in ('pendiente', 'reintento', 'procesando');
  end if;
  return v_id is not null;
end
$$;

revoke execute on function public.desactivar_suscripcion_push_web(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.desactivar_suscripcion_push_web(uuid, text, text)
  to service_role;

create or replace function public.desactivar_suscripciones_push_usuario(
  p_usuario_id uuid,
  p_motivo text default 'preferencias'
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_total integer;
begin
  if p_motivo not in ('usuario', 'preferencias') then
    raise exception 'MOTIVO_PUSH_INVALIDO';
  end if;
  update public.suscripciones_push_web
  set activa = false,
      desactivada_en = coalesce(desactivada_en, now()),
      motivo_desactivacion = p_motivo
  where usuario_id = p_usuario_id and activa;
  get diagnostics v_total = row_count;

  update public.entregas_push_web
  set estado = 'cancelada', finalizada_en = now(), codigo_error = 'SUSCRIPCION_INACTIVA'
  where usuario_id = p_usuario_id
    and estado in ('pendiente', 'reintento', 'procesando');
  return v_total;
end
$$;

revoke execute on function public.desactivar_suscripciones_push_usuario(uuid, text)
  from public, anon, authenticated;
grant execute on function public.desactivar_suscripciones_push_usuario(uuid, text)
  to service_role;

create or replace function public.cantidad_suscripciones_push_usuario(p_usuario_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.suscripciones_push_web s
  where s.usuario_id = p_usuario_id and s.activa;
$$;

revoke execute on function public.cantidad_suscripciones_push_usuario(uuid)
  from public, anon, authenticated;
grant execute on function public.cantidad_suscripciones_push_usuario(uuid)
  to service_role;

create or replace function private.cancelar_entregas_push_notificacion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.estado = 'cancelada' and old.estado is distinct from new.estado then
    update public.entregas_push_web
    set estado = 'cancelada', finalizada_en = now(), codigo_error = 'NOTIFICACION_CANCELADA'
    where notificacion_id = new.id
      and estado in ('pendiente', 'reintento', 'procesando');
  end if;
  return new;
end
$$;

revoke execute on function private.cancelar_entregas_push_notificacion()
  from public, anon, authenticated;

create trigger notificaciones_cancelar_push
after update of estado on public.notificaciones
for each row execute function private.cancelar_entregas_push_notificacion();

create or replace function public.entregar_notificaciones_pendientes(
  p_limite integer default 20
)
returns table (
  notificacion_id uuid,
  usuario_id uuid,
  evento_id uuid,
  version_evento bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fila record;
  v_limite integer := least(greatest(coalesce(p_limite, 20), 1), 20);
begin
  for v_fila in
    select
      n.id, n.usuario_id, n.evento_id, n.tipo,
      n.version_evento as notificacion_version,
      e.fecha_evento, e.es_dia_completo,
      e.estado_sincronizacion,
      e.version_notificacion as evento_version,
      p.recibir_notificaciones,
      p.notificar_dia_previo,
      p.notificar_dia_vencimiento,
      p.zona_horaria_notificaciones
    from public.notificaciones n
    left join public.eventos_calendar e
      on e.id = n.evento_id and e.usuario_id = n.usuario_id
    left join public.perfiles p on p.id = n.usuario_id
    where n.estado = 'programada' and n.programada_para <= now()
    order by n.programada_para, n.id
    limit v_limite
    for update of n skip locked
  loop
    if v_fila.evento_id is null
      or v_fila.evento_version is null
      or v_fila.evento_version <> v_fila.notificacion_version
      or v_fila.estado_sincronizacion = 'eliminado'
      or not coalesce(v_fila.recibir_notificaciones, false)
      or (v_fila.tipo = 'dia_previo' and not coalesce(v_fila.notificar_dia_previo, false))
      or (v_fila.tipo = 'dia_vencimiento' and not coalesce(v_fila.notificar_dia_vencimiento, false))
      or not private.evento_notificacion_atendible(
        v_fila.fecha_evento,
        v_fila.es_dia_completo,
        v_fila.zona_horaria_notificaciones
      ) then
      update public.notificaciones
      set estado = 'cancelada', cancelada_en = now()
      where id = v_fila.id;
      continue;
    end if;

    update public.notificaciones
    set estado = 'entregada', entregada_en = now(), cancelada_en = null
    where id = v_fila.id;

    insert into public.consumos_mensuales (
      usuario_id, periodo, alertas_entregadas
    ) values (
      v_fila.usuario_id, date_trunc('month', current_date)::date, 1
    )
    on conflict (usuario_id, periodo) do update set
      alertas_entregadas = public.consumos_mensuales.alertas_entregadas + 1,
      actualizado_en = now();

    insert into public.entregas_push_web (
      usuario_id, notificacion_id, suscripcion_id, version_evento
    )
    select
      v_fila.usuario_id, v_fila.id, s.id, v_fila.notificacion_version
    from public.suscripciones_push_web s
    where s.usuario_id = v_fila.usuario_id and s.activa
    on conflict (notificacion_id, suscripcion_id, version_evento) do nothing;

    notificacion_id := v_fila.id;
    usuario_id := v_fila.usuario_id;
    evento_id := v_fila.evento_id;
    version_evento := v_fila.notificacion_version;
    return next;
  end loop;
end
$$;

revoke execute on function public.entregar_notificaciones_pendientes(integer)
  from public, anon, authenticated;
grant execute on function public.entregar_notificaciones_pendientes(integer)
  to service_role;

create or replace function public.reclamar_entregas_push_web(p_limite integer default 40)
returns table (
  entrega_id uuid,
  usuario_id uuid,
  suscripcion_id uuid,
  notificacion_id uuid,
  version_evento bigint,
  intento integer,
  datos_cifrados text,
  iv text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fila record;
  v_limite integer := least(greatest(coalesce(p_limite, 40), 1), 40);
begin
  update public.entregas_push_web
  set estado = 'reintento', reclamada_en = null, disponible_en = now(),
      codigo_error = 'LEASE_EXPIRADO'
  where id in (
    select id from public.entregas_push_web
    where estado = 'procesando'
      and reclamada_en < now() - interval '5 minutes'
    order by reclamada_en, id
    limit 1000
  );

  for v_fila in
    select
      d.id, d.usuario_id, d.notificacion_id, d.suscripcion_id,
      d.version_evento, d.intentos,
      s.datos_cifrados, s.iv, s.activa,
      n.estado as estado_notificacion,
      e.version_notificacion, e.estado_sincronizacion,
      p.recibir_notificaciones
    from public.entregas_push_web d
    join public.suscripciones_push_web s
      on s.id = d.suscripcion_id and s.usuario_id = d.usuario_id
    join public.notificaciones n
      on n.id = d.notificacion_id and n.usuario_id = d.usuario_id
    left join public.eventos_calendar e
      on e.id = n.evento_id and e.usuario_id = d.usuario_id
    left join public.perfiles p on p.id = d.usuario_id
    where d.estado in ('pendiente', 'reintento')
      and d.disponible_en <= now()
    order by d.disponible_en, d.id
    limit v_limite
    for update of d skip locked
  loop
    if not v_fila.activa
      or v_fila.estado_notificacion <> 'entregada'
      or v_fila.version_notificacion is null
      or v_fila.version_notificacion <> v_fila.version_evento
      or v_fila.estado_sincronizacion = 'eliminado'
      or not coalesce(v_fila.recibir_notificaciones, false)
      or v_fila.intentos >= 4 then
      update public.entregas_push_web
      set estado = case when v_fila.intentos >= 4 then 'terminal' else 'cancelada' end,
          finalizada_en = now(), codigo_error = 'ENTREGA_OBSOLETA'
      where id = v_fila.id;
      continue;
    end if;

    update public.entregas_push_web
    set estado = 'procesando', reclamada_en = now(),
        intentos = intentos + 1, codigo_error = null
    where id = v_fila.id;

    entrega_id := v_fila.id;
    usuario_id := v_fila.usuario_id;
    suscripcion_id := v_fila.suscripcion_id;
    notificacion_id := v_fila.notificacion_id;
    version_evento := v_fila.version_evento;
    intento := v_fila.intentos + 1;
    datos_cifrados := v_fila.datos_cifrados;
    iv := v_fila.iv;
    return next;
  end loop;
end
$$;

revoke execute on function public.reclamar_entregas_push_web(integer)
  from public, anon, authenticated;
grant execute on function public.reclamar_entregas_push_web(integer)
  to service_role;

create or replace function public.finalizar_entrega_push_web(
  p_entrega_id uuid,
  p_intento integer,
  p_estado text,
  p_codigo_error text default null,
  p_disponible_en timestamptz default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare v_usuario_id uuid;
begin
  if p_estado not in ('exitosa', 'reintento', 'terminal') then
    raise exception 'ESTADO_ENTREGA_INVALIDO';
  end if;
  update public.entregas_push_web
  set estado = p_estado,
      disponible_en = case
        when p_estado = 'reintento' then greatest(coalesce(p_disponible_en, now()), now())
        else disponible_en
      end,
      reclamada_en = null,
      finalizada_en = case when p_estado in ('exitosa', 'terminal') then now() else null end,
      codigo_error = nullif(left(coalesce(p_codigo_error, ''), 64), '')
  where id = p_entrega_id
    and estado = 'procesando'
    and intentos = p_intento;
  if not found then return false; end if;
  select usuario_id into v_usuario_id
  from public.entregas_push_web where id = p_entrega_id;
  insert into public.consumos_mensuales (
    usuario_id, periodo, push_exitosos, push_reintentos, push_terminales
  ) values (
    v_usuario_id,
    date_trunc('month', current_date)::date,
    case when p_estado = 'exitosa' then 1 else 0 end,
    case when p_estado = 'reintento' then 1 else 0 end,
    case when p_estado = 'terminal' then 1 else 0 end
  )
  on conflict (usuario_id, periodo) do update set
    push_exitosos = public.consumos_mensuales.push_exitosos + excluded.push_exitosos,
    push_reintentos = public.consumos_mensuales.push_reintentos + excluded.push_reintentos,
    push_terminales = public.consumos_mensuales.push_terminales + excluded.push_terminales,
    actualizado_en = now();
  return true;
end
$$;

revoke execute on function public.finalizar_entrega_push_web(uuid, integer, text, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.finalizar_entrega_push_web(uuid, integer, text, text, timestamptz)
  to service_role;

create or replace function public.actualizar_preferencias_notificacion(
  p_recibir boolean,
  p_dia_previo boolean,
  p_dia_vencimiento boolean,
  p_zona_horaria text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario_id uuid := (select auth.uid());
  v_zona text := nullif(btrim(coalesce(p_zona_horaria, '')), '');
begin
  if v_usuario_id is null then raise exception 'Sesión requerida'; end if;
  if not (select private.usuario_habilitado()) then
    raise exception 'Cuenta o suscripción no habilitada';
  end if;
  if v_zona is null or not exists (
    select 1 from pg_catalog.pg_timezone_names z where z.name = v_zona
  ) then raise exception 'Zona horaria inválida'; end if;

  update public.perfiles
  set recibir_notificaciones = coalesce(p_recibir, false),
      notificar_dia_previo = coalesce(p_dia_previo, false),
      notificar_dia_vencimiento = coalesce(p_dia_vencimiento, false),
      zona_horaria_notificaciones = v_zona
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
      not coalesce(p_recibir, false)
      or (tipo = 'dia_previo' and not coalesce(p_dia_previo, false))
      or (tipo = 'dia_vencimiento' and not coalesce(p_dia_vencimiento, false))
    );

  if not coalesce(p_recibir, false)
    or (not coalesce(p_dia_previo, false) and not coalesce(p_dia_vencimiento, false)) then
    perform public.desactivar_suscripciones_push_usuario(v_usuario_id, 'preferencias');
  end if;

  return jsonb_build_object(
    'recibir_notificaciones', coalesce(p_recibir, false),
    'notificar_dia_previo', coalesce(p_dia_previo, false),
    'notificar_dia_vencimiento', coalesce(p_dia_vencimiento, false),
    'zona_horaria', v_zona
  );
end
$$;

revoke execute on function public.actualizar_preferencias_notificacion(
  boolean, boolean, boolean, text
) from public, anon;
grant execute on function public.actualizar_preferencias_notificacion(
  boolean, boolean, boolean, text
) to authenticated;

create or replace function public.metricas_notificaciones_push()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'revisiones_pendientes', (
      select count(*) from public.correos_procesados where requiere_revision
    ),
    'alertas_pendientes', (
      select count(*) from public.notificaciones where estado = 'programada'
    ),
    'alerta_mas_antigua_minutos', coalesce((
      select floor(extract(epoch from now() - min(programada_para)) / 60)::bigint
      from public.notificaciones where estado = 'programada' and programada_para <= now()
    ), 0),
    'push_exitosos', (
      select coalesce(sum(c.push_exitosos), 0)
      from public.consumos_mensuales c
      where c.periodo = date_trunc('month', current_date)::date
    ),
    'push_temporales', (
      select count(*) from public.entregas_push_web where estado in ('pendiente', 'reintento', 'procesando')
    ),
    'push_terminales', (
      select coalesce(sum(c.push_terminales), 0)
      from public.consumos_mensuales c
      where c.periodo = date_trunc('month', current_date)::date
    ),
    'suscripciones_push_activas', (
      select count(*) from public.suscripciones_push_web where activa
    )
  );
$$;

revoke execute on function public.metricas_notificaciones_push()
  from public, anon, authenticated;
grant execute on function public.metricas_notificaciones_push()
  to service_role;

create or replace function private.limpiar_notificaciones_agenkin()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_notificaciones integer := 0;
  v_entregas integer := 0;
  v_suscripciones integer := 0;
  v_filas integer := 0;
begin
  for v_lote in 1..5 loop
    delete from public.entregas_push_web
    where id in (
      select id from public.entregas_push_web
      where (estado = 'exitosa' and finalizada_en < now() - interval '48 hours')
        or (estado in ('terminal', 'cancelada') and finalizada_en < now() - interval '30 days')
      order by finalizada_en
      limit 1000
    );
    get diagnostics v_filas = row_count;
    v_entregas := v_entregas + v_filas;
    exit when v_filas < 1000;
  end loop;

  for v_lote in 1..5 loop
    delete from public.suscripciones_push_web
    where id in (
      select id from public.suscripciones_push_web
      where not activa and desactivada_en < now() - interval '30 days'
      order by desactivada_en
      limit 1000
    );
    get diagnostics v_filas = row_count;
    v_suscripciones := v_suscripciones + v_filas;
    exit when v_filas < 1000;
  end loop;

  for v_lote in 1..5 loop
    delete from public.notificaciones
    where id in (
      select id from public.notificaciones
      where coalesce(entregada_en, cancelada_en, actualizado_en) < now() - interval '30 days'
      order by coalesce(entregada_en, cancelada_en, actualizado_en)
      limit 1000
    );
    get diagnostics v_filas = row_count;
    v_notificaciones := v_notificaciones + v_filas;
    exit when v_filas < 1000;
  end loop;
  return jsonb_build_object(
    'notificaciones_eliminadas', v_notificaciones,
    'entregas_push_eliminadas', v_entregas,
    'suscripciones_push_eliminadas', v_suscripciones
  );
end
$$;

revoke execute on function private.limpiar_notificaciones_agenkin()
  from public, anon, authenticated;
grant execute on function private.limpiar_notificaciones_agenkin()
  to service_role;
