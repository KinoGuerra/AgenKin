-- Recupera el flujo reciente sin volver a abrir indefinidamente el histórico.
alter table public.tareas_correos_gmail
  add column if not exists origen_sincronizacion text not null default 'historica',
  add column if not exists intentos_ia integer not null default 0;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'tareas_gmail_origen_sincronizacion_check'
      and conrelid = 'public.tareas_correos_gmail'::regclass
  ) then
    alter table public.tareas_correos_gmail
      add constraint tareas_gmail_origen_sincronizacion_check
      check (origen_sincronizacion in ('incremental', 'reconciliacion', 'historica'));
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'tareas_gmail_intentos_ia_check'
      and conrelid = 'public.tareas_correos_gmail'::regclass
  ) then
    alter table public.tareas_correos_gmail
      add constraint tareas_gmail_intentos_ia_check check (intentos_ia between 0 and 2);
  end if;
end
$$;

alter table public.conexiones_google
  add column if not exists gmail_reconciliacion_desde date,
  add column if not exists gmail_reconciliacion_page_token text,
  add column if not exists gmail_ultima_reconciliacion_en timestamptz;

create table if not exists private.consumo_ia_diario (
  fecha date primary key,
  solicitudes integer not null default 0 check (solicitudes >= 0),
  solicitudes_historicas integer not null default 0 check (solicitudes_historicas >= 0),
  tokens_contabilizados bigint not null default 0 check (tokens_contabilizados >= 0),
  tokens_reservados bigint not null default 0 check (tokens_reservados >= 0),
  bloqueado_hasta timestamptz,
  actualizado_en timestamptz not null default now()
);

revoke all on private.consumo_ia_diario from public, anon, authenticated;

drop index if exists public.tareas_gmail_disponibles_idx;
create index tareas_gmail_disponibles_idx
  on public.tareas_correos_gmail (
    origen_sincronizacion,
    disponible_en,
    creado_en desc
  )
  where estado in ('pendiente', 'procesando');

drop function if exists public.registrar_tareas_correos_gmail(uuid, uuid, text[]);
create function public.registrar_tareas_correos_gmail(
  p_usuario_id uuid,
  p_conexion_google_id uuid,
  p_gmail_message_ids text[],
  p_origen_sincronizacion text default 'incremental'
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_abiertas integer;
  v_nuevas text[];
  v_total integer;
begin
  if p_origen_sincronizacion not in ('incremental', 'reconciliacion', 'historica') then
    raise exception 'ORIGEN_SINCRONIZACION_INVALIDO';
  end if;
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
  if coalesce(cardinality(p_gmail_message_ids), 0) > 100 then
    raise exception 'LOTE_GMAIL_DEMASIADO_GRANDE';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('agenkin_cola_gmail'));

  select coalesce(array_agg(candidato.identificador order by candidato.orden), array[]::text[])
  into v_nuevas
  from (
    select distinct on (btrim(valor))
      btrim(valor) as identificador,
      orden
    from unnest(coalesce(p_gmail_message_ids, array[]::text[]))
      with ordinality as entrada(valor, orden)
    where btrim(valor) ~ '^[A-Za-z0-9_-]{1,128}$'
    order by btrim(valor), orden
  ) candidato
  where not exists (
    select 1
    from public.tareas_correos_gmail t
    where t.conexion_google_id = p_conexion_google_id
      and t.gmail_message_id = candidato.identificador
  );

  if coalesce(cardinality(v_nuevas), 0) = 0 then
    return 0;
  end if;

  select count(*) into v_abiertas
  from public.tareas_correos_gmail
  where estado in ('pendiente', 'procesando');

  if v_abiertas + cardinality(v_nuevas) > 500 then
    raise exception 'COLA_GMAIL_SATURADA';
  end if;

  insert into public.tareas_correos_gmail (
    usuario_id,
    conexion_google_id,
    gmail_message_id,
    estado,
    disponible_en,
    origen_sincronizacion
  )
  select
    p_usuario_id,
    p_conexion_google_id,
    identificador,
    'pendiente',
    now(),
    p_origen_sincronizacion
  from unnest(v_nuevas) as identificador
  on conflict (conexion_google_id, gmail_message_id) do nothing;
  get diagnostics v_total = row_count;
  return v_total;
end
$$;

revoke execute on function public.registrar_tareas_correos_gmail(uuid, uuid, text[], text)
  from public, anon, authenticated;
grant execute on function public.registrar_tareas_correos_gmail(uuid, uuid, text[], text)
  to service_role;

drop function if exists public.leer_tareas_correos_gmail(integer);
create function public.leer_tareas_correos_gmail(p_cantidad integer default 20)
returns table (
  tarea_id uuid,
  intentos integer,
  intentos_ia integer,
  origen_sincronizacion text,
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
      case when t.origen_sincronizacion = 'historica' then 1 else 0 end as prioridad,
      row_number() over (
        partition by t.conexion_google_id
        order by
          case when t.origen_sincronizacion = 'historica' then 1 else 0 end,
          case when t.origen_sincronizacion = 'historica' then t.creado_en end,
          case when t.origen_sincronizacion <> 'historica' then t.creado_en end desc,
          t.disponible_en
      ) as ronda
    from public.tareas_correos_gmail t
    where (
      t.estado = 'pendiente'
      and t.disponible_en <= now()
    ) or (
      t.estado = 'procesando'
      and (t.reclamada_en is null or t.reclamada_en < now() - interval '10 minutes')
    )
  ),
  elegidas as (
    select t.id
    from public.tareas_correos_gmail t
    join ordenadas o on o.id = t.id
    order by o.ronda, o.prioridad, t.disponible_en, t.creado_en desc
    limit least(greatest(p_cantidad, 1), 20)
    for update of t skip locked
  ),
  reclamadas as (
    update public.tareas_correos_gmail t
    set estado = 'procesando', reclamada_en = now()
    from elegidas e
    where t.id = e.id
    returning
      t.id,
      t.intentos,
      t.intentos_ia,
      t.origen_sincronizacion,
      t.usuario_id,
      t.conexion_google_id,
      t.gmail_message_id
  )
  select * from reclamadas;
$$;

revoke execute on function public.leer_tareas_correos_gmail(integer)
  from public, anon, authenticated;
grant execute on function public.leer_tareas_correos_gmail(integer) to service_role;

create or replace function public.reservar_presupuesto_ia(
  p_tarea_id uuid,
  p_max_solicitudes integer default 300,
  p_max_tokens bigint default 80000,
  p_max_historicas integer default 20,
  p_tokens_estimados integer default 250
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tarea public.tareas_correos_gmail%rowtype;
  v_control private.consumo_ia_diario%rowtype;
  v_fecha date := (now() at time zone 'America/Argentina/Cordoba')::date;
  v_siguiente timestamptz := (
    ((now() at time zone 'America/Argentina/Cordoba')::date + 1)
      at time zone 'America/Argentina/Cordoba'
  );
  v_historica boolean;
begin
  select * into v_tarea
  from public.tareas_correos_gmail t
  where t.id = p_tarea_id and t.estado = 'procesando'
  for update;
  if v_tarea.id is null then
    return jsonb_build_object('permitido', false, 'motivo', 'tarea_invalida');
  end if;
  if v_tarea.intentos_ia >= 2 then
    return jsonb_build_object('permitido', false, 'motivo', 'intentos_agotados');
  end if;

  v_historica := v_tarea.origen_sincronizacion = 'historica';
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('agenkin_presupuesto_ia'));
  insert into private.consumo_ia_diario (fecha) values (v_fecha)
  on conflict (fecha) do nothing;
  select * into v_control
  from private.consumo_ia_diario c
  where c.fecha = v_fecha
  for update;

  if v_control.bloqueado_hasta is not null and v_control.bloqueado_hasta > now() then
    return jsonb_build_object(
      'permitido', false,
      'motivo', 'proveedor_bloqueado',
      'disponible_en', v_control.bloqueado_hasta
    );
  end if;
  if v_control.solicitudes >= least(greatest(p_max_solicitudes, 1), 10000)
    or v_control.tokens_contabilizados + v_control.tokens_reservados
      + least(greatest(p_tokens_estimados, 1), 10000) > least(greatest(p_max_tokens, 1), 100000000)
    or (v_historica and v_control.solicitudes_historicas >= least(greatest(p_max_historicas, 0), 1000)) then
    return jsonb_build_object(
      'permitido', false,
      'motivo', case
        when v_historica and v_control.solicitudes_historicas >= p_max_historicas
          then 'presupuesto_historico'
        else 'presupuesto_diario'
      end,
      'disponible_en', v_siguiente
    );
  end if;

  update private.consumo_ia_diario
  set
    solicitudes = solicitudes + 1,
    solicitudes_historicas = solicitudes_historicas + case when v_historica then 1 else 0 end,
    tokens_reservados = tokens_reservados + least(greatest(p_tokens_estimados, 1), 10000),
    bloqueado_hasta = null,
    actualizado_en = now()
  where fecha = v_fecha;
  update public.tareas_correos_gmail
  set intentos_ia = intentos_ia + 1
  where id = v_tarea.id;

  return jsonb_build_object(
    'permitido', true,
    'motivo', 'reservado',
    'intentos_ia', v_tarea.intentos_ia + 1
  );
end
$$;

create or replace function public.confirmar_consumo_ia(
  p_tokens_no_cacheados integer,
  p_tokens_reservados integer default 250
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fecha date := (now() at time zone 'America/Argentina/Cordoba')::date;
begin
  update private.consumo_ia_diario
  set
    tokens_reservados = greatest(tokens_reservados - least(greatest(p_tokens_reservados, 0), 10000), 0),
    tokens_contabilizados = tokens_contabilizados + least(greatest(p_tokens_no_cacheados, 0), 1000000),
    actualizado_en = now()
  where fecha = v_fecha;
end
$$;

create or replace function public.bloquear_proveedor_ia(p_hasta timestamptz)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_fecha date := (now() at time zone 'America/Argentina/Cordoba')::date;
  v_hasta timestamptz := least(greatest(coalesce(p_hasta, now() + interval '15 minutes'), now()), now() + interval '24 hours');
begin
  insert into private.consumo_ia_diario (fecha, bloqueado_hasta)
  values (v_fecha, v_hasta)
  on conflict (fecha) do update
    set
      bloqueado_hasta = greatest(private.consumo_ia_diario.bloqueado_hasta, excluded.bloqueado_hasta),
      actualizado_en = now();
end
$$;

revoke execute on function public.reservar_presupuesto_ia(uuid, integer, bigint, integer, integer)
  from public, anon, authenticated;
revoke execute on function public.confirmar_consumo_ia(integer, integer)
  from public, anon, authenticated;
revoke execute on function public.bloquear_proveedor_ia(timestamptz)
  from public, anon, authenticated;
grant execute on function public.reservar_presupuesto_ia(uuid, integer, bigint, integer, integer)
  to service_role;
grant execute on function public.confirmar_consumo_ia(integer, integer) to service_role;
grant execute on function public.bloquear_proveedor_ia(timestamptz) to service_role;

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
  sincronizacion_inicial_completa boolean,
  gmail_reconciliacion_desde date,
  gmail_reconciliacion_page_token text,
  gmail_ultima_reconciliacion_en timestamptz
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
    a.sincronizacion_inicial_completa,
    a.gmail_reconciliacion_desde,
    a.gmail_reconciliacion_page_token,
    a.gmail_ultima_reconciliacion_en
  from actualizadas a;
$$;

revoke execute on function public.reclamar_sincronizaciones_google(integer)
  from public, anon, authenticated;
grant execute on function public.reclamar_sincronizaciones_google(integer) to service_role;

drop function if exists public.reclamar_sincronizaciones_manuales(uuid, uuid[]);
create function public.reclamar_sincronizaciones_manuales(
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
  sincronizacion_inicial_completa boolean,
  gmail_reconciliacion_desde date,
  gmail_reconciliacion_page_token text,
  gmail_ultima_reconciliacion_en timestamptz
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
      and (coalesce(cardinality(p_conexion_ids), 0) = 0 or c.id = any(p_conexion_ids))
      and (c.ultima_solicitud_manual_en is null or c.ultima_solicitud_manual_en <= now() - interval '60 seconds')
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
    a.sincronizacion_inicial_completa,
    a.gmail_reconciliacion_desde,
    a.gmail_reconciliacion_page_token,
    a.gmail_ultima_reconciliacion_en
  from actualizadas a
  order by a.creado_en;
$$;

revoke execute on function public.reclamar_sincronizaciones_manuales(uuid, uuid[])
  from public, anon, authenticated;
grant execute on function public.reclamar_sincronizaciones_manuales(uuid, uuid[])
  to service_role;

create or replace function public.reconciliar_eventos_calendar_pendientes(p_limite integer default 20)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_candidato record;
  v_tarea_id uuid;
  v_total integer := 0;
begin
  for v_candidato in
    select
      e.id as evento_id,
      e.usuario_id,
      c.id as conexion_google_id,
      t.id as tarea_id,
      t.estado as tarea_estado,
      t.intentos as tarea_intentos
    from public.eventos_calendar e
    join public.conexiones_google c
      on c.usuario_id = e.usuario_id
      and c.es_calendar_principal
      and c.calendar_conectado
      and c.estado_conexion = 'activa'
    left join public.tareas_calendar t on t.evento_id = e.id
    where e.estado_sincronizacion <> 'eliminado'
      and e.fecha_evento >= current_date
      and e.google_event_id is null
      and (
        t.id is null
        or (t.operacion = 'crear' and t.estado = 'completada')
        or (
          t.operacion = 'crear'
          and t.estado = 'error'
          and t.ultimo_error = 'GOOGLE_TEMPORAL'
          and t.intentos < 10
          and t.actualizado_en <= now() - interval '15 minutes'
        )
      )
    order by e.fecha_evento, e.creado_en
    limit least(greatest(p_limite, 1), 20)
    for update of e skip locked
  loop
    update public.eventos_calendar
    set
      conexion_google_id = v_candidato.conexion_google_id,
      estado_google = 'pendiente',
      error_google = null
    where id = v_candidato.evento_id;

    insert into public.tareas_calendar (
      evento_id, usuario_id, operacion, estado, intentos, ultimo_error
    )
    values (v_candidato.evento_id, v_candidato.usuario_id, 'crear', 'pendiente', 0, null)
    on conflict (evento_id) do update
      set
        operacion = 'crear',
        estado = 'pendiente',
        intentos = case
          when public.tareas_calendar.estado = 'error'
            then public.tareas_calendar.intentos
          else 0
        end,
        ultimo_error = null
    returning id into v_tarea_id;

    if not exists (
      select 1
      from pgmq.q_calendar_sync q
      where (q.message->>'tarea_id')::uuid = v_tarea_id
        and coalesce(q.message->>'operacion', 'crear') = 'crear'
    ) then
      perform pgmq.send(
        'calendar_sync',
        jsonb_build_object(
          'tarea_id', v_tarea_id,
          'evento_id', v_candidato.evento_id,
          'usuario_id', v_candidato.usuario_id,
          'operacion', 'crear'
        )
      );
      v_total := v_total + 1;
    end if;
  end loop;
  return v_total;
end
$$;

revoke execute on function public.reconciliar_eventos_calendar_pendientes(integer)
  from public, anon, authenticated;
grant execute on function public.reconciliar_eventos_calendar_pendientes(integer)
  to service_role;

-- Un barrido reciente acotado repara cualquier hueco previo de Gmail.
update public.conexiones_google
set
  gmail_reconciliacion_desde = (current_date - 7),
  gmail_reconciliacion_page_token = null
where gmail_conectado and estado_conexion = 'activa';

-- Los límites anteriores no vuelven a girar indefinidamente. Sólo los últimos
-- siete días reciben un último intento controlado.
update public.tareas_correos_gmail t
set
  estado = case when cp.fecha_correo >= now() - interval '7 days' then 'pendiente' else 'error' end,
  origen_sincronizacion = case when cp.fecha_correo >= now() - interval '7 days' then 'reconciliacion' else 'historica' end,
  intentos_ia = case when cp.fecha_correo >= now() - interval '7 days' then 1 else 2 end,
  disponible_en = case
    when cp.fecha_correo >= now() - interval '7 days'
      then (((now() at time zone 'America/Argentina/Cordoba')::date + 1)
        at time zone 'America/Argentina/Cordoba')
    else t.disponible_en
  end,
  reclamada_en = null
from public.correos_procesados cp
where cp.conexion_google_id = t.conexion_google_id
  and cp.gmail_message_id = t.gmail_message_id
  and t.ultimo_error = 'AI_LIMITE_TEMPORAL'
  and t.estado in ('pendiente', 'procesando', 'error');

update public.tareas_correos_gmail
set estado = 'error', intentos_ia = 2, reclamada_en = null
where ultimo_error = 'AI_RESPUESTA_INVALIDA'
  and estado in ('pendiente', 'procesando');

-- Sin correo asociado o sin fecha reciente, el límite previo queda terminal.
update public.tareas_correos_gmail t
set estado = 'error', intentos_ia = 2, reclamada_en = null
where t.ultimo_error = 'AI_LIMITE_TEMPORAL'
  and t.estado in ('pendiente', 'procesando')
  and not exists (
    select 1
    from public.correos_procesados cp
    where cp.conexion_google_id = t.conexion_google_id
      and cp.gmail_message_id = t.gmail_message_id
      and cp.fecha_correo >= now() - interval '7 days'
  );
