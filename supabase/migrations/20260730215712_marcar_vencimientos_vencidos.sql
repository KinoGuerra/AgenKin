-- Una fecha pasada sigue siendo un hallazgo válido, pero nunca un pendiente.
-- Se conserva como antecedente y queda fuera de las acciones y del Calendar.
create or replace function private.marcar_vencimiento_vencido()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.estado in ('pendiente', 'confirmado')
    and new.fecha_vencimiento
      < (now() at time zone 'America/Argentina/Cordoba')::date then
    new.estado := 'vencido';
    new.actualizado_en := now();
  end if;
  return new;
end
$$;

revoke execute on function private.marcar_vencimiento_vencido()
from public, anon, authenticated;

drop trigger if exists vencimientos_marcar_fecha_pasada
on public.vencimientos_detectados;
create trigger vencimientos_marcar_fecha_pasada
before insert or update of fecha_vencimiento, estado
on public.vencimientos_detectados
for each row execute function private.marcar_vencimiento_vencido();

update public.vencimientos_detectados
set
  estado = 'vencido',
  actualizado_en = now()
where estado in ('pendiente', 'confirmado')
  and fecha_vencimiento
    < (now() at time zone 'America/Argentina/Cordoba')::date;
