-- Los importes comerciales se administran y persisten únicamente en pesos.
update public.planes
set moneda = 'ARS',
    actualizado_en = now()
where btrim(moneda) <> 'ARS';

alter table public.planes
add constraint planes_moneda_ars_check
check (btrim(moneda) = 'ARS');

create or replace function public.actualizar_catalogo_precios(
  p_administrador_id uuid,
  p_precios jsonb
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_cantidad integer;
  v_distintos integer;
  v_antes jsonb;
  v_despues jsonb;
begin
  if not public.es_superadministrador(p_administrador_id) then
    raise exception 'Acceso administrativo denegado';
  end if;

  if p_precios is null or jsonb_typeof(p_precios) <> 'array'
    or jsonb_array_length(p_precios) not between 1 and 10 then
    raise exception 'Catálogo de precios inválido';
  end if;

  select count(*)::integer, count(distinct datos.id)::integer
  into v_cantidad, v_distintos
  from jsonb_to_recordset(p_precios) as datos(id uuid, precio numeric);

  if v_cantidad <> v_distintos then
    raise exception 'Hay planes repetidos';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_precios) as datos(id uuid, precio numeric)
    left join public.planes p on p.id = datos.id
    where p.id is null
      or not p.activo
      or not p.visible_publico
      or p.es_interno
      or datos.precio is null
      or datos.precio < 0
      or datos.precio > 9999999999.99
  ) then
    raise exception 'Precio o plan inválido';
  end if;

  select jsonb_agg(
    jsonb_build_object(
      'plan_id', p.id,
      'plan', p.nombre,
      'precio', p.precio,
      'moneda', 'ARS'
    ) order by p.nombre
  )
  into v_antes
  from public.planes p
  join jsonb_to_recordset(p_precios) as datos(id uuid, precio numeric)
    on datos.id = p.id;

  update public.planes p
  set precio = round(datos.precio, 2),
      moneda = 'ARS',
      actualizado_en = now()
  from jsonb_to_recordset(p_precios) as datos(id uuid, precio numeric)
  where p.id = datos.id;

  select jsonb_agg(
    jsonb_build_object(
      'plan_id', p.id,
      'plan', p.nombre,
      'precio', p.precio,
      'moneda', 'ARS'
    ) order by p.nombre
  )
  into v_despues
  from public.planes p
  join jsonb_to_recordset(p_precios) as datos(id uuid, precio numeric)
    on datos.id = p.id;

  insert into public.auditoria_administrativa (
    administrador_id,
    accion,
    detalle,
    datos_anteriores,
    datos_nuevos
  ) values (
    p_administrador_id,
    'actualizar_precios_planes',
    'Actualización del catálogo público de precios en pesos argentinos',
    v_antes,
    v_despues
  );
end
$$;

revoke execute on function public.actualizar_catalogo_precios(uuid, jsonb)
from public, anon, authenticated;
grant execute on function public.actualizar_catalogo_precios(uuid, jsonb)
to service_role;
