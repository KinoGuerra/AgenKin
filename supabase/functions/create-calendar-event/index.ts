import { sincronizarEventoAgenda } from '../_shared/calendar.ts'
import { errorSeguro, json, manejarPreflight } from '../_shared/http.ts'
import { clienteServicio, usuarioAutenticado } from '../_shared/supabase.ts'

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

function fechaActual(zona: string) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: zona,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date())
}

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    const body = await request.json()
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const invocacionAutomatica = Boolean(serviceKey)
      && body.automatico === true
      && UUID.test(body.usuario_id || '')
      && request.headers.get('Authorization') === `Bearer ${serviceKey}`
    const contexto = invocacionAutomatica
      ? { usuario: { id: body.usuario_id }, cliente: clienteServicio() }
      : await usuarioAutenticado(request)
    const { usuario, cliente } = contexto
    const servicio = clienteServicio()

    if (!UUID.test(body.vencimiento_id || '')) return json({ error: 'Vencimiento inválido' }, 400)
    const { data: habilitado } = await cliente.rpc('usuario_habilitado', { usuario: usuario.id })
    if (!habilitado) return json({ error: 'La cuenta o suscripción no está habilitada' }, 403)

    const { data: vencimiento, error: errorVencimiento } = await cliente
      .from('vencimientos_detectados')
      .select('id,titulo,descripcion,fecha_vencimiento,hora_vencimiento,zona_horaria,estado,confianza,requiere_revision')
      .eq('id', body.vencimiento_id)
      .eq('usuario_id', usuario.id)
      .single()
    if (errorVencimiento) return json({ error: 'Vencimiento no encontrado' }, 404)

    const { data: conexion } = await cliente
      .from('conexiones_google')
      .select('calendar_conectado,creacion_automatica_eventos,umbral_confianza_automatica')
      .eq('usuario_id', usuario.id)
      .maybeSingle()
    if (invocacionAutomatica) {
      const elegible = conexion?.creacion_automatica_eventos
        && vencimiento.estado === 'pendiente'
        && !vencimiento.requiere_revision
        && Number(vencimiento.confianza) >= Number(conexion.umbral_confianza_automatica)
        && vencimiento.fecha_vencimiento >= fechaActual(vencimiento.zona_horaria)
      if (!elegible) return json({ ok: true, omitido: true })
    }

    const titulo = String(invocacionAutomatica ? vencimiento.titulo : body.titulo || vencimiento.titulo)
      .trim()
      .slice(0, 160)
    const descripcion = String(
      invocacionAutomatica ? vencimiento.descripcion : body.descripcion || vencimiento.descripcion || '',
    ).slice(0, 1000)
    const fecha = !invocacionAutomatica && /^\d{4}-\d{2}-\d{2}$/.test(body.fecha || '')
      ? body.fecha
      : vencimiento.fecha_vencimiento
    const hora = !invocacionAutomatica && /^\d{2}:\d{2}$/.test(body.hora || '')
      ? body.hora
      : vencimiento.hora_vencimiento?.slice(0, 5) || null
    const fechaEvento = hora
      ? new Date(`${fecha}T${hora}:00-03:00`).toISOString()
      : new Date(`${fecha}T12:00:00-03:00`).toISOString()
    const recordatorio = Number(body.recordatorio)
    const recordatorioMinutos = Number.isInteger(recordatorio)
      && recordatorio >= 0
      && recordatorio <= 40_320
      ? recordatorio
      : 1_440

    const { data: agendaEventoId, error: errorAgenda } = await servicio.rpc('registrar_evento_agenda', {
      p_usuario_id: usuario.id,
      p_vencimiento_id: vencimiento.id,
      p_titulo: titulo,
      p_descripcion: descripcion,
      p_fecha_evento: fechaEvento,
      p_zona_horaria: vencimiento.zona_horaria,
      p_es_dia_completo: !hora,
      p_recordatorio_minutos: recordatorioMinutos,
    })
    if (errorAgenda) throw new Error('No se pudo guardar el evento en Agenda')

    let googleEstado = conexion?.calendar_conectado ? 'pendiente' : 'no_conectado'
    if (conexion?.calendar_conectado) {
      try {
        const googleId = await sincronizarEventoAgenda(servicio, usuario.id, agendaEventoId)
        googleEstado = googleId ? 'sincronizado' : 'no_conectado'
      } catch {
        googleEstado = 'pendiente'
      }
    }
    return json({
      ok: true,
      automatico: invocacionAutomatica,
      agenda_event_id: agendaEventoId,
      google_estado: googleEstado,
    })
  } catch (error) {
    return errorSeguro(error)
  }
})
