-- Corrige tipos detectados por plpgsql_check después del despliegue y elimina
-- una declaración redundante del mantenimiento. La migración anterior también
-- queda corregida para instalaciones nuevas.

do $$
declare
  definicion text;
  corregida text;
begin
  select pg_get_functiondef(
    'public.finalizar_correo_analizado(uuid,uuid,uuid,uuid,jsonb)'::regprocedure
  )
  into definicion;

  corregida := replace(
    definicion,
    'estado_procesamiento = v_estado,',
    'estado_procesamiento = v_estado::public.estado_procesamiento,'
  );

  if corregida = definicion then
    raise exception 'No se encontró la asignación a corregir en finalizar_correo_analizado';
  end if;

  execute corregida;

  select pg_get_functiondef(
    'private.ejecutar_mantenimiento_agenkin()'::regprocedure
  )
  into definicion;

  corregida := replace(definicion, E'  lote integer;\n', '');

  if corregida = definicion then
    raise exception 'No se encontró la variable redundante en ejecutar_mantenimiento_agenkin';
  end if;

  execute corregida;
end
$$;
