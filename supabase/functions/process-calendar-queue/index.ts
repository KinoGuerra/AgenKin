import { sincronizarEventoAgenda } from '../_shared/calendar.ts'
import { errorSeguro, json, manejarPreflight, verificarCron } from '../_shared/http.ts'
import { clienteServicio } from '../_shared/supabase.ts'

const MAXIMO_INTENTOS = 5

type TareaCalendar = {
  msg_id: number
  tarea_id: string
  evento_id: string
  usuario_id: string
  intentos: number
}

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    verificarCron(request)
    const cliente = clienteServicio()
    const { data: tareas, error } = await cliente.rpc('leer_tareas_calendar', { p_cantidad: 3 })
    if (error) throw error

    const resumen = { sincronizados: 0, reintentos: 0, errores: 0 }
    for (const tarea of (tareas || []) as TareaCalendar[]) {
      let codigoError: string | null = null
      try {
        const googleId = await sincronizarEventoAgenda(cliente, tarea.usuario_id, tarea.evento_id)
        if (!googleId) codigoError = 'CALENDAR_DESCONECTADO'
      } catch {
        codigoError = 'SINCRONIZACION_GOOGLE_FALLIDA'
      }
      const reintentar = codigoError === 'SINCRONIZACION_GOOGLE_FALLIDA'
        && tarea.intentos + 1 < MAXIMO_INTENTOS
      const { error: errorFinalizacion } = await cliente.rpc('finalizar_tarea_calendar', {
        p_msg_id: tarea.msg_id,
        p_tarea_id: tarea.tarea_id,
        p_error: codigoError,
        p_reintentar: reintentar,
      })
      if (errorFinalizacion) throw errorFinalizacion
      if (!codigoError) resumen.sincronizados += 1
      else if (reintentar) resumen.reintentos += 1
      else resumen.errores += 1
    }
    return json(resumen)
  } catch (error) {
    return errorSeguro(error)
  }
})
