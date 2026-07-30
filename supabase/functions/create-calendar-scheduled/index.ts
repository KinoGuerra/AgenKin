import { errorSeguro, json, manejarPreflight, verificarCron } from '../_shared/http.ts'
import { clienteServicio } from '../_shared/supabase.ts'

const MAXIMO_EVENTOS = 5

type EventoCreado = {
  evento_id: string
  usuario_id: string
}

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    verificarCron(request)
    const cliente = clienteServicio()
    const { data: eventos, error } = await cliente.rpc(
      'crear_eventos_automaticos_pendientes',
      { p_limite: MAXIMO_EVENTOS },
    )
    if (error) throw error

    return json({ creados: ((eventos || []) as EventoCreado[]).length })
  } catch (error) {
    return errorSeguro(error)
  }
})
