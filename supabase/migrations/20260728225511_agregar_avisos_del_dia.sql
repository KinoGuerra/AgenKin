alter table public.vencimientos_detectados
  add column if not exists entidad text,
  add column if not exists monto numeric(14, 2);

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'vencimientos_entidad_longitud_check'
      and conrelid = 'public.vencimientos_detectados'::regclass
  ) then
    alter table public.vencimientos_detectados
      add constraint vencimientos_entidad_longitud_check
      check (entidad is null or char_length(entidad) between 1 and 120);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'vencimientos_monto_no_negativo_check'
      and conrelid = 'public.vencimientos_detectados'::regclass
  ) then
    alter table public.vencimientos_detectados
      add constraint vencimientos_monto_no_negativo_check
      check (monto is null or monto >= 0);
  end if;
end;
$$;

create index if not exists vencimientos_usuario_fecha_activos_idx
  on public.vencimientos_detectados (usuario_id, fecha_vencimiento)
  where estado <> 'descartado'::public.estado_vencimiento;

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
