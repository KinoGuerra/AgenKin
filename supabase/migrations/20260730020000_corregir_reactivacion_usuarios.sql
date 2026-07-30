-- Corrige el trigger compartido por perfiles y suscripciones.
-- Cada rama accede únicamente a las columnas disponibles en la tabla que la invoca.
create or replace function private.ajustar_automatizacion_usuario()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  usuario_afectado uuid;
begin
  if tg_relid = 'public.perfiles'::regclass then
    usuario_afectado := new.id;
  elsif tg_relid = 'public.suscripciones'::regclass then
    usuario_afectado := new.usuario_id;
  else
    raise exception 'Tabla no soportada por ajustar_automatizacion_usuario';
  end if;

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

revoke execute on function private.ajustar_automatizacion_usuario()
from public, anon, authenticated;
