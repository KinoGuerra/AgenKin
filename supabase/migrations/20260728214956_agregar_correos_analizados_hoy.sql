create table if not exists public.solicitudes_mejora_plan (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.perfiles(id) on delete cascade,
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'atendida', 'cancelada')),
  creado_en timestamptz not null default now()
);

create unique index if not exists solicitudes_mejora_plan_pendiente_idx
  on public.solicitudes_mejora_plan (usuario_id)
  where estado = 'pendiente';

alter table public.solicitudes_mejora_plan enable row level security;

drop policy if exists "solicitudes_mejora_propias_select" on public.solicitudes_mejora_plan;
create policy "solicitudes_mejora_propias_select"
on public.solicitudes_mejora_plan
for select
to authenticated
using ((select auth.uid()) = usuario_id);

drop policy if exists "solicitudes_mejora_propias_insert" on public.solicitudes_mejora_plan;
create policy "solicitudes_mejora_propias_insert"
on public.solicitudes_mejora_plan
for insert
to authenticated
with check ((select auth.uid()) = usuario_id and estado = 'pendiente');

revoke all on public.solicitudes_mejora_plan from public, anon;
grant select, insert on public.solicitudes_mejora_plan to authenticated;

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
