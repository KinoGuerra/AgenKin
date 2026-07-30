-- Reintenta únicamente fallos definitivos cuyos metadatos no llegaron a persistirse.
-- Los pendientes por límite temporal ya se reintentan mediante la cola normal.
update public.tareas_correos_gmail tarea
set
  estado = 'pendiente',
  intentos = 0,
  ultimo_error = null,
  disponible_en = now(),
  reclamada_en = null,
  actualizado_en = now()
where tarea.estado = 'error'
  and tarea.ultimo_error in ('AI_RESPUESTA_INVALIDA', 'PROCESAMIENTO_EN_CURSO')
  and exists (
    select 1
    from public.correos_procesados correo
    where correo.usuario_id = tarea.usuario_id
      and correo.conexion_google_id = tarea.conexion_google_id
      and correo.gmail_message_id = tarea.gmail_message_id
      and correo.estado_procesamiento = 'error'
      and correo.fecha_correo is null
      and btrim(coalesce(correo.remitente, '')) = ''
      and btrim(coalesce(correo.asunto, '')) = ''
  );
