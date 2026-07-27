import { googleJson, tokenAcceso } from '../_shared/google.ts'
import { errorSeguro, json, manejarPreflight } from '../_shared/http.ts'
import { usuarioAutenticado } from '../_shared/supabase.ts'

function fechaEvento(fecha: string, hora: string | null, zona: string) {
  if (!hora) {
    const fin = new Date(`${fecha}T12:00:00Z`)
    fin.setUTCDate(fin.getUTCDate() + 1)
    return { start: { date: fecha }, end: { date: fin.toISOString().slice(0, 10) } }
  }
  const inicio = `${fecha}T${hora}:00`
  const fin = new Date(`${inicio}-03:00`)
  fin.setMinutes(fin.getMinutes() + 30)
  const finLocal = new Intl.DateTimeFormat('sv-SE', {
    timeZone: zona, year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
  }).format(fin).replace(' ', 'T')
  return {
    start: { dateTime: inicio, timeZone: zona },
    end: { dateTime: finLocal, timeZone: zona },
  }
}

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    const { usuario, cliente } = await usuarioAutenticado(request)
    const body = await request.json()
    if (!/^[0-9a-f-]{36}$/i.test(body.vencimiento_id || '')) return json({ error: 'Vencimiento inválido' }, 400)
    const { data: habilitado } = await cliente.rpc('usuario_habilitado', { usuario: usuario.id })
    if (!habilitado) return json({ error: 'La cuenta o suscripción no está habilitada' }, 403)
    const { data: vencimiento, error: errorVencimiento } = await cliente
      .from('vencimientos_detectados')
      .select('id,titulo,descripcion,fecha_vencimiento,hora_vencimiento,zona_horaria,estado')
      .eq('id', body.vencimiento_id)
      .eq('usuario_id', usuario.id)
      .single()
    if (errorVencimiento) return json({ error: 'Vencimiento no encontrado' }, 404)
    const { data: existente } = await cliente.from('eventos_calendar').select('id,google_event_id').eq('vencimiento_id', vencimiento.id).maybeSingle()
    if (existente) return json({ ok: true, duplicado: true, evento_id: existente.google_event_id })
    const { data: conexion, error: errorConexion } = await cliente
      .from('conexiones_google')
      .select('refresh_token_cifrado,token_iv,calendar_id,estado_conexion')
      .eq('usuario_id', usuario.id)
      .single()
    if (errorConexion || conexion.estado_conexion !== 'activa') throw new Error('Conectá Google Calendar antes de crear el evento')
    const acceso = await tokenAcceso(conexion)
    let calendarId = conexion.calendar_id
    if (!calendarId) {
      const calendario = await googleJson('https://www.googleapis.com/calendar/v3/calendars', acceso, {
        method: 'POST',
        body: JSON.stringify({ summary: 'AgenKin', description: 'Eventos confirmados desde AgenKin', timeZone: 'America/Argentina/Cordoba' }),
      })
      calendarId = calendario.id
      await cliente.from('conexiones_google').update({ calendar_id: calendarId }).eq('usuario_id', usuario.id)
    }
    const titulo = String(body.titulo || vencimiento.titulo).trim().slice(0, 160)
    const descripcion = String(body.descripcion || vencimiento.descripcion || '').slice(0, 1000)
    const fecha = /^\d{4}-\d{2}-\d{2}$/.test(body.fecha || '') ? body.fecha : vencimiento.fecha_vencimiento
    const hora = /^\d{2}:\d{2}$/.test(body.hora || '') ? body.hora : vencimiento.hora_vencimiento?.slice(0, 5) || null
    const recordatorio = Math.min(10080, Math.max(0, Number(body.recordatorio) || 10))
    const intervalo = fechaEvento(fecha, hora, vencimiento.zona_horaria)
    const eventoId = vencimiento.id.replaceAll('-', '')
    const url = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(calendarId)}/events`
    const evento = await googleJson(url, acceso, {
      method: 'POST',
      body: JSON.stringify({
        id: eventoId,
        summary: titulo,
        description: descripcion,
        ...intervalo,
        reminders: { useDefault: false, overrides: [{ method: 'popup', minutes: recordatorio }] },
        extendedProperties: { private: { agenkin_vencimiento_id: vencimiento.id } },
      }),
    })
    const fechaEventoDb = hora ? new Date(`${fecha}T${hora}:00-03:00`).toISOString() : new Date(`${fecha}T12:00:00-03:00`).toISOString()
    const { error: errorRegistro } = await cliente.from('eventos_calendar').insert({
      usuario_id: usuario.id,
      vencimiento_id: vencimiento.id,
      google_event_id: evento.id,
      calendar_id: calendarId,
      fecha_evento: fechaEventoDb,
    })
    if (errorRegistro) throw new Error('El evento se creó, pero no pudo registrarse en AgenKin')
    await cliente.from('vencimientos_detectados').update({ estado: 'evento_creado' }).eq('id', vencimiento.id)
    await cliente.rpc('incrementar_eventos_creados', { p_usuario_id: usuario.id })
    return json({ ok: true, evento_id: evento.id })
  } catch (error) {
    return errorSeguro(error)
  }
})
