-- Reduce la superficie RPC pública, optimiza RLS y completa índices de claves foráneas.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

create or replace function private.usuario_habilitado()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.perfiles p
    join public.suscripciones s on s.usuario_id = p.id
    where p.id = (select auth.uid())
      and p.estado_acceso = 'activo'
      and s.estado in ('prueba', 'activa')
      and s.fecha_vencimiento >= now()
  );
$$;

create or replace function private.registrar_ultimo_acceso()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.perfiles
  set ultimo_acceso = now()
  where id = (select auth.uid());
$$;

create or replace function private.obtener_panel_usuario()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'correos_procesados', coalesce(c.correos_procesados, 0),
    'eventos_creados', coalesce(c.eventos_creados, 0),
    'vencimientos_detectados', (
      select count(*)
      from public.vencimientos_detectados v
      where v.usuario_id = (select auth.uid())
    ),
    'pendientes_revision', (
      select count(*)
      from public.vencimientos_detectados v
      where v.usuario_id = (select auth.uid()) and v.estado = 'pendiente'
    ),
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
    on c.usuario_id = s.usuario_id
    and c.periodo = date_trunc('month', current_date)::date
  where s.usuario_id = (select auth.uid());
$$;

create or replace function private.obtener_estado_conexion_google()
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
      from public.conexiones_google
      where usuario_id = (select auth.uid())
    ),
    '{"conectado": false, "estado_conexion": "desconectada"}'::jsonb
  );
$$;

revoke execute on function private.usuario_habilitado() from public, anon;
revoke execute on function private.registrar_ultimo_acceso() from public, anon;
revoke execute on function private.obtener_panel_usuario() from public, anon;
revoke execute on function private.obtener_estado_conexion_google() from public, anon;
grant execute on function private.usuario_habilitado() to authenticated;
grant execute on function private.registrar_ultimo_acceso() to authenticated;
grant execute on function private.obtener_panel_usuario() to authenticated;
grant execute on function private.obtener_estado_conexion_google() to authenticated;

create or replace function public.registrar_ultimo_acceso()
returns void
language sql
security invoker
set search_path = ''
as $$
  select private.registrar_ultimo_acceso();
$$;

create or replace function public.obtener_panel_usuario()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select private.obtener_panel_usuario();
$$;

create or replace function public.obtener_estado_conexion_google()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select private.obtener_estado_conexion_google();
$$;

revoke execute on function public.actualizar_marca_temporal() from public, anon, authenticated;
revoke execute on function public.crear_usuario_inicial() from public, anon, authenticated;
revoke execute on function public.es_superadministrador(uuid) from public, anon, authenticated;
revoke execute on function public.usuario_habilitado(uuid) from public, anon, authenticated;
grant execute on function public.es_superadministrador(uuid) to service_role;
grant execute on function public.usuario_habilitado(uuid) to service_role;

revoke execute on function public.registrar_ultimo_acceso() from public, anon;
revoke execute on function public.obtener_panel_usuario() from public, anon;
revoke execute on function public.obtener_estado_conexion_google() from public, anon;
grant execute on function public.registrar_ultimo_acceso() to authenticated;
grant execute on function public.obtener_panel_usuario() to authenticated;
grant execute on function public.obtener_estado_conexion_google() to authenticated;

create index if not exists suscripciones_plan_id_idx
  on public.suscripciones (plan_id);
create index if not exists vencimientos_correo_id_idx
  on public.vencimientos_detectados (correo_id);
create index if not exists auditoria_administrador_id_idx
  on public.auditoria_administrativa (administrador_id);
create index if not exists auditoria_usuario_afectado_id_idx
  on public.auditoria_administrativa (usuario_afectado_id);
create index if not exists oauth_states_usuario_id_idx
  on public.oauth_states (usuario_id);

drop policy if exists "perfil propio visible" on public.perfiles;
create policy "perfil propio visible"
on public.perfiles for select to authenticated
using (id = (select auth.uid()));

drop policy if exists "consumo propio visible" on public.consumos_mensuales;
create policy "consumo propio visible"
on public.consumos_mensuales for select to authenticated
using (usuario_id = (select auth.uid()));

drop policy if exists "correos propios visibles" on public.correos_procesados;
create policy "correos propios visibles"
on public.correos_procesados for select to authenticated
using (usuario_id = (select auth.uid()));

drop policy if exists "vencimientos propios visibles" on public.vencimientos_detectados;
create policy "vencimientos propios visibles"
on public.vencimientos_detectados for select to authenticated
using (usuario_id = (select auth.uid()));

drop policy if exists "vencimientos propios editables" on public.vencimientos_detectados;
create policy "vencimientos propios editables"
on public.vencimientos_detectados for update to authenticated
using (
  usuario_id = (select auth.uid())
  and (select private.usuario_habilitado())
)
with check (
  usuario_id = (select auth.uid())
  and (select private.usuario_habilitado())
);

drop policy if exists "eventos propios visibles" on public.eventos_calendar;
create policy "eventos propios visibles"
on public.eventos_calendar for select to authenticated
using (usuario_id = (select auth.uid()));

drop policy if exists "reglas propias visibles" on public.reglas_usuario;
create policy "reglas propias visibles"
on public.reglas_usuario for select to authenticated
using (usuario_id = (select auth.uid()));

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
