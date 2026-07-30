-- Puerta de publicación: falla si el esquema remoto no conserva los
-- invariantes de seguridad, aislamiento y operación multicuenta.

do $$
declare
  relacion regclass;
  rol name;
  privilegio text;
  tarea record;
begin
  foreach relacion in array array[
    'public.perfiles'::regclass,
    'public.planes'::regclass,
    'public.suscripciones'::regclass,
    'public.conexiones_google'::regclass,
    'public.correos_procesados'::regclass,
    'public.vencimientos_detectados'::regclass,
    'public.eventos_calendar'::regclass,
    'public.reglas_usuario'::regclass,
    'public.solicitudes_mejora_plan'::regclass,
    'public.tareas_correos_gmail'::regclass,
    'public.tareas_calendar'::regclass,
    'public.oauth_states'::regclass,
    'public.patrones_correo'::regclass,
    'public.consumos_mensuales'::regclass,
    'public.auditoria_administrativa'::regclass
  ]
  loop
    if not (
      select c.relrowsecurity
      from pg_class c
      where c.oid = relacion
    ) then
      raise exception 'RLS desactivada en %', relacion;
    end if;

    foreach rol in array array['anon'::name, 'authenticated'::name]
    loop
      foreach privilegio in array array[
        'TRUNCATE', 'REFERENCES', 'TRIGGER'
      ]
      loop
        if has_table_privilege(rol, relacion, privilegio) then
          raise exception 'Privilegio % inesperado para % en %',
            privilegio, rol, relacion;
        end if;
      end loop;
    end loop;

    foreach privilegio in array array[
      'SELECT', 'INSERT', 'UPDATE', 'DELETE'
    ]
    loop
      if has_table_privilege('anon', relacion, privilegio) then
        raise exception 'Privilegio % inesperado para anon en %',
          privilegio, relacion;
      end if;
    end loop;

    if has_table_privilege('authenticated', relacion, 'UPDATE') then
      raise exception 'UPDATE directo inesperado para authenticated en %',
        relacion;
    end if;
  end loop;

  if exists (
    select 1
    from pg_class secuencia
    join pg_namespace esquema on esquema.oid = secuencia.relnamespace
    where esquema.nspname = 'public'
      and secuencia.relkind = 'S'
      and (
        has_sequence_privilege('anon', secuencia.oid, 'USAGE')
        or has_sequence_privilege('authenticated', secuencia.oid, 'USAGE')
      )
  ) then
    raise exception 'Una secuencia pública quedó expuesta a roles de usuario';
  end if;

  if exists (
    select 1
    from pg_proc funcion
    join pg_namespace esquema on esquema.oid = funcion.pronamespace
    where esquema.nspname = 'public'
      and has_function_privilege('anon', funcion.oid, 'EXECUTE')
  ) then
    raise exception 'Una función pública quedó expuesta a anon';
  end if;

  if exists (
    select 1
    from pg_proc funcion
    join pg_namespace esquema on esquema.oid = funcion.pronamespace
    where esquema.nspname = 'public'
      and has_function_privilege('authenticated', funcion.oid, 'EXECUTE')
      and funcion.proname not in (
        'registrar_ultimo_acceso',
        'obtener_panel_usuario',
        'obtener_estado_conexion_google',
        'configurar_automatizacion_google',
        'actualizar_grupo_correo',
        'descartar_vencimiento'
      )
  ) then
    raise exception 'Una función pública no autorizada quedó expuesta a authenticated';
  end if;

  if exists (
    select 1
    from public.conexiones_google conexion
    where (conexion.refresh_token_cifrado is null)
      <> (conexion.token_iv is null)
  ) then
    raise exception 'Hay tokens OAuth incompletos';
  end if;

  if exists (
    select 1
    from public.conexiones_google conexion
    where conexion.gmail_conectado
      and conexion.estado_conexion = 'activa'
      and (
        conexion.refresh_token_cifrado is null
        or conexion.token_iv is null
        or nullif(conexion.google_subject_id, '') is null
      )
  ) then
    raise exception 'Hay conexiones Gmail activas sin identidad o token completo';
  end if;

  if exists (
    select 1
    from public.suscripciones suscripcion
    join public.planes plan on plan.id = suscripcion.plan_id
    left join lateral (
      select count(*)::integer as total
      from public.conexiones_google conexion
      where conexion.usuario_id = suscripcion.usuario_id
        and conexion.gmail_conectado
        and conexion.estado_conexion = 'activa'
    ) cuentas on true
    where cuentas.total > plan.limite_cuentas_gmail
  ) then
    raise exception 'Un usuario supera el cupo de cuentas Gmail de su plan';
  end if;

  if exists (
    select 1
    from public.correos_procesados correo
    join public.conexiones_google conexion
      on conexion.id = correo.conexion_google_id
    where conexion.usuario_id <> correo.usuario_id
  ) or exists (
    select 1
    from public.tareas_correos_gmail tarea_gmail
    join public.conexiones_google conexion
      on conexion.id = tarea_gmail.conexion_google_id
    where conexion.usuario_id <> tarea_gmail.usuario_id
  ) or exists (
    select 1
    from public.vencimientos_detectados vencimiento
    join public.correos_procesados correo
      on correo.id = vencimiento.correo_id
    where correo.usuario_id <> vencimiento.usuario_id
  ) or exists (
    select 1
    from public.tareas_calendar tarea_calendar
    join public.eventos_calendar evento
      on evento.id = tarea_calendar.evento_id
    where evento.usuario_id <> tarea_calendar.usuario_id
  ) then
    raise exception 'Se detectaron asociaciones cruzadas entre usuarios';
  end if;

  for tarea in
    select *
    from (
      values
        ('agenkin-descubrir-gmail', '*/5 * * * *', '/functions/v1/sync-gmail-scheduled'),
        ('agenkin-procesar-gmail', '* * * * *', '/functions/v1/process-gmail-queue'),
        ('agenkin-crear-eventos', '*/2 * * * *', '/functions/v1/create-calendar-scheduled'),
        ('agenkin-procesar-calendar', '* * * * *', '/functions/v1/process-calendar-queue'),
        ('agenkin-mantenimiento-diario', '43 3 * * *', 'private.ejecutar_mantenimiento_agenkin')
    ) as esperada(nombre, frecuencia, destino)
  loop
    if (
      select count(*)
      from cron.job trabajo
      where trabajo.jobname = tarea.nombre
        and trabajo.schedule = tarea.frecuencia
        and trabajo.command like '%' || tarea.destino || '%'
    ) <> 1 then
      raise exception 'Cron ausente o duplicado: %', tarea.nombre;
    end if;
  end loop;

  if exists (
    select 1
    from cron.job trabajo
    where trabajo.jobname = 'agenkin-limpiar-oauth-states'
  ) then
    raise exception 'El cron OAuth legado continúa activo';
  end if;
end
$$;
