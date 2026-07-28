-- Evita vencimientos duplicados y permite devolver un cupo cuando falla el
-- procesamiento técnico de un correo. La RPC solo es accesible por service_role.
create unique index if not exists vencimientos_correo_unico_idx
  on public.vencimientos_detectados (correo_id);

create or replace function public.liberar_cupo_correo(p_usuario_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  filas_actualizadas integer;
begin
  update public.consumos_mensuales
  set correos_procesados = greatest(correos_procesados - 1, 0)
  where usuario_id = p_usuario_id
    and periodo = date_trunc('month', current_date)::date
    and correos_procesados > 0;

  get diagnostics filas_actualizadas = row_count;
  return filas_actualizadas = 1;
end;
$$;

revoke execute on function public.liberar_cupo_correo(uuid) from public, anon, authenticated;
grant execute on function public.liberar_cupo_correo(uuid) to service_role;
