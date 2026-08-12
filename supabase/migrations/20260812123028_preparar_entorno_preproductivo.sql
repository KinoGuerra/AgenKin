-- Corrige la entrega de alertas sin modificar programaciones ni historial.
-- La referencia por nombre evita la ambigüedad con el parámetro de salida
-- usuario_id de la propia función.
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
    on conflict on constraint consumos_mensuales_usuario_id_periodo_key
    do update set
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

-- Amplía el resumen ya consumido por admin-manage-user. Las edades sólo
-- consideran trabajo que el worker puede tomar ahora.
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
    'gmail_pendientes', (
      select count(*)
      from public.tareas_correos_gmail
      where estado = 'pendiente' and disponible_en <= now()
    ),
    'gmail_antiguedad_minutos', (
      select coalesce(floor(extract(epoch from (now() - min(disponible_en))) / 60), 0)
      from public.tareas_correos_gmail
      where estado = 'pendiente' and disponible_en <= now()
    ),
    'calendar_pendientes', (
      select count(*)
      from public.tareas_calendar
      where estado = 'pendiente'
    ),
    'calendar_antiguedad_minutos', (
      select coalesce(floor(extract(epoch from (now() - min(actualizado_en))) / 60), 0)
      from public.tareas_calendar
      where estado = 'pendiente'
    ),
    'conexiones_token_vencido', (
      select count(*)
      from public.conexiones_google
      where estado_conexion = 'token_vencido'
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
