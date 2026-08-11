-- Preferencias, programación idempotente y centro de alertas interno.

alter table public.perfiles
  add column if not exists recibir_notificaciones boolean not null default false,
  add column if not exists notificar_dia_previo boolean not null default true,
  add column if not exists notificar_dia_vencimiento boolean not null default true,
  add column if not exists zona_horaria_notificaciones text not null
    default 'America/Argentina/Cordoba';

alter table public.eventos_calendar
  add column if not exists version_notificacion bigint not null default 1,
  add column if not exists version_notificacion_programada bigint not null default 0;

create or replace function private.versionar_notificacion_evento()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.fecha_evento is distinct from new.fecha_evento
    or old.titulo is distinct from new.titulo
    or old.zona_horaria is distinct from new.zona_horaria
    or old.es_dia_completo is distinct from new.es_dia_completo
    or old.estado_sincronizacion is distinct from new.estado_sincronizacion then
    new.version_notificacion := old.version_notificacion + 1;
  end if;
  return new;
end
$$;

revoke execute on function private.versionar_notificacion_evento()
  from public, anon, authenticated;

drop trigger if exists eventos_versionar_notificacion on public.eventos_calendar;
create trigger eventos_versionar_notificacion
before update on public.eventos_calendar
for each row execute function private.versionar_notificacion_evento();

create table if not exists public.notificaciones (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.perfiles(id) on delete cascade,
  evento_id uuid,
  tipo text not null check (tipo in ('dia_previo', 'dia_vencimiento')),
  estado text not null default 'programada'
    check (estado in ('programada', 'entregada', 'cancelada')),
  version_evento bigint not null check (version_evento > 0),
  titulo text not null check (char_length(titulo) between 1 and 240),
  mensaje text not null default '' check (char_length(mensaje) <= 500),
  programada_para timestamptz not null,
  entregada_en timestamptz,
  leida_en timestamptz,
  cancelada_en timestamptz,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (evento_id, tipo)
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'notificaciones_evento_usuario_fkey'
      and conrelid = 'public.notificaciones'::regclass
  ) then
    alter table public.notificaciones
      add constraint notificaciones_evento_usuario_fkey
      foreign key (evento_id, usuario_id)
      references public.eventos_calendar(id, usuario_id)
      on delete set null (evento_id);
  end if;
end
$$;

create index if not exists notificaciones_programadas_idx
  on public.notificaciones (programada_para, id)
  where estado = 'programada';
create index if not exists notificaciones_usuario_entregadas_idx
  on public.notificaciones (usuario_id, entregada_en desc, id desc)
  where estado = 'entregada';
create index if not exists notificaciones_usuario_idx
  on public.notificaciones (usuario_id);
create index if not exists notificaciones_usuario_no_leidas_idx
  on public.notificaciones (usuario_id, entregada_en desc)
  where estado = 'entregada' and leida_en is null;
create index if not exists notificaciones_evento_idx
  on public.notificaciones (evento_id)
  where evento_id is not null;
create index if not exists eventos_notificacion_pendiente_idx
  on public.eventos_calendar (actualizado_en, id)
  where version_notificacion > version_notificacion_programada;

drop trigger if exists actualizar_marca_temporal on public.notificaciones;
create trigger actualizar_marca_temporal
before update on public.notificaciones
for each row execute function public.actualizar_marca_temporal();

alter table public.notificaciones enable row level security;
revoke all on public.notificaciones from public, anon, authenticated;
grant select on public.notificaciones to authenticated;

drop policy if exists "notificaciones propias visibles" on public.notificaciones;
create policy "notificaciones propias visibles"
on public.notificaciones for select to authenticated
using (
  usuario_id = (select auth.uid())
  and (select private.usuario_habilitado())
);

create or replace function private.evento_notificacion_atendible(
  p_fecha timestamptz,
  p_dia_completo boolean,
  p_zona text,
  p_ahora timestamptz default now()
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case
    when p_fecha is null then false
    when p_dia_completo then
      (p_fecha at time zone p_zona)::date >= (p_ahora at time zone p_zona)::date
    else p_fecha > p_ahora
  end;
$$;

revoke execute on function private.evento_notificacion_atendible(
  timestamptz, boolean, text, timestamptz
) from public, anon, authenticated;

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
            + time '09:00'
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
      n.id,
      n.usuario_id,
      n.evento_id,
      n.tipo,
      n.version_evento as notificacion_version,
      e.fecha_evento,
      e.es_dia_completo,
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
    where n.estado = 'programada'
      and n.programada_para <= now()
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

create or replace function public.marcar_notificacion_leida(p_notificacion_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then raise exception 'Sesión requerida'; end if;
  if not (select private.usuario_habilitado()) then
    raise exception 'Cuenta o suscripción no habilitada';
  end if;
  update public.notificaciones
  set leida_en = coalesce(leida_en, now())
  where id = p_notificacion_id
    and usuario_id = (select auth.uid())
    and estado = 'entregada';
  return found;
end
$$;

revoke execute on function public.marcar_notificacion_leida(uuid)
  from public, anon;
grant execute on function public.marcar_notificacion_leida(uuid)
  to authenticated;

create or replace function public.marcar_notificaciones_leidas()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_total integer;
begin
  if (select auth.uid()) is null then raise exception 'Sesión requerida'; end if;
  if not (select private.usuario_habilitado()) then
    raise exception 'Cuenta o suscripción no habilitada';
  end if;
  update public.notificaciones
  set leida_en = now()
  where usuario_id = (select auth.uid())
    and estado = 'entregada'
    and leida_en is null;
  get diagnostics v_total = row_count;
  return v_total;
end
$$;

revoke execute on function public.marcar_notificaciones_leidas()
  from public, anon;
grant execute on function public.marcar_notificaciones_leidas()
  to authenticated;

create or replace function private.limpiar_notificaciones_agenkin()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_total integer := 0;
  v_filas integer := 0;
begin
  for v_lote in 1..5 loop
    delete from public.notificaciones
    where id in (
      select id from public.notificaciones
      where coalesce(entregada_en, cancelada_en, actualizado_en) < now() - interval '30 days'
      order by coalesce(entregada_en, cancelada_en, actualizado_en)
      limit 1000
    );
    get diagnostics v_filas = row_count;
    v_total := v_total + v_filas;
    exit when v_filas < 1000;
  end loop;
  return jsonb_build_object('notificaciones_eliminadas', v_total);
end
$$;

revoke execute on function private.limpiar_notificaciones_agenkin()
  from public, anon, authenticated;
grant execute on function private.limpiar_notificaciones_agenkin()
  to service_role;

-- El Cron se activa en una migración posterior, después de desplegar la función.
