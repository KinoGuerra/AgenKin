-- AgenKin es un plan interno gratuito, equivalente a Pro y sin vencimiento.
do $$
begin
  if not exists (select 1 from public.planes where nombre = 'AgenKin') then
    raise exception 'PLAN_AGENKIN_INEXISTENTE';
  end if;
end
$$;

update public.planes
set descripcion = 'Plan interno gratuito, equivalente a Pro y sin vencimiento.',
    precio = 0,
    limite_cuentas_gmail = 3,
    permite_automatizacion = true,
    es_interno = true,
    visible_publico = false,
    activo = true,
    actualizado_en = now()
where nombre = 'AgenKin';

update public.suscripciones s
set fecha_vencimiento = 'infinity'::timestamptz,
    renovacion_automatica = false,
    actualizado_en = now()
from public.planes p
where p.id = s.plan_id
  and p.nombre = 'AgenKin';

create or replace function public.aplicar_accion_administrativa(
  p_administrador_id uuid,
  p_usuario_id uuid,
  p_accion text,
  p_plan_id uuid default null,
  p_fecha_vencimiento timestamptz default null,
  p_observacion text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  antes jsonb;
  despues jsonb;
  v_plan_actual_interno boolean;
  v_plan_destino_interno boolean;
begin
  if not public.es_superadministrador(p_administrador_id) then
    raise exception 'Acceso administrativo denegado';
  end if;
  if p_administrador_id = p_usuario_id
    and p_accion in ('bloquear', 'suspender', 'cancelar_suscripcion') then
    raise exception 'No puede restringir su propia cuenta';
  end if;

  select
    jsonb_build_object(
      'estado_acceso', p.estado_acceso,
      'plan_id', s.plan_id,
      'estado_suscripcion', s.estado,
      'fecha_vencimiento', s.fecha_vencimiento
    ),
    pl.es_interno
  into antes, v_plan_actual_interno
  from public.perfiles p
  join public.suscripciones s on s.usuario_id = p.id
  join public.planes pl on pl.id = s.plan_id
  where p.id = p_usuario_id
  for update of s;
  if antes is null then raise exception 'Usuario no encontrado'; end if;

  case p_accion
    when 'activar' then
      update public.perfiles set estado_acceso = 'activo' where id = p_usuario_id;
    when 'desbloquear' then
      update public.perfiles set estado_acceso = 'activo' where id = p_usuario_id;
    when 'suspender' then
      update public.perfiles set estado_acceso = 'suspendido' where id = p_usuario_id;
    when 'bloquear' then
      update public.perfiles set estado_acceso = 'bloqueado' where id = p_usuario_id;
    when 'cambiar_plan' then
      select es_interno
      into v_plan_destino_interno
      from public.planes
      where id = p_plan_id and activo;
      if not found then raise exception 'Plan inválido'; end if;
      if v_plan_actual_interno
        and not v_plan_destino_interno
        and (p_fecha_vencimiento is null or p_fecha_vencimiento <= now()) then
        raise exception 'Definí un vencimiento futuro al salir del plan AgenKin';
      end if;
      if not v_plan_destino_interno
        and p_fecha_vencimiento is not null
        and p_fecha_vencimiento <= now() then
        raise exception 'Fecha inválida';
      end if;
      update public.suscripciones
      set plan_id = p_plan_id,
          estado = 'activa',
          fecha_vencimiento = case
            when v_plan_destino_interno then 'infinity'::timestamptz
            when p_fecha_vencimiento is not null then p_fecha_vencimiento
            else fecha_vencimiento
          end,
          renovacion_automatica = case
            when v_plan_destino_interno then false
            else renovacion_automatica
          end
      where usuario_id = p_usuario_id;
    when 'extender_prueba' then
      if v_plan_actual_interno then
        raise exception 'El plan AgenKin no tiene vencimiento';
      end if;
      if p_fecha_vencimiento is null or p_fecha_vencimiento <= now() then
        raise exception 'Fecha inválida';
      end if;
      update public.suscripciones
      set fecha_vencimiento = p_fecha_vencimiento, estado = 'prueba'
      where usuario_id = p_usuario_id;
    when 'cambiar_vencimiento' then
      if v_plan_actual_interno then
        raise exception 'El plan AgenKin no tiene vencimiento';
      end if;
      if p_fecha_vencimiento is null then raise exception 'Fecha inválida'; end if;
      update public.suscripciones
      set fecha_vencimiento = p_fecha_vencimiento
      where usuario_id = p_usuario_id;
    when 'cancelar_suscripcion' then
      update public.suscripciones
      set estado = 'cancelada', renovacion_automatica = false
      where usuario_id = p_usuario_id;
    when 'registrar_observacion' then
      update public.suscripciones
      set observaciones_internas = left(coalesce(p_observacion, ''), 1000)
      where usuario_id = p_usuario_id;
    else
      raise exception 'Acción no permitida';
  end case;

  select jsonb_build_object(
    'estado_acceso', p.estado_acceso,
    'plan_id', s.plan_id,
    'estado_suscripcion', s.estado,
    'fecha_vencimiento', s.fecha_vencimiento
  ) into despues
  from public.perfiles p
  join public.suscripciones s on s.usuario_id = p.id
  where p.id = p_usuario_id;

  insert into public.auditoria_administrativa (
    administrador_id, usuario_afectado_id, accion, detalle,
    datos_anteriores, datos_nuevos
  ) values (
    p_administrador_id, p_usuario_id, p_accion,
    left(p_observacion, 1000), antes, despues
  );
end
$$;

revoke execute on function public.aplicar_accion_administrativa(
  uuid, uuid, text, uuid, timestamptz, text
) from public, anon, authenticated;
grant execute on function public.aplicar_accion_administrativa(
  uuid, uuid, text, uuid, timestamptz, text
) to service_role;
