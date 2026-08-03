-- Mejora incremental del análisis: conserva contratos existentes y hace que
-- la base siga siendo la autoridad para cupos, deduplicación y fechas válidas.

-- Los únicos cupos comerciales efectivos son 1, 2, 3 o 5 Gmail activas.
alter table public.planes
  drop constraint if exists planes_limite_cuentas_gmail_check;
update public.planes
set limite_cuentas_gmail = case
  when limite_cuentas_gmail <= 1 then 1
  when limite_cuentas_gmail = 2 then 2
  when limite_cuentas_gmail = 3 then 3
  else 5
end
where limite_cuentas_gmail not in (1, 2, 3, 5);
alter table public.planes
  add constraint planes_limite_cuentas_gmail_check
  check (limite_cuentas_gmail in (1, 2, 3, 5));

-- Trazabilidad de análisis local y deduplicación funcional.
alter table public.correos_procesados
  add column if not exists huella_funcional text,
  add column if not exists duplicado_funcional boolean not null default false;
alter table public.vencimientos_detectados
  add column if not exists huella_funcional text;

alter table public.correos_procesados
  drop constraint if exists correos_procesados_origen_analisis_check;
alter table public.correos_procesados
  add constraint correos_procesados_origen_analisis_check
  check (origen_analisis in (
    'regla', 'patron_personal', 'patron_global', 'local', 'ia', 'migracion'
  ));

alter table public.correos_procesados
  drop constraint if exists correos_procesados_grupo_asignado_por_check;
alter table public.correos_procesados
  add constraint correos_procesados_grupo_asignado_por_check
  check (grupo_asignado_por in ('ia', 'usuario', 'local', 'migracion'));

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'correos_huella_funcional_check'
      and conrelid = 'public.correos_procesados'::regclass
  ) then
    alter table public.correos_procesados
      add constraint correos_huella_funcional_check
      check (huella_funcional is null or huella_funcional ~ '^[a-f0-9]{64}$');
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'vencimientos_huella_funcional_check'
      and conrelid = 'public.vencimientos_detectados'::regclass
  ) then
    alter table public.vencimientos_detectados
      add constraint vencimientos_huella_funcional_check
      check (huella_funcional is null or huella_funcional ~ '^[a-f0-9]{64}$');
  end if;
end
$$;

create index if not exists vencimientos_huella_funcional_reciente_idx
  on public.vencimientos_detectados (usuario_id, huella_funcional, creado_en desc)
  where huella_funcional is not null;

-- La huella calculada por el worker se valida dentro de la transacción y un
-- advisory lock evita que dos cuentas creen el mismo compromiso simultáneamente.
create or replace function private.deduplicar_vencimiento_funcional()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existente uuid;
begin
  if new.huella_funcional is null then
    return new;
  end if;
  if exists (
    select 1 from public.vencimientos_detectados v
    where v.correo_id = new.correo_id
      and v.usuario_id = new.usuario_id
  ) then
    return new;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(new.usuario_id::text || new.huella_funcional, 0));
  select v.id into v_existente
  from public.vencimientos_detectados v
  where v.usuario_id = new.usuario_id
    and v.huella_funcional = new.huella_funcional
    and v.creado_en >= now() - interval '120 days'
    and v.correo_id <> new.correo_id
  order by v.creado_en desc
  limit 1;

  update public.correos_procesados
  set
    huella_funcional = new.huella_funcional,
    duplicado_funcional = v_existente is not null
  where id = new.correo_id
    and usuario_id = new.usuario_id;

  if v_existente is not null then
    return null;
  end if;
  return new;
end
$$;

revoke execute on function private.deduplicar_vencimiento_funcional()
  from public, anon, authenticated;

drop trigger if exists vencimientos_deduplicar_funcional
  on public.vencimientos_detectados;
create trigger vencimientos_deduplicar_funcional
before insert on public.vencimientos_detectados
for each row execute function private.deduplicar_vencimiento_funcional();

-- Validación adaptativa y auditable de patrones.
alter table public.patrones_correo
  add column if not exists ultima_validacion_en timestamptz,
  add column if not exists ultima_discrepancia_en timestamptz,
  add column if not exists nivel_confianza numeric(5,4) not null default 0
    check (nivel_confianza between 0 and 1);

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
    ultima_validacion_en = now(),
    ultima_discrepancia_en = case when p_coincide then ultima_discrepancia_en else now() end,
    nivel_confianza = (coincidencias + case when p_coincide then 1 else 0 end)::numeric
      / greatest(validaciones_sombra + 1, 1),
    estado = case
      when not p_coincide and discrepancias + 1 >= 3 then 'pausado'
      when not p_coincide then 'observacion'
      else estado
    end,
    ultimo_uso_en = now()
  where id = p_patron_id;
end
$$;

revoke execute on function public.registrar_validacion_patron(uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.registrar_validacion_patron(uuid, boolean)
  to service_role;

-- Una fecha de hoy sin hora sigue vigente; una hora ya transcurrida no.
create or replace function private.marcar_vencimiento_vencido()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.estado in ('pendiente', 'confirmado') and (
    new.fecha_vencimiento < (now() at time zone 'America/Argentina/Cordoba')::date
    or (
      new.hora_vencimiento is not null
      and (new.fecha_vencimiento + new.hora_vencimiento)
        at time zone 'America/Argentina/Cordoba' <= now()
    )
  ) then
    new.estado := 'vencido';
    new.actualizado_en := now();
  end if;
  return new;
end
$$;

revoke execute on function private.marcar_vencimiento_vencido()
  from public, anon, authenticated;

drop trigger if exists vencimientos_marcar_fecha_pasada
  on public.vencimientos_detectados;
create trigger vencimientos_marcar_fecha_pasada
before insert or update of fecha_vencimiento, hora_vencimiento, estado
on public.vencimientos_detectados
for each row execute function private.marcar_vencimiento_vencido();

create or replace function private.validar_evento_agenda_futuro()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.estado_sincronizacion <> 'eliminado' and (
    (new.es_dia_completo and (new.fecha_evento at time zone new.zona_horaria)::date
      < (now() at time zone new.zona_horaria)::date)
    or (not new.es_dia_completo and new.fecha_evento <= now())
  ) then
    raise exception 'EVENTO_AGENDA_PASADO';
  end if;
  return new;
end
$$;

revoke execute on function private.validar_evento_agenda_futuro()
  from public, anon, authenticated;

drop trigger if exists eventos_calendar_validar_futuro on public.eventos_calendar;
create trigger eventos_calendar_validar_futuro
before insert or update of fecha_evento, estado_sincronizacion
on public.eventos_calendar
for each row execute function private.validar_evento_agenda_futuro();

-- Contratos existentes ampliados de forma compatible con el origen local.
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
  if p_origen not in ('regla', 'patron_personal', 'patron_global', 'local', 'ia', 'migracion') then
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
    or v_origen not in ('regla', 'patron_personal', 'patron_global', 'local', 'ia', 'migracion')
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
      when p_resultado->>'grupo_asignado_por' in ('ia', 'migracion', 'local', 'usuario')
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
    huella_funcional = nullif(left(p_resultado->>'huella_funcional', 64), ''),
    duplicado_funcional = false,
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
      requiere_revision,
      huella_funcional
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
      coalesce((v_vencimiento->>'requiere_revision')::boolean, true),
      nullif(p_resultado->>'huella_funcional', '')
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
      requiere_revision = excluded.requiere_revision,
      huella_funcional = excluded.huella_funcional;
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

-- La salud muestra también conexiones Gmail degradadas y el estado de Calendar.
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
        where c.gmail_conectado
      ), '[]'::jsonb)
    ),
    'calendar', jsonb_build_object(
      'conexion_id', (select id from calendar),
      'email', (select google_email from calendar),
      'conectado', exists (select 1 from calendar),
      'ultima_sincronizacion_en', (
        select calendar_ultima_sincronizacion_en from calendar
      ),
      'eventos_pendientes', (
        select count(*) from public.eventos_calendar e
        where e.usuario_id = (select auth.uid())
          and e.estado_google = 'pendiente'
          and e.estado_sincronizacion <> 'eliminado'
      ),
      'eventos_error', (
        select count(*) from public.eventos_calendar e
        where e.usuario_id = (select auth.uid())
          and e.estado_google = 'error'
          and e.estado_sincronizacion <> 'eliminado'
      ),
      'ultimo_evento_sincronizado_en', (
        select max(e.google_sincronizado_en) from public.eventos_calendar e
        where e.usuario_id = (select auth.uid())
          and e.estado_google = 'sincronizado'
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
