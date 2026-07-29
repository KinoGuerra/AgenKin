-- Endurecimiento integral de autorización, planes y automatización.

create or replace function private.usuario_con_acceso()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.perfiles p
    where p.id = (select auth.uid())
      and p.estado_acceso = 'activo'
  );
$$;

revoke execute on function private.usuario_con_acceso() from public, anon;
grant execute on function private.usuario_con_acceso() to authenticated, service_role;

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
    'correos_analizados_total', count(cp.id),
    'correos_analizados_hoy', count(cp.id) filter (
      where cp.fecha_procesamiento >= (
        (now() at time zone 'America/Argentina/Cordoba')::date
          at time zone 'America/Argentina/Cordoba'
      )
      and cp.fecha_procesamiento < (
        ((now() at time zone 'America/Argentina/Cordoba')::date + 1)
          at time zone 'America/Argentina/Cordoba'
      )
    ),
    'categorias_resumen', jsonb_build_object(
      'tarjetas', count(*) filter (where cp.grupo_resumen = 'tarjetas'),
      'servicios', count(*) filter (where cp.grupo_resumen = 'servicios'),
      'suscripciones', count(*) filter (where cp.grupo_resumen = 'suscripciones'),
      'turnos', count(*) filter (where cp.grupo_resumen = 'turnos'),
      'otros', count(*) filter (where cp.grupo_resumen = 'otros')
    ),
    'avisos_del_dia', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', v.id,
          'grupo_resumen', coalesce(correo_avisos.grupo_resumen, 'otros'),
          'entidad', v.entidad,
          'monto', v.monto,
          'titulo', v.titulo,
          'estado', v.estado
        )
        order by v.hora_vencimiento asc nulls last, v.creado_en asc
      )
      from public.vencimientos_detectados v
      left join public.correos_procesados correo_avisos
        on correo_avisos.id = v.correo_id
        and correo_avisos.usuario_id = v.usuario_id
      where v.usuario_id = (select auth.uid())
        and v.fecha_vencimiento = (now() at time zone 'America/Argentina/Cordoba')::date
        and v.estado <> 'descartado'
    ), '[]'::jsonb),
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
      'permite_automatizacion', pl.permite_automatizacion,
      'correos_mes', coalesce(cm.correos_procesados, 0),
      'solicitud_mejora_pendiente', exists (
        select 1
        from public.solicitudes_mejora_plan smp
        where smp.usuario_id = (select auth.uid()) and smp.estado = 'pendiente'
      )
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

revoke execute on function private.obtener_panel_usuario() from public, anon;
grant execute on function private.obtener_panel_usuario() to authenticated;

drop policy if exists "consumo propio visible" on public.consumos_mensuales;
create policy "consumo propio visible"
on public.consumos_mensuales for select to authenticated
using (
  usuario_id = (select auth.uid())
  and (select private.usuario_con_acceso())
);

drop policy if exists "correos propios visibles" on public.correos_procesados;
create policy "correos propios visibles"
on public.correos_procesados for select to authenticated
using (
  usuario_id = (select auth.uid())
  and (select private.usuario_con_acceso())
);

drop policy if exists "vencimientos propios visibles" on public.vencimientos_detectados;
create policy "vencimientos propios visibles"
on public.vencimientos_detectados for select to authenticated
using (
  usuario_id = (select auth.uid())
  and (select private.usuario_con_acceso())
);

drop policy if exists "eventos propios visibles" on public.eventos_calendar;
create policy "eventos propios visibles"
on public.eventos_calendar for select to authenticated
using (
  usuario_id = (select auth.uid())
  and (select private.usuario_con_acceso())
);

drop policy if exists "reglas propias visibles" on public.reglas_usuario;
create policy "reglas propias visibles"
on public.reglas_usuario for select to authenticated
using (
  usuario_id = (select auth.uid())
  and (select private.usuario_con_acceso())
);

drop policy if exists "reglas propias creadas" on public.reglas_usuario;
create policy "reglas propias creadas"
on public.reglas_usuario for insert to authenticated
with check (
  usuario_id = (select auth.uid())
  and (select private.usuario_habilitado())
);

drop policy if exists "reglas propias editables" on public.reglas_usuario;
create policy "reglas propias editables"
on public.reglas_usuario for update to authenticated
using (
  usuario_id = (select auth.uid())
  and (select private.usuario_habilitado())
)
with check (
  usuario_id = (select auth.uid())
  and (select private.usuario_habilitado())
);

drop policy if exists "reglas propias eliminables" on public.reglas_usuario;
create policy "reglas propias eliminables"
on public.reglas_usuario for delete to authenticated
using (
  usuario_id = (select auth.uid())
  and (select private.usuario_habilitado())
);

drop policy if exists "solicitudes_mejora_propias_select" on public.solicitudes_mejora_plan;
create policy "solicitudes_mejora_propias_select"
on public.solicitudes_mejora_plan for select to authenticated
using (
  usuario_id = (select auth.uid())
  and (select private.usuario_con_acceso())
);

drop policy if exists "solicitudes_mejora_propias_insert" on public.solicitudes_mejora_plan;
create policy "solicitudes_mejora_propias_insert"
on public.solicitudes_mejora_plan for insert to authenticated
with check (
  usuario_id = (select auth.uid())
  and estado = 'pendiente'
  and (select private.usuario_habilitado())
);

create or replace function public.registrar_ultimo_acceso()
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if not (select private.usuario_con_acceso()) then
    raise exception 'Cuenta sin acceso';
  end if;
  perform private.registrar_ultimo_acceso();
end
$$;

create or replace function public.obtener_panel_usuario()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select case
    when (select private.usuario_con_acceso()) then private.obtener_panel_usuario()
    else null
  end;
$$;

create or replace function public.obtener_estado_conexion_google()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select case
    when (select private.usuario_con_acceso()) then private.obtener_estado_conexion_google()
    else null
  end;
$$;

create or replace function private.actualizar_grupo_correo(
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
  if not (select private.usuario_habilitado()) then
    raise exception 'Cuenta o suscripción no habilitada';
  end if;
  if grupo not in ('tarjetas', 'servicios', 'suscripciones', 'turnos', 'otros') then
    raise exception 'Categoría inválida';
  end if;

  update public.correos_procesados
  set grupo_resumen = grupo, grupo_asignado_por = 'usuario'
  where id = correo_id
    and usuario_id = (select auth.uid());
  if not found then
    raise exception 'Correo no encontrado';
  end if;
end
$$;

revoke execute on function private.actualizar_grupo_correo(uuid, text) from public, anon;
grant execute on function private.actualizar_grupo_correo(uuid, text) to authenticated;

create or replace function public.actualizar_grupo_correo(
  correo_id uuid,
  grupo text
)
returns void
language sql
security invoker
set search_path = ''
as $$
  select private.actualizar_grupo_correo(correo_id, grupo);
$$;

revoke execute on function public.actualizar_grupo_correo(uuid, text) from public, anon;
grant execute on function public.actualizar_grupo_correo(uuid, text) to authenticated;

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
  resultado jsonb;
  solicita_automatizacion boolean :=
    p_sincronizacion_automatica or p_creacion_automatica_eventos;
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
  if solicita_automatizacion and not exists (
    select 1
    from public.suscripciones s
    join public.planes p on p.id = s.plan_id
    where s.usuario_id = (select auth.uid())
      and s.estado in ('prueba', 'activa')
      and s.fecha_vencimiento >= now()
      and p.activo
      and p.permite_automatizacion
  ) then
    raise exception 'Tu plan no incluye automatización';
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
    and gmail_conectado
  returning jsonb_build_object(
    'sincronizacion_automatica', sincronizacion_automatica,
    'creacion_automatica_eventos', creacion_automatica_eventos,
    'umbral_confianza_automatica', umbral_confianza_automatica
  ) into resultado;

  if resultado is null then
    raise exception 'Conectá Gmail antes de configurar la automatización';
  end if;
  return resultado;
end
$$;

revoke execute on function private.configurar_automatizacion_google(boolean, boolean, numeric)
  from public, anon;
grant execute on function private.configurar_automatizacion_google(boolean, boolean, numeric)
  to authenticated;

create or replace function public.configurar_automatizacion_google(
  p_sincronizacion_automatica boolean,
  p_creacion_automatica_eventos boolean,
  p_umbral_confianza numeric default 0.900
)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select private.configurar_automatizacion_google(
    p_sincronizacion_automatica,
    p_creacion_automatica_eventos,
    p_umbral_confianza
  );
$$;

revoke execute on function public.configurar_automatizacion_google(boolean, boolean, numeric)
  from public, anon;
grant execute on function public.configurar_automatizacion_google(boolean, boolean, numeric)
  to authenticated;

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
      and pl.permite_automatizacion
    order by c.proxima_sincronizacion nulls first, c.actualizado_en
    limit least(greatest(p_limite, 1), 10)
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
  join public.correos_procesados cp on cp.id = v.correo_id
  join public.conexiones_google c on c.usuario_id = v.usuario_id
  join public.perfiles pe on pe.id = v.usuario_id
  join public.suscripciones s on s.usuario_id = v.usuario_id
  join public.planes pl on pl.id = s.plan_id
  where c.estado_conexion = 'activa'
    and c.creacion_automatica_eventos
    and v.estado = 'pendiente'
    and not v.requiere_revision
    and v.confianza >= c.umbral_confianza_automatica
    and v.fecha_vencimiento >= (now() at time zone v.zona_horaria)::date
    and pe.estado_acceso = 'activo'
    and s.estado in ('prueba', 'activa')
    and s.fecha_vencimiento >= now()
    and pl.activo
    and pl.permite_automatizacion
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
    and (
      select count(*)
      from public.eventos_calendar e
      where e.usuario_id = v.usuario_id
        and e.creado_en >= date_trunc('day', now())
    ) < 20
    and not exists (
      select 1
      from public.eventos_calendar e
      where e.vencimiento_id = v.id
    )
  order by v.fecha_vencimiento, v.creado_en
  limit least(greatest(p_limite, 1), 20);
$$;

create or replace function private.ajustar_automatizacion_usuario()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  usuario_afectado uuid;
begin
  usuario_afectado := case
    when tg_table_name = 'perfiles' then new.id
    else new.usuario_id
  end;

  if not exists (
    select 1
    from public.perfiles pe
    join public.suscripciones s on s.usuario_id = pe.id
    join public.planes pl on pl.id = s.plan_id
    where pe.id = usuario_afectado
      and pe.estado_acceso = 'activo'
      and s.estado in ('prueba', 'activa')
      and s.fecha_vencimiento >= now()
      and pl.activo
      and pl.permite_automatizacion
  ) then
    update public.conexiones_google
    set
      sincronizacion_automatica = false,
      creacion_automatica_eventos = false,
      proxima_sincronizacion = null
    where usuario_id = usuario_afectado;
  end if;
  return new;
end
$$;

revoke execute on function private.ajustar_automatizacion_usuario() from public, anon, authenticated;

drop trigger if exists perfiles_ajustar_automatizacion on public.perfiles;
create trigger perfiles_ajustar_automatizacion
after update of estado_acceso on public.perfiles
for each row execute function private.ajustar_automatizacion_usuario();

drop trigger if exists suscripciones_ajustar_automatizacion on public.suscripciones;
create trigger suscripciones_ajustar_automatizacion
after update of plan_id, estado, fecha_vencimiento on public.suscripciones
for each row execute function private.ajustar_automatizacion_usuario();

create or replace function private.ajustar_automatizacion_plan()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not new.activo or not new.permite_automatizacion then
    update public.conexiones_google c
    set
      sincronizacion_automatica = false,
      creacion_automatica_eventos = false,
      proxima_sincronizacion = null
    where exists (
      select 1
      from public.suscripciones s
      where s.usuario_id = c.usuario_id
        and s.plan_id = new.id
    );
  end if;
  return new;
end
$$;

revoke execute on function private.ajustar_automatizacion_plan() from public, anon, authenticated;

drop trigger if exists planes_ajustar_automatizacion on public.planes;
create trigger planes_ajustar_automatizacion
after update of activo, permite_automatizacion on public.planes
for each row execute function private.ajustar_automatizacion_plan();

update public.conexiones_google c
set
  sincronizacion_automatica = false,
  creacion_automatica_eventos = false,
  proxima_sincronizacion = null
where not exists (
  select 1
  from public.perfiles pe
  join public.suscripciones s on s.usuario_id = pe.id
  join public.planes pl on pl.id = s.plan_id
  where pe.id = c.usuario_id
    and pe.estado_acceso = 'activo'
    and s.estado in ('prueba', 'activa')
    and s.fecha_vencimiento >= now()
    and pl.activo
    and pl.permite_automatizacion
);

delete from public.oauth_states
where vence_en < now()
   or usado_en is not null;

create unique index if not exists oauth_states_usuario_servicio_pendiente_idx
  on public.oauth_states (usuario_id, servicio)
  where usado_en is null;

do $$
declare
  trabajo record;
begin
  for trabajo in
    select jobid from cron.job where jobname = 'agenkin-limpiar-oauth-states'
  loop
    perform cron.unschedule(trabajo.jobid);
  end loop;

  perform cron.schedule(
    'agenkin-limpiar-oauth-states',
    '17 3 * * *',
    $tarea$
      delete from public.oauth_states
      where vence_en < now() - interval '1 day'
         or usado_en < now() - interval '1 day';
    $tarea$
  );
end
$$;
