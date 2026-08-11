# Notificaciones internas y Web Push

Agenda es la fuente principal. Cada cambio relevante de un evento incrementa
una versión; el worker global reconcilia hasta 40 eventos y entrega hasta 20
alertas internas por minuto. Push se encola después y nunca puede revertir la
alerta interna.

## Secretos

Configurar exclusivamente en Supabase Secrets:

```bash
supabase secrets set \
  VAPID_PUBLIC_KEY="CLAVE_PUBLICA" \
  VAPID_PRIVATE_KEY="CLAVE_PRIVADA" \
  VAPID_SUBJECT="mailto:seguridad@ejemplo.com"
```

`TOKEN_ENCRYPTION_KEY` cifra endpoint y claves de cada dispositivo.
`CRON_SECRET` protege `process-notifications-scheduled`. Ninguno usa prefijo
`VITE_`; la clave VAPID pública se obtiene desde la función autenticada.

La dependencia `web-push@3.6.7` está fijada sólo en el `deno.json` de la
función. No se incorpora al paquete del frontend.

## Orden de publicación

1. Pausar únicamente el Cron de notificaciones si ya existiera.
2. Aplicar las migraciones de revisión, alertas y Push.
3. Desplegar `process-gmail-queue`, `admin-manage-user`, `manage-web-push` y
   `process-notifications-scheduled`.
4. Probar con dos usuarios y dos dispositivos.
5. Aplicar `20260811191446_activar_cron_notificaciones.sql`.
6. Publicar el frontend al final.

El Service Worker no implementa caché offline ni intercepta solicitudes. El
payload exterior contiene sólo un UUID de notificación y texto genérico. Los
endpoints se validan al guardar y al enviar: HTTPS, puerto estándar, sin
credenciales, IP ni localhost, y con proveedor explícitamente permitido.

## Retención y operación

- Alertas entregadas o canceladas: 30 días.
- Entregas Push exitosas: 48 horas.
- Entregas terminales: 30 días.
- Suscripciones inactivas: 30 días.
- Cada sentencia de limpieza elimina como máximo 1.000 filas.

Una demora de alertas superior a 30 minutos aparece en Administración. Para un
rollback urgente, desactivar el Cron y volver a la función/frontend anterior;
no borrar tablas, historial ni suscripciones.
