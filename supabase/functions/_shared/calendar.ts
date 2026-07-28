import { ErrorGoogle, googleJson, tokenAcceso } from './google.ts'

type Cliente = {
  from: (tabla: string) => any
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

export async function sincronizarEventoAgenda(
  cliente: Cliente,
  usuarioId: string,
  eventoId: string,
) {
  const { data: evento, error: errorEvento } = await cliente
    .from('eventos_calendar')
    .select('id,titulo,descripcion,fecha_evento,zona_horaria,es_dia_completo,recordatorio_minutos,google_event_id')
    .eq('id', eventoId)
    .eq('usuario_id', usuarioId)
    .single()
  if (errorEvento) throw new Error('Evento de Agenda no encontrado')
  if (evento.google_event_id) return evento.google_event_id as string

  const { data: conexion, error: errorConexion } = await cliente
    .from('conexiones_google')
    .select('refresh_token_cifrado,token_iv,calendar_id,estado_conexion,calendar_conectado')
    .eq('usuario_id', usuarioId)
    .single()
  if (errorConexion || conexion.estado_conexion !== 'activa' || !conexion.calendar_conectado) {
    await cliente.from('eventos_calendar').update({
      estado_google: 'no_conectado',
      error_google: null,
    }).eq('id', eventoId)
    return null
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
      await cliente.from('conexiones_google').update({ calendar_id: calendarId }).eq('usuario_id', usuarioId)
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
    const { error: errorActualizacion } = await cliente.from('eventos_calendar').update({
      google_event_id: eventoGoogle.id,
      calendar_id: calendarId,
      estado_google: 'sincronizado',
      error_google: null,
      google_sincronizado_en: ahora,
    }).eq('id', evento.id)
    if (errorActualizacion) throw errorActualizacion
    await cliente.from('conexiones_google').update({
      calendar_ultima_sincronizacion_en: ahora,
      agenda_ultima_actualizacion_en: ahora,
    }).eq('usuario_id', usuarioId)
    return eventoGoogle.id as string
  } catch (error) {
    await cliente.from('eventos_calendar').update({
      estado_google: 'error',
      error_google: 'SINCRONIZACION_GOOGLE_FALLIDA',
    }).eq('id', eventoId)
    throw error
  }
}
