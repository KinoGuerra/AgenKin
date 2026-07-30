import { ErrorGoogle, tokenAcceso } from '../_shared/google.ts'
import {
  type ConexionCorreo,
  procesarCorreoGmail,
  type TareaCorreo,
} from '../_shared/process-email.ts'
import { errorSeguro, json, manejarPreflight, verificarCron } from '../_shared/http.ts'
import { clienteServicio } from '../_shared/supabase.ts'

const MAXIMO_INTENTOS = 5
const TAREAS_POR_EJECUCION = 20
const CONCURRENCIA = 4
const PRESUPUESTO_MS = 120_000
const MINIMO_PARA_OTRO_GRUPO_MS = 65_000

type ConexionFila = {
  id: string
  usuario_id: string
  google_email: string
  refresh_token_cifrado: string
  token_iv: string
  gmail_conectado: boolean
  estado_conexion: string
}

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    verificarCron(request)
    const inicio = Date.now()
    const cliente = clienteServicio()
    const { data: tareas, error } = await cliente.rpc('leer_tareas_correos_gmail', {
      p_cantidad: TAREAS_POR_EJECUCION,
    })
    if (error) throw error

    const lista = (tareas || []) as TareaCorreo[]
    const idsConexion = [...new Set(lista.map((tarea) => tarea.conexion_google_id))]
    const { data: conexiones, error: errorConexiones } = idsConexion.length
      ? await cliente
        .from('conexiones_google')
        .select('id,usuario_id,google_email,refresh_token_cifrado,token_iv,gmail_conectado,estado_conexion')
        .in('id', idsConexion)
      : { data: [], error: null }
    if (errorConexiones) throw errorConexiones

    const filas = new Map(
      ((conexiones || []) as ConexionFila[]).map((conexion) => [conexion.id, conexion]),
    )
    const accesos = new Map<string, Promise<string>>()
    const obtenerConexion = async (tarea: TareaCorreo): Promise<ConexionCorreo | null> => {
      const conexion = filas.get(tarea.conexion_google_id)
      if (
        !conexion
        || conexion.usuario_id !== tarea.usuario_id
        || !conexion.gmail_conectado
        || conexion.estado_conexion !== 'activa'
      ) return null
      if (!accesos.has(conexion.id)) {
        accesos.set(conexion.id, tokenAcceso(conexion))
      }
      return {
        id: conexion.id,
        usuario_id: conexion.usuario_id,
        google_email: conexion.google_email,
        acceso: await accesos.get(conexion.id)!,
      }
    }

    const resumen = {
      procesadas: 0,
      ignoradas: 0,
      omitidas: 0,
      detectadas: 0,
      reintentos: 0,
      errores: 0,
      diferidas: 0,
    }
    const conexionesActualizadas = new Set<string>()

    for (let indice = 0; indice < lista.length; indice += CONCURRENCIA) {
      const restante = PRESUPUESTO_MS - (Date.now() - inicio)
      if (indice > 0 && restante < MINIMO_PARA_OTRO_GRUPO_MS) {
        const diferidas = lista.slice(indice)
        resumen.diferidas += diferidas.length
        await cliente.rpc('liberar_tareas_correos_gmail', {
          p_tarea_ids: diferidas.map((tarea) => tarea.tarea_id),
        })
        break
      }

      const grupo = lista.slice(indice, indice + CONCURRENCIA)
      await Promise.all(grupo.map(async (tarea) => {
        let codigoError: string | null = null
        let reintentar = false
        let retrasoSegundos = 0
        let tareaFinalizada = false
        try {
          const conexion = await obtenerConexion(tarea)
          if (!conexion) {
            codigoError = 'CONEXION_GMAIL_INVALIDA'
          } else {
            const resultado = await procesarCorreoGmail(cliente, tarea, conexion)
            codigoError = resultado.codigoError
            retrasoSegundos = resultado.retrasoSegundos
            tareaFinalizada = resultado.tareaFinalizada
            reintentar = resultado.estado === 'reintentar'
              && (
                resultado.codigoError === 'AI_LIMITE_TEMPORAL'
                || tarea.intentos + 1 < MAXIMO_INTENTOS
              )
            if (resultado.estado === 'procesado') resumen.procesadas += 1
            if (resultado.estado === 'ignorado') resumen.ignoradas += 1
            if (resultado.estado === 'omitido') resumen.omitidas += 1
            if (resultado.detectado) resumen.detectadas += 1
            if (
              ['procesado', 'ignorado'].includes(resultado.estado)
              || (resultado.estado === 'omitido' && !resultado.tareaFinalizada)
            ) {
              conexionesActualizadas.add(tarea.conexion_google_id)
            }
          }
        } catch (errorTarea) {
          codigoError = errorTarea instanceof ErrorGoogle
            ? errorTarea.codigo
            : 'PROCESAMIENTO_FALLIDO'
          reintentar = (
            !(errorTarea instanceof ErrorGoogle)
            || errorTarea.codigo === 'GOOGLE_TEMPORAL'
          ) && tarea.intentos + 1 < MAXIMO_INTENTOS
          retrasoSegundos = errorTarea instanceof ErrorGoogle
            ? Math.min(
                604_800,
                Math.max(60, Math.ceil((errorTarea.reintentoDespuesMs || 300_000) / 1_000)),
              )
            : 300
          if (
            errorTarea instanceof ErrorGoogle
            && errorTarea.codigo === 'GOOGLE_TOKEN_VENCIDO'
          ) {
            await cliente
              .from('conexiones_google')
              .update({
                estado_conexion: 'token_vencido',
                error_ultima_sincronizacion: 'GOOGLE_TOKEN_VENCIDO',
                proxima_sincronizacion: null,
              })
              .eq('id', tarea.conexion_google_id)
          }
        }

        if (!tareaFinalizada) {
          const { error: errorFinalizacion } = await cliente.rpc(
            'finalizar_tarea_correo_gmail',
            {
              p_tarea_id: tarea.tarea_id,
              p_error: codigoError,
              p_reintentar: reintentar,
              p_retraso_segundos: retrasoSegundos,
            },
          )
          if (errorFinalizacion) throw errorFinalizacion
        }

        if (codigoError && reintentar) resumen.reintentos += 1
        else if (codigoError) resumen.errores += 1
      }))
    }

    if (conexionesActualizadas.size) {
      const ahora = new Date().toISOString()
      await cliente
        .from('conexiones_google')
        .update({
          fecha_ultima_sincronizacion: ahora,
          gmail_ultima_lectura_en: ahora,
          agenda_ultima_actualizacion_en: ahora,
        })
        .in('id', [...conexionesActualizadas])
    }
    return json(resumen)
  } catch (error) {
    return errorSeguro(error)
  }
})
