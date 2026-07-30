-- Reanuda los workers globales solo después de desplegar las Edge Functions
-- compatibles con el esquema multicuenta.

do $$
begin
  if not exists (
    select 1
    from vault.decrypted_secrets
    where name = 'agenkin_project_url'
      and nullif(decrypted_secret, '') is not null
  ) then
    raise exception 'CONFIGURACION_REQUERIDA: falta agenkin_project_url en Vault';
  end if;

  if not exists (
    select 1
    from vault.decrypted_secrets
    where name = 'agenkin_cron_secret'
      and nullif(decrypted_secret, '') is not null
  ) then
    raise exception 'CONFIGURACION_REQUERIDA: falta agenkin_cron_secret en Vault';
  end if;
end
$$;

do $$
declare
  trabajo record;
begin
  for trabajo in
    select jobid
    from cron.job
    where jobname in (
      'agenkin-descubrir-gmail',
      'agenkin-procesar-gmail',
      'agenkin-crear-eventos',
      'agenkin-procesar-calendar'
    )
  loop
    perform cron.unschedule(trabajo.jobid);
  end loop;

  perform cron.schedule(
    'agenkin-descubrir-gmail',
    '*/5 * * * *',
    $tarea$
      select net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'agenkin_project_url'
        ) || '/functions/v1/sync-gmail-scheduled',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-agenkin-cron-secret', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'agenkin_cron_secret'
          )
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 125000
      );
    $tarea$
  );

  perform cron.schedule(
    'agenkin-procesar-gmail',
    '* * * * *',
    $tarea$
      select net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'agenkin_project_url'
        ) || '/functions/v1/process-gmail-queue',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-agenkin-cron-secret', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'agenkin_cron_secret'
          )
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 125000
      );
    $tarea$
  );

  perform cron.schedule(
    'agenkin-crear-eventos',
    '*/2 * * * *',
    $tarea$
      select net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'agenkin_project_url'
        ) || '/functions/v1/create-calendar-scheduled',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-agenkin-cron-secret', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'agenkin_cron_secret'
          )
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 125000
      );
    $tarea$
  );

  perform cron.schedule(
    'agenkin-procesar-calendar',
    '* * * * *',
    $tarea$
      select net.http_post(
        url := (
          select decrypted_secret
          from vault.decrypted_secrets
          where name = 'agenkin_project_url'
        ) || '/functions/v1/process-calendar-queue',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-agenkin-cron-secret', (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'agenkin_cron_secret'
          )
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 125000
      );
    $tarea$
  );
end
$$;
