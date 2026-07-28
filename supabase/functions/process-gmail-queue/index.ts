import { envRequerida, errorSeguro, json, manejarPreflight, verificarCron } from '../_shared/http.ts'
import { clienteServicio } from '../_shared/supabase.ts'

const MAXIMO_INTENTOS = 5

type TareaCola = {
  msg_id: number
  read_ct: number
  intentos: number
  tarea_id: string
  usuario_id: string
  gmail_message_id: string
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
    const { data: tareas, error } = await cliente.rpc('leer_tareas_correos_gmail', {
      p_cantidad: 2,
    })
    if (error) throw error

    const resumen = { procesadas: 0, reintentos: 0, errores: 0 }
    const usuariosProcesados = new Set<string>()
    for (const tarea of (tareas || []) as TareaCola[]) {
      let codigoError: string | null = null
      let reintentar = false
      let retrasoSegundos = 0
      let contarIntento = true
      try {
        const respuesta = await fetch(`${SUPABASE_URL}/functions/v1/scan-gmail`, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            usuario_id: tarea.usuario_id,
            gmail_message_ids: [tarea.gmail_message_id],
          }),
        })
        const resultado = await respuesta.json().catch(() => ({}))
        if (respuesta.ok && resultado.limite_alcanzado) {
          codigoError = 'LIMITE_MENSUAL'
          reintentar = true
          retrasoSegundos = 86_400
          contarIntento = false
        } else {
          codigoError = respuesta.ok && !resultado.errores && !resultado.reintentar
            ? null
            : respuesta.ok
              ? 'PROCESAMIENTO_PENDIENTE'
              : `HTTP_${respuesta.status}`
          reintentar = codigoError !== null && tarea.intentos + 1 < MAXIMO_INTENTOS
        }
      } catch {
        codigoError = 'INVOCACION_FALLIDA'
        reintentar = tarea.intentos + 1 < MAXIMO_INTENTOS
      }

      const { error: errorFinalizacion } = await cliente.rpc('finalizar_tarea_correo_gmail', {
        p_msg_id: tarea.msg_id,
        p_tarea_id: tarea.tarea_id,
        p_error: codigoError,
        p_reintentar: reintentar,
        p_retraso_segundos: retrasoSegundos,
        p_contar_intento: contarIntento,
      })
      if (errorFinalizacion) throw errorFinalizacion

      if (codigoError === null) {
        resumen.procesadas += 1
        usuariosProcesados.add(tarea.usuario_id)
      }
      else if (reintentar) resumen.reintentos += 1
      else resumen.errores += 1
    }

    if (resumen.procesadas) {
      const ahora = new Date().toISOString()
      await cliente
        .from('conexiones_google')
        .update({
          fecha_ultima_sincronizacion: ahora,
          gmail_ultima_lectura_en: ahora,
          agenda_ultima_actualizacion_en: ahora,
        })
        .in('usuario_id', [...usuariosProcesados])
    }
    return json(resumen)
  } catch (error) {
    return errorSeguro(error)
  }
})
