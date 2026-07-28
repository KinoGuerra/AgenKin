import { envRequerida, errorSeguro, json, manejarPreflight, verificarCron } from '../_shared/http.ts'
import { clienteServicio } from '../_shared/supabase.ts'

const MAXIMO_EVENTOS = 5

type EventoAutomatico = {
  usuario_id: string
  vencimiento_id: string
}

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    verificarCron(request)
    const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = envRequerida(
      'SUPABASE_URL',
      'SUPABASE_SERVICE_ROLE_KEY',
    )
    const cliente = clienteServicio()
    const { data: pendientes, error } = await cliente.rpc(
      'obtener_eventos_automaticos_pendientes',
      { p_limite: MAXIMO_EVENTOS },
    )
    if (error) throw error

    const resumen = { creados: 0, omitidos: 0, errores: 0 }
    for (const pendiente of (pendientes || []) as EventoAutomatico[]) {
      try {
        const respuesta = await fetch(`${SUPABASE_URL}/functions/v1/create-calendar-event`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            usuario_id: pendiente.usuario_id,
            vencimiento_id: pendiente.vencimiento_id,
            automatico: true,
          }),
        })
        const resultado = await respuesta.json().catch(() => ({}))
        if (!respuesta.ok) resumen.errores += 1
        else if (resultado.omitido || resultado.duplicado) resumen.omitidos += 1
        else resumen.creados += 1
      } catch {
        resumen.errores += 1
      }
    }
    return json(resumen)
  } catch (error) {
    return errorSeguro(error)
  }
})
