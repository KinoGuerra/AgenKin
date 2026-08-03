import { ErrorGoogle, tokenAcceso } from '../_shared/google.ts'
import {
  type ConexionSincronizable,
  descubrirCambiosGmail,
} from '../_shared/gmail-sync.ts'
import { errorSeguro, json, manejarPreflight, verificarCron } from '../_shared/http.ts'
import { clienteServicio } from '../_shared/supabase.ts'

const CUENTAS_POR_EJECUCION = 40
const CONCURRENCIA = 4
const PRESUPUESTO_MS = 120_000

function colaSaturada(error: unknown) {
  return typeof error === 'object'
    && error !== null
    && 'message' in error
    && String(error.message).includes('COLA_GMAIL_SATURADA')
}

async function actualizarConexion(
  cliente: ReturnType<typeof clienteServicio>,
  conexionId: string,
  cambios: Record<string, unknown>,
) {
  const { error } = await cliente
    .from('conexiones_google')
    .update(cambios)
    .eq('id', conexionId)
  if (error) throw error
}

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    verificarCron(request)
    const inicio = Date.now()
    const cliente = clienteServicio()
    const [{ data: conexiones, error }, { data: capacidad }] = await Promise.all([
      cliente.rpc('reclamar_sincronizaciones_google', {
        p_limite: CUENTAS_POR_EJECUCION,
      }),
      cliente.rpc('estado_capacidad_agenkin'),
    ])
    if (error) throw error
    const permitirHistorico = !capacidad?.detener_carga_historica
    const lista = (conexiones || []) as ConexionSincronizable[]
    const resumen = {
      revisadas: 0,
      descubiertos: 0,
      encolados: 0,
      errores: 0,
      diferidas: 0,
      carga_historica_detenida: !permitirHistorico,
      reconciliaciones: 0,
    }

    for (let indice = 0; indice < lista.length; indice += CONCURRENCIA) {
      if (Date.now() - inicio >= PRESUPUESTO_MS) {
        const diferidas = lista.slice(indice)
        resumen.diferidas += diferidas.length
        if (diferidas.length) {
          await cliente
            .from('conexiones_google')
            .update({ proxima_sincronizacion: new Date().toISOString() })
            .in('id', diferidas.map((conexion) => conexion.conexion_google_id))
        }
        break
      }

      const grupo = lista.slice(indice, indice + CONCURRENCIA)
      await Promise.all(grupo.map(async (conexion) => {
        try {
          const acceso = await tokenAcceso(conexion)
          const resultado = await descubrirCambiosGmail(
            cliente,
            conexion,
            acceso,
            permitirHistorico,
          )
          resumen.revisadas += 1
          resumen.descubiertos += resultado.descubiertos
          resumen.encolados += resultado.encolados
          if (resultado.origen === 'reconciliacion') resumen.reconciliaciones += 1
        } catch (errorConexion) {
          if (colaSaturada(errorConexion)) {
            resumen.diferidas += 1
            await actualizarConexion(
              cliente,
              conexion.conexion_google_id,
              { proxima_sincronizacion: new Date(Date.now() + 5 * 60_000).toISOString() },
            )
            return
          }
          resumen.errores += 1
          const historyVencido = errorConexion instanceof ErrorGoogle
            && errorConexion.status === 404
          const paginaInvalida = errorConexion instanceof ErrorGoogle
            && errorConexion.status === 400
          const tokenVencido = errorConexion instanceof ErrorGoogle
            && errorConexion.codigo === 'GOOGLE_TOKEN_VENCIDO'
          const cambios: Record<string, unknown> = {
            error_ultima_sincronizacion: tokenVencido
              ? 'GOOGLE_TOKEN_VENCIDO'
              : historyVencido
                ? 'GMAIL_HISTORY_VENCIDO'
                : 'SINCRONIZACION_FALLIDA',
            proxima_sincronizacion: tokenVencido
              ? null
              : new Date(Date.now() + 5 * 60_000).toISOString(),
          }
          if (tokenVencido) {
            cambios.estado_conexion = 'token_vencido'
          } else if (historyVencido) {
            Object.assign(cambios, {
              gmail_history_id: null,
              gmail_history_objetivo: null,
              gmail_page_token: null,
              sincronizacion_inicial_completa: false,
            })
          } else if (paginaInvalida) {
            cambios.gmail_page_token = null
          }
          await actualizarConexion(
            cliente,
            conexion.conexion_google_id,
            cambios,
          )
        }
      }))
    }
    return json(resumen)
  } catch (error) {
    return errorSeguro(error)
  }
})
