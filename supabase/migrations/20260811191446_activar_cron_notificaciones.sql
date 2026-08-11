-- Aplicar sólo después de desplegar process-notifications-scheduled.
do $$
declare trabajo record;
begin
  if not exists (
    select 1 from vault.decrypted_secrets where name = 'agenkin_project_url'
  ) then raise exception 'CONFIGURACION_REQUERIDA: falta agenkin_project_url en Vault'; end if;
  if not exists (
    select 1 from vault.decrypted_secrets where name = 'agenkin_cron_secret'
  ) then raise exception 'CONFIGURACION_REQUERIDA: falta agenkin_cron_secret en Vault'; end if;

  for trabajo in
    select jobid from cron.job where jobname = 'agenkin-procesar-notificaciones'
  loop
    perform cron.unschedule(trabajo.jobid);
  end loop;

  perform cron.schedule(
    'agenkin-procesar-notificaciones',
    '* * * * *',
    $tarea$
      select net.http_post(
        url := (
          select decrypted_secret from vault.decrypted_secrets
          where name = 'agenkin_project_url'
        ) || '/functions/v1/process-notifications-scheduled',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-agenkin-cron-secret', (
            select decrypted_secret from vault.decrypted_secrets
            where name = 'agenkin_cron_secret'
          )
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 55000
      );
    $tarea$
  );

  for trabajo in
    select jobid from cron.job where jobname = 'agenkin-mantenimiento-diario'
  loop
    perform cron.unschedule(trabajo.jobid);
  end loop;
  perform cron.schedule(
    'agenkin-mantenimiento-diario',
    '43 3 * * *',
    $tarea$
      select private.ejecutar_mantenimiento_agenkin();
      select private.limpiar_notificaciones_agenkin();
    $tarea$
  );
end
$$;
