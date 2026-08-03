import { ErrorGoogle, googleJson, tokenAcceso } from './google.ts'

type Cliente = {
  from: (tabla: string) => any
  rpc: (funcion: string, argumentos?: Record<string, unknown>) => any
}

type OpcionesAgenda = {
  titulo?: unknown
  descripcion?: unknown
  fecha?: unknown
  hora?: unknown
  recordatorio?: unknown
}

export type ResultadoOperacionCalendar = {
  estado: 'sincronizado' | 'omitido' | 'no_conectado'
  googleId: string | null
}

function fechaLocal(valor: string | Date, zona: string, incluirHora = false) {
  const partes = new Intl.DateTimeFormat('en-US', {
    timeZone: zona,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    ...(incluirHora
      ? { hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' as const }
      : {}),
  }).formatToParts(new Date(valor))
  const obtener = (tipo: Intl.DateTimeFormatPartTypes) =>
    partes.find((parte) => parte.type === tipo)?.value || ''
  const fecha = `${obtener('year')}-${obtener('month')}-${obtener('day')}`
  return incluirHora
    ? `${fecha}T${obtener('hour')}:${obtener('minute')}:${obtener('second')}`
    : fecha
}

function intervaloEvento(fechaEvento: string, esDiaCompleto: boolean, zona: string) {
  if (esDiaCompleto) {
    const fecha = fechaLocal(fechaEvento, zona)
    const fin = new Date(fechaEvento)
    fin.setUTCDate(fin.getUTCDate() + 1)
    return { start: { date: fecha }, end: { date: fechaLocal(fin, zona) } }
  }
  const inicio = fechaLocal(fechaEvento, zona, true)
  const fin = new Date(fechaEvento)
  fin.setMinutes(fin.getMinutes() + 30)
  return {
    start: { dateTime: inicio, timeZone: zona },
    end: { dateTime: fechaLocal(fin, zona, true), timeZone: zona },
  }
}

export async function asegurarCalendarioVisible(
  acceso: string,
  calendarId: string,
) {
  const lista = 'https://www.googleapis.com/calendar/v3/users/me/calendarList'
  const entrada = `${lista}/${encodeURIComponent(calendarId)}`
  try {
    await googleJson(entrada, acceso, {
      method: 'PATCH',
      body: JSON.stringify({ hidden: false, selected: true }),
    })
  } catch (error) {
    if (!(error instanceof ErrorGoogle) || error.status !== 404) throw error
    await googleJson(lista, acceso, {
      method: 'POST',
      body: JSON.stringify({ id: calendarId, hidden: false, selected: true }),
    })
  }
}

export async function registrarEventoAgenda(
  cliente: Cliente,
  usuarioId: string,
  vencimientoId: string,
  opciones: OpcionesAgenda = {},
) {
  const { data: vencimiento, error: errorVencimiento } = await cliente
    .from('vencimientos_detectados')
    .select('id,titulo,descripcion,fecha_vencimiento,hora_vencimiento,zona_horaria,estado')
    .eq('id', vencimientoId)
    .eq('usuario_id', usuarioId)
    .single()
  if (errorVencimiento) throw new Error('Vencimiento no encontrado')
  if (!['pendiente', 'evento_creado'].includes(vencimiento.estado)) {
    throw new Error('El vencimiento ya no puede agregarse a Agenda')
  }

  const { data: conexiones, error: errorConexiones } = await cliente
    .from('conexiones_google')
    .select('calendar_conectado,es_calendar_principal,estado_conexion')
    .eq('usuario_id', usuarioId)
  if (errorConexiones) throw errorConexiones

  const calendarConectado = (conexiones || []).some((conexion: {
    calendar_conectado: boolean
    es_calendar_principal: boolean
    estado_conexion: string
  }) =>
    conexion.calendar_conectado
    && conexion.es_calendar_principal
    && conexion.estado_conexion === 'activa'
  )

  const titulo = String(opciones.titulo || vencimiento.titulo).trim().slice(0, 160)
  const descripcion = String(
    opciones.descripcion || vencimiento.descripcion || '',
  ).slice(0, 1000)
  const fecha = /^\d{4}-\d{2}-\d{2}$/.test(String(opciones.fecha || ''))
    ? String(opciones.fecha)
    : vencimiento.fecha_vencimiento
  const hora = /^\d{2}:\d{2}$/.test(String(opciones.hora || ''))
    ? String(opciones.hora)
    : vencimiento.hora_vencimiento?.slice(0, 5) || null
  const fechaEvento = hora
    ? new Date(`${fecha}T${hora}:00-03:00`).toISOString()
    : new Date(`${fecha}T12:00:00-03:00`).toISOString()
  const recordatorio = Number(opciones.recordatorio)
  const recordatorioMinutos = Number.isInteger(recordatorio)
    && recordatorio >= 0
    && recordatorio <= 40_320
    ? recordatorio
    : 1_440

  const { data: agendaEventoId, error: errorAgenda } = await cliente.rpc(
    'registrar_evento_agenda',
    {
      p_usuario_id: usuarioId,
      p_vencimiento_id: vencimiento.id,
      p_titulo: titulo,
      p_descripcion: descripcion,
      p_fecha_evento: fechaEvento,
      p_zona_horaria: vencimiento.zona_horaria,
      p_es_dia_completo: !hora,
      p_recordatorio_minutos: recordatorioMinutos,
    },
  )
  if (errorAgenda) throw new Error('No se pudo guardar el evento en Agenda')

  return {
    agenda_event_id: agendaEventoId as string,
    google_estado: calendarConectado ? 'pendiente' : 'no_conectado',
  }
}

export async function sincronizarEventoAgenda(
  cliente: Cliente,
  usuarioId: string,
  eventoId: string,
) {
  const { data: evento, error: errorEvento } = await cliente
    .from('eventos_calendar')
    .select('id,titulo,descripcion,fecha_evento,zona_horaria,es_dia_completo,recordatorio_minutos,google_event_id,calendar_id,conexion_google_id,estado_sincronizacion')
    .eq('id', eventoId)
    .eq('usuario_id', usuarioId)
    .single()
  if (errorEvento) throw new Error('Evento de Agenda no encontrado')
  if (evento.estado_sincronizacion === 'eliminado') {
    return { estado: 'omitido', googleId: null } satisfies ResultadoOperacionCalendar
  }
  if (evento.google_event_id) {
    return {
      estado: 'sincronizado',
      googleId: evento.google_event_id as string,
    } satisfies ResultadoOperacionCalendar
  }

  const { data: conexion, error: errorConexion } = await cliente
    .from('conexiones_google')
    .select('id,refresh_token_cifrado,token_iv,calendar_id,estado_conexion,calendar_conectado,es_calendar_principal')
    .eq('id', evento.conexion_google_id || '')
    .eq('usuario_id', usuarioId)
    .single()
  if (
    errorConexion
    || conexion.estado_conexion !== 'activa'
    || !conexion.calendar_conectado
    || !conexion.es_calendar_principal
  ) {
    await cliente.from('eventos_calendar').update({
      estado_google: 'no_conectado',
      error_google: null,
    }).eq('id', eventoId)
    return { estado: 'no_conectado', googleId: null } satisfies ResultadoOperacionCalendar
  }

  try {
    const acceso = await tokenAcceso(conexion)
    let calendarId = conexion.calendar_id
    if (!calendarId) {
      const calendario = await googleJson('https://www.googleapis.com/calendar/v3/calendars', acceso, {
        method: 'POST',
        body: JSON.stringify({
          summary: 'Agenda',
          description: 'Agenda de vencimientos administrada por AgenKin',
          timeZone: 'America/Argentina/Cordoba',
        }),
      })
      calendarId = calendario.id
      await cliente.from('conexiones_google').update({ calendar_id: calendarId }).eq('id', conexion.id)
      await asegurarCalendarioVisible(acceso, calendarId)
    }

    const eventoGoogleId = evento.id.replaceAll('-', '')
    const url = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendarId)}/events`
    let eventoGoogle
    try {
      eventoGoogle = await googleJson(url, acceso, {
        method: 'POST',
        body: JSON.stringify({
          id: eventoGoogleId,
          summary: evento.titulo,
          description: evento.descripcion,
          ...intervaloEvento(evento.fecha_evento, evento.es_dia_completo, evento.zona_horaria),
          reminders: {
            useDefault: false,
            overrides: [{ method: 'popup', minutes: evento.recordatorio_minutos }],
          },
          extendedProperties: { private: { agenkin_agenda_id: evento.id } },
        }),
      })
    } catch (error) {
      if (!(error instanceof ErrorGoogle) || error.status !== 409) throw error
      eventoGoogle = await googleJson(`${url}/${eventoGoogleId}`, acceso)
    }

    const ahora = new Date().toISOString()
    const { data: actualizado, error: errorActualizacion } = await cliente
      .from('eventos_calendar')
      .update({
        google_event_id: eventoGoogle.id,
        calendar_id: calendarId,
        conexion_google_id: conexion.id,
        estado_google: 'sincronizado',
        error_google: null,
        google_sincronizado_en: ahora,
      })
      .eq('id', evento.id)
      .neq('estado_sincronizacion', 'eliminado')
      .select('id')
      .maybeSingle()
    if (errorActualizacion) throw errorActualizacion
    if (!actualizado) {
      await eliminarEventoGoogle(acceso, calendarId, eventoGoogle.id || eventoGoogleId)
      return { estado: 'omitido', googleId: null } satisfies ResultadoOperacionCalendar
    }
    await cliente.from('conexiones_google').update({
      calendar_ultima_sincronizacion_en: ahora,
      agenda_ultima_actualizacion_en: ahora,
    }).eq('id', conexion.id)
    return {
      estado: 'sincronizado',
      googleId: eventoGoogle.id as string,
    } satisfies ResultadoOperacionCalendar
  } catch (error) {
    const codigo = error instanceof ErrorGoogle
      ? error.codigo
      : 'SINCRONIZACION_GOOGLE_FALLIDA'
    await cliente.from('eventos_calendar').update({
      estado_google: 'error',
      error_google: codigo,
    }).eq('id', eventoId)
    if (error instanceof ErrorGoogle && error.codigo === 'GOOGLE_TOKEN_VENCIDO') {
      await cliente.from('conexiones_google').update({
        estado_conexion: 'token_vencido',
        error_ultima_sincronizacion: 'GOOGLE_TOKEN_VENCIDO',
        proxima_sincronizacion: null,
      }).eq('id', conexion.id)
    }
    throw error
  }
}

async function eliminarEventoGoogle(
  acceso: string,
  calendarId: string,
  googleEventId: string,
) {
  const url = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendarId)}/events/${encodeURIComponent(googleEventId)}?sendUpdates=none`
  try {
    await googleJson(url, acceso, { method: 'DELETE' })
  } catch (error) {
    if (error instanceof ErrorGoogle && error.status === 404) return
    throw error
  }
}

export async function eliminarEventoAgenda(
  cliente: Cliente,
  usuarioId: string,
  eventoId: string,
): Promise<ResultadoOperacionCalendar> {
  const { data: evento, error: errorEvento } = await cliente
    .from('eventos_calendar')
    .select('id,google_event_id,calendar_id,conexion_google_id,estado_sincronizacion')
    .eq('id', eventoId)
    .eq('usuario_id', usuarioId)
    .single()
  if (errorEvento) throw new Error('Evento de Agenda no encontrado')

  if (!evento.conexion_google_id && !evento.google_event_id && !evento.calendar_id) {
    return { estado: 'omitido', googleId: null }
  }

  const { data: conexion, error: errorConexion } = await cliente
    .from('conexiones_google')
    .select('id,refresh_token_cifrado,token_iv,calendar_id,estado_conexion,calendar_conectado,es_calendar_principal')
    .eq('id', evento.conexion_google_id || '')
    .eq('usuario_id', usuarioId)
    .single()
  if (
    errorConexion
    || conexion.estado_conexion !== 'activa'
    || !conexion.calendar_conectado
    || !conexion.es_calendar_principal
  ) {
    await cliente.from('eventos_calendar').update({
      estado_google: 'no_conectado',
      error_google: null,
    }).eq('id', eventoId)
    return { estado: 'no_conectado', googleId: null }
  }

  const calendarId = evento.calendar_id || conexion.calendar_id
  if (!calendarId) {
    await cliente.from('eventos_calendar').update({
      estado_google: 'no_conectado',
      error_google: null,
    }).eq('id', eventoId)
    return { estado: 'omitido', googleId: null }
  }

  const googleEventId = evento.google_event_id || evento.id.replaceAll('-', '')
  try {
    const acceso = await tokenAcceso(conexion)
    await eliminarEventoGoogle(acceso, calendarId, googleEventId)
    const ahora = new Date().toISOString()
    await cliente.from('eventos_calendar').update({
      estado_google: 'no_conectado',
      error_google: null,
      google_sincronizado_en: ahora,
    }).eq('id', evento.id)
    await cliente.from('conexiones_google').update({
      calendar_ultima_sincronizacion_en: ahora,
      agenda_ultima_actualizacion_en: ahora,
    }).eq('id', conexion.id)
    return { estado: 'sincronizado', googleId: googleEventId }
  } catch (error) {
    const codigo = error instanceof ErrorGoogle
      ? error.codigo
      : 'SINCRONIZACION_GOOGLE_FALLIDA'
    await cliente.from('eventos_calendar').update({
      estado_google: 'error',
      error_google: codigo,
    }).eq('id', eventoId)
    if (error instanceof ErrorGoogle && error.codigo === 'GOOGLE_TOKEN_VENCIDO') {
      await cliente.from('conexiones_google').update({
        estado_conexion: 'token_vencido',
        error_ultima_sincronizacion: 'GOOGLE_TOKEN_VENCIDO',
        proxima_sincronizacion: null,
      }).eq('id', conexion.id)
    }
    throw error
  }
}
