import { registrarEventoAgenda } from '../_shared/calendar.ts'
import { errorSeguro, json, manejarPreflight } from '../_shared/http.ts'
import { usuarioAutenticado } from '../_shared/supabase.ts'

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    const body = await request.json()
    const { usuario, cliente } = await usuarioAutenticado(request)

    if (!UUID.test(body.vencimiento_id || '')) return json({ error: 'Vencimiento inválido' }, 400)
    const { data: habilitado } = await cliente.rpc('usuario_habilitado', { usuario: usuario.id })
    if (!habilitado) return json({ error: 'La cuenta o suscripción no está habilitada' }, 403)

    const resultado = await registrarEventoAgenda(
      cliente,
      usuario.id,
      body.vencimiento_id,
      {
        titulo: body.titulo,
        descripcion: body.descripcion,
        fecha: body.fecha,
        hora: body.hora,
        recordatorio: body.recordatorio,
      },
    )
    return json({
      ok: true,
      agenda_event_id: resultado.agenda_event_id,
      google_estado: resultado.google_estado,
    })
  } catch (error) {
    return errorSeguro(error)
  }
})
