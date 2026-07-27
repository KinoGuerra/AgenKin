-- Reemplazá el placeholder antes de ejecutar esta migración manual.
-- Nunca promovemos automáticamente una cuenta administrativa.
do $$
declare
  correo_objetivo text := 'REEMPLAZAR_EMAIL_SUPERADMIN';
begin
  if correo_objetivo = 'REEMPLAZAR_EMAIL_SUPERADMIN' then
    raise notice 'Promoción omitida: reemplazá REEMPLAZAR_EMAIL_SUPERADMIN por el correo del propietario.';
    return;
  end if;

  update public.perfiles
  set rol = 'superadministrador', actualizado_en = now()
  where lower(email) = lower(correo_objetivo);

  if not found then raise exception 'No existe un perfil con el correo indicado'; end if;
end $$;
