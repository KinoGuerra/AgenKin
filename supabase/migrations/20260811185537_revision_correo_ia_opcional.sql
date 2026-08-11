-- Revisión manual durable y métricas del procesamiento local/IA.

alter table public.correos_procesados
  add column if not exists requiere_revision boolean not null default false,
  add column if not exists motivo_revision text,
  add column if not exists candidatos_revision jsonb,
  add column if not exists duracion_procesamiento_ms integer,
  add column if not exists remitente_autenticado boolean not null default false;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'correos_motivo_revision_check'
      and conrelid = 'public.correos_procesados'::regclass
  ) then
    alter table public.correos_procesados
      add constraint correos_motivo_revision_check
      check (
        motivo_revision is null or motivo_revision in (
          'ia_deshabilitada', 'ia_no_configurada', 'presupuesto_ia_agotado',
          'ia_no_disponible', 'exclusion_aprendida',
          'remitente_no_autenticado', 'clasificacion_ambigua',
          'reintentos_ia_agotados'
        )
      );
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'correos_candidatos_revision_check'
      and conrelid = 'public.correos_procesados'::regclass
  ) then
    alter table public.correos_procesados
      add constraint correos_candidatos_revision_check
      check (
        candidatos_revision is null
        or (
          jsonb_typeof(candidatos_revision) = 'object'
          and octet_length(candidatos_revision::text) <= 8000
        )
      );
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'correos_duracion_procesamiento_check'
      and conrelid = 'public.correos_procesados'::regclass
  ) then
    alter table public.correos_procesados
      add constraint correos_duracion_procesamiento_check
      check (
        duracion_procesamiento_ms is null
        or duracion_procesamiento_ms between 0 and 600000
      );
  end if;
end
$$;

create index if not exists correos_revision_usuario_fecha_idx
  on public.correos_procesados (usuario_id, fecha_correo desc, id desc)
  where requiere_revision and not detalle_compactado;

alter table public.consumos_mensuales
  add column if not exists origen_local integer not null default 0,
  add column if not exists correos_revision integer not null default 0,
  add column if not exists llamadas_ia integer not null default 0,
  add column if not exists reintentos_ia integer not null default 0,
  add column if not exists errores_ia integer not null default 0,
  add column if not exists duracion_procesamiento_ms bigint not null default 0,
  add column if not exists duplicados_evitados integer not null default 0;

create or replace function private.limpiar_revision_al_compactar()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.detalle_compactado and not old.detalle_compactado then
    new.requiere_revision := false;
    new.motivo_revision := null;
    new.candidatos_revision := null;
    new.remitente_autenticado := false;
  end if;
  return new;
end
$$;

revoke execute on function private.limpiar_revision_al_compactar()
  from public, anon, authenticated;

drop trigger if exists correos_limpiar_revision_compactada
  on public.correos_procesados;
create trigger correos_limpiar_revision_compactada
before update of detalle_compactado on public.correos_procesados
for each row execute function private.limpiar_revision_al_compactar();

create or replace function public.correo_tiene_exclusion_agenda(
  p_usuario_id uuid,
  p_dominio text,
  p_huella text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.exclusiones_agenda_usuario x
    where x.usuario_id = p_usuario_id
      and x.dominio_remitente = p_dominio
      and x.huella_plantilla = p_huella
  );
$$;

revoke execute on function public.correo_tiene_exclusion_agenda(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.correo_tiene_exclusion_agenda(uuid, text, text)
  to service_role;

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
  v_requiere_revision boolean := coalesce((p_resultado->>'requiere_revision')::boolean, false);
  v_motivo_revision text := nullif(p_resultado->>'motivo_revision', '');
  v_candidatos_revision jsonb := p_resultado->'candidatos_revision';
  v_duracion integer := least(
    greatest(coalesce(nullif(p_resultado->>'duracion_procesamiento_ms', '')::integer, 0), 0),
    600000
  );
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
      v_requiere_revision and (
        v_estado <> 'procesado'
        or v_motivo_revision not in (
          'ia_deshabilitada', 'ia_no_configurada', 'presupuesto_ia_agotado',
          'ia_no_disponible', 'exclusion_aprendida',
          'remitente_no_autenticado', 'clasificacion_ambigua',
          'reintentos_ia_agotados'
        )
        or v_candidatos_revision is null
        or jsonb_typeof(v_candidatos_revision) <> 'object'
        or octet_length(v_candidatos_revision::text) > 8000
      )
    )
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

  select c.id
  into v_conexion_id
  from public.conexiones_google c
  where c.id = p_conexion_google_id
    and c.usuario_id = p_usuario_id
    and c.gmail_conectado
    and c.estado_conexion = 'activa'
  for share;
  if v_conexion_id is null then return false; end if;

  select * into v_tarea
  from public.tareas_correos_gmail t
  where t.id = p_tarea_id
  for update;
  if v_tarea.id is null
    or v_tarea.estado <> 'procesando'
    or v_tarea.usuario_id <> p_usuario_id
    or v_tarea.conexion_google_id <> p_conexion_google_id then
    return false;
  end if;

  select * into v_correo
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
    requiere_revision = v_requiere_revision,
    motivo_revision = case when v_requiere_revision then v_motivo_revision else null end,
    candidatos_revision = case when v_requiere_revision then v_candidatos_revision else null end,
    duracion_procesamiento_ms = v_duracion,
    remitente_autenticado = coalesce((p_resultado->>'remitente_autenticado')::boolean, false),
    detalle_compactado = false
  where cp.id = p_correo_id;

  if jsonb_typeof(v_vencimiento) = 'object' then
    insert into public.vencimientos_detectados (
      usuario_id, correo_id, tipo, titulo, descripcion, entidad, monto,
      fecha_vencimiento, hora_vencimiento, zona_horaria, confianza,
      explicacion, requiere_revision, huella_funcional
    ) values (
      p_usuario_id,
      p_correo_id,
      left(coalesce(v_vencimiento->>'tipo', 'otro'), 50),
      left(coalesce(v_vencimiento->>'titulo', 'Fecha detectada'), 160),
      left(coalesce(v_vencimiento->>'descripcion', ''), 1000),
      nullif(left(v_vencimiento->>'entidad', 120), ''),
      nullif(v_vencimiento->>'monto', '')::numeric,
      (v_vencimiento->>'fecha')::date,
      nullif(v_vencimiento->>'hora', '')::time,
      coalesce(nullif(v_vencimiento->>'zona_horaria', ''), 'America/Argentina/Cordoba'),
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
    where correo_id = p_correo_id and usuario_id = p_usuario_id;
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

    insert into public.consumos_mensuales (
      usuario_id, periodo, origen_local, correos_revision, llamadas_ia,
      reintentos_ia, errores_ia, duracion_procesamiento_ms, duplicados_evitados
    ) values (
      p_usuario_id,
      date_trunc('month', current_date)::date,
      case when v_origen = 'local' then 1 else 0 end,
      case when v_requiere_revision then 1 else 0 end,
      case when coalesce((p_resultado->>'llamada_ia')::boolean, false) then 1 else 0 end,
      0,
      case when v_motivo_revision in ('ia_no_disponible', 'reintentos_ia_agotados') then 1 else 0 end,
      v_duracion,
      case when (
        select cp.duplicado_funcional
        from public.correos_procesados cp where cp.id = p_correo_id
      ) then 1 else 0 end
    )
    on conflict (usuario_id, periodo) do update set
      origen_local = public.consumos_mensuales.origen_local + excluded.origen_local,
      correos_revision = public.consumos_mensuales.correos_revision + excluded.correos_revision,
      llamadas_ia = public.consumos_mensuales.llamadas_ia + excluded.llamadas_ia,
      reintentos_ia = public.consumos_mensuales.reintentos_ia + excluded.reintentos_ia,
      errores_ia = public.consumos_mensuales.errores_ia + excluded.errores_ia,
      duracion_procesamiento_ms = public.consumos_mensuales.duracion_procesamiento_ms
        + excluded.duracion_procesamiento_ms,
      duplicados_evitados = public.consumos_mensuales.duplicados_evitados
        + excluded.duplicados_evitados,
      actualizado_en = now();

    update public.correos_procesados
    set metricas_registradas_en = now()
    where id = p_correo_id;
  end if;

  update public.tareas_correos_gmail
  set estado = 'completada', intentos = intentos + 1,
      ultimo_error = null, reclamada_en = null
  where id = p_tarea_id;

  return true;
end
$$;

revoke execute on function public.finalizar_correo_analizado(uuid, uuid, uuid, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.finalizar_correo_analizado(uuid, uuid, uuid, uuid, jsonb)
  to service_role;

create or replace function public.registrar_reintento_ia(p_usuario_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.consumos_mensuales (usuario_id, periodo, reintentos_ia)
  values (p_usuario_id, date_trunc('month', current_date)::date, 1)
  on conflict (usuario_id, periodo) do update set
    reintentos_ia = public.consumos_mensuales.reintentos_ia + 1,
    actualizado_en = now();
$$;

revoke execute on function public.registrar_reintento_ia(uuid)
  from public, anon, authenticated;
grant execute on function public.registrar_reintento_ia(uuid)
  to service_role;

create or replace function public.confirmar_revision_correo(
  p_correo_id uuid,
  p_tipo text,
  p_titulo text,
  p_descripcion text,
  p_fecha date,
  p_hora time default null,
  p_entidad text default null,
  p_monto numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario_id uuid := (select auth.uid());
  v_correo public.correos_procesados%rowtype;
  v_vencimiento_id uuid;
  v_evento_id uuid;
  v_fecha_evento timestamptz;
  v_zona text := 'America/Argentina/Cordoba';
  v_google text;
begin
  if v_usuario_id is null then raise exception 'Sesión requerida'; end if;
  if not (select private.usuario_habilitado()) then
    raise exception 'Cuenta o suscripción no habilitada';
  end if;
  if p_tipo not in (
    'vencimiento', 'pago', 'entrega', 'reunion', 'turno', 'renovacion',
    'respuesta', 'documentacion', 'compromiso', 'otro'
  ) then raise exception 'Tipo de compromiso inválido'; end if;
  if char_length(btrim(coalesce(p_titulo, ''))) not between 1 and 160 then
    raise exception 'El título debe tener entre 1 y 160 caracteres';
  end if;
  if char_length(coalesce(p_descripcion, '')) > 1000
    or char_length(coalesce(p_entidad, '')) > 120 then
    raise exception 'El detalle supera el límite permitido';
  end if;
  if p_monto is not null and (p_monto < 0 or p_monto > 999999999999.99) then
    raise exception 'Monto inválido';
  end if;
  if p_fecha is null or p_fecha < (now() at time zone v_zona)::date then
    raise exception 'La fecha del compromiso ya pasó';
  end if;
  v_fecha_evento := (p_fecha + coalesce(p_hora, time '12:00')) at time zone v_zona;
  if p_hora is not null and v_fecha_evento <= now() then
    raise exception 'La fecha y hora del compromiso ya pasaron';
  end if;

  select * into v_correo
  from public.correos_procesados cp
  where cp.id = p_correo_id
    and cp.usuario_id = v_usuario_id
    and cp.requiere_revision
    and not cp.detalle_compactado
  for update;
  if v_correo.id is null then raise exception 'Revisión no encontrada'; end if;

  insert into public.vencimientos_detectados (
    usuario_id, correo_id, tipo, titulo, descripcion, entidad, monto,
    fecha_vencimiento, hora_vencimiento, zona_horaria, confianza,
    explicacion, estado, requiere_revision
  ) values (
    v_usuario_id, v_correo.id, p_tipo, btrim(p_titulo), coalesce(p_descripcion, ''),
    nullif(btrim(coalesce(p_entidad, '')), ''), p_monto, p_fecha, p_hora, v_zona,
    1, 'Compromiso confirmado manualmente por el usuario.', 'pendiente', false
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
    confianza = 1,
    explicacion = excluded.explicacion,
    estado = 'pendiente',
    requiere_revision = false
  returning id into v_vencimiento_id;

  update public.correos_procesados
  set requiere_revision = false,
      motivo_revision = null,
      candidatos_revision = null,
      relevante = true,
      categoria = case
        when p_tipo in ('pago', 'vencimiento') then 'pago'
        when p_tipo in ('turno', 'reunion', 'renovacion', 'entrega', 'respuesta', 'documentacion') then p_tipo
        else 'otro'
      end
  where id = v_correo.id;

  v_evento_id := public.registrar_evento_agenda(
    v_usuario_id, v_vencimiento_id, btrim(p_titulo), coalesce(p_descripcion, ''),
    v_fecha_evento, v_zona, p_hora is null, 1440
  );
  select e.estado_google into v_google
  from public.eventos_calendar e
  where e.id = v_evento_id and e.usuario_id = v_usuario_id;

  return jsonb_build_object(
    'vencimiento_id', v_vencimiento_id,
    'agenda_event_id', v_evento_id,
    'google_estado', v_google
  );
end
$$;

revoke execute on function public.confirmar_revision_correo(
  uuid, text, text, text, date, time, text, numeric
) from public, anon;
grant execute on function public.confirmar_revision_correo(
  uuid, text, text, text, date, time, text, numeric
) to authenticated;

create or replace function public.descartar_revision_correo(p_correo_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_usuario_id uuid := (select auth.uid());
  v_correo public.correos_procesados%rowtype;
begin
  if v_usuario_id is null then raise exception 'Sesión requerida'; end if;
  if not (select private.usuario_habilitado()) then
    raise exception 'Cuenta o suscripción no habilitada';
  end if;

  select * into v_correo
  from public.correos_procesados cp
  where cp.id = p_correo_id and cp.usuario_id = v_usuario_id
  for update;
  if v_correo.id is null then raise exception 'Correo no encontrado'; end if;
  if not v_correo.requiere_revision then return true; end if;

  if v_correo.remitente_autenticado
    and v_correo.dominio_remitente is not null
    and v_correo.huella_plantilla ~ '^[a-f0-9]{64}$' then
    insert into private.exclusiones_agenda_usuario (
      usuario_id, dominio_remitente, huella_plantilla
    ) values (
      v_usuario_id, v_correo.dominio_remitente, v_correo.huella_plantilla
    )
    on conflict (usuario_id, dominio_remitente, huella_plantilla)
    do update set actualizado_en = now();
  end if;

  delete from public.vencimientos_detectados
  where correo_id = v_correo.id
    and usuario_id = v_usuario_id
    and estado in ('pendiente', 'vencido');

  update public.correos_procesados
  set requiere_revision = false,
      motivo_revision = null,
      candidatos_revision = null,
      relevante = false,
      categoria = 'irrelevante',
      grupo_resumen = 'otros',
      estado_procesamiento = 'ignorado',
      error_procesamiento = null
  where id = v_correo.id;
  return true;
end
$$;

revoke execute on function public.descartar_revision_correo(uuid)
  from public, anon;
grant execute on function public.descartar_revision_correo(uuid)
  to authenticated;
