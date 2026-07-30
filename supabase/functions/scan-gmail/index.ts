import {
  type ConexionSincronizable,
  descubrirCambiosGmail,
} from '../_shared/gmail-sync.ts'
import { ErrorGoogle, tokenAcceso } from '../_shared/google.ts'
import { errorSeguro, json, manejarPreflight } from '../_shared/http.ts'
import { usuarioAutenticado } from '../_shared/supabase.ts'

const CONCURRENCIA = 2
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

type ConexionManual = ConexionSincronizable & {
  google_email: string
}

function idsSolicitados(valor: unknown) {
  if (valor === undefined || valor === null) return [] as string[]
  if (!Array.isArray(valor) || valor.length > 5) return null
  const ids = [...new Set(valor.map(String))]
  return ids.every((id) => UUID.test(id)) ? ids : null
}

function colaSaturada(error: unknown) {
  return typeof error === 'object'
    && error !== null
    && 'message' in error
    && String(error.message).includes('COLA_GMAIL_SATURADA')
}

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    const body = await request.json().catch(() => ({}))
    const solicitadas = idsSolicitados(body.conexion_ids)
    if (solicitadas === null) {
      return json({ error: 'Seleccioná hasta cinco cuentas Gmail válidas' }, 400)
    }

    const { usuario, cliente } = await usuarioAutenticado(request)
    const { data: habilitado } = await cliente.rpc('usuario_habilitado', {
      usuario: usuario.id,
    })
    if (!habilitado) {
      return json({ error: 'La cuenta o suscripción no está habilitada' }, 403)
    }

    const [
      { data: reclamadas, error: errorReclamo },
      { data: capacidad, error: errorCapacidad },
    ] = await Promise.all([
      cliente.rpc('reclamar_sincronizaciones_manuales', {
        p_usuario_id: usuario.id,
        p_conexion_ids: solicitadas.length ? solicitadas : null,
      }),
      cliente.rpc('estado_capacidad_agenkin'),
    ])
    if (errorReclamo || errorCapacidad) throw errorReclamo || errorCapacidad
    const conexiones = (reclamadas || []) as ConexionManual[]

    if (!conexiones.length) {
      const { count } = await cliente
        .from('conexiones_google')
        .select('id', { count: 'exact', head: true })
        .eq('usuario_id', usuario.id)
        .eq('gmail_conectado', true)
        .eq('estado_conexion', 'activa')
      return count
        ? json({
            error: 'La actualización ya fue solicitada. Esperá un minuto antes de repetirla.',
            codigo: 'SINCRONIZACION_EN_COOLDOWN',
          }, 429)
        : json({ error: 'Configuración requerida: conectá al menos una cuenta Gmail' }, 400)
    }

    const resumen = {
      descubiertos: 0,
      encolados: 0,
      errores: 0,
      diferidas: 0,
      no_disponibles: Math.max(0, solicitadas.length - conexiones.length),
      cuentas: [] as Array<Record<string, unknown>>,
    }
    const permitirHistorico = !capacidad?.detener_carga_historica

    for (let indice = 0; indice < conexiones.length; indice += CONCURRENCIA) {
      const grupo = conexiones.slice(indice, indice + CONCURRENCIA)
      const resultados = await Promise.all(grupo.map(async (conexion) => {
        try {
          const acceso = await tokenAcceso(conexion)
          const resultado = await descubrirCambiosGmail(
            cliente,
            conexion,
            acceso,
            permitirHistorico,
          )
          return {
            conexion_id: conexion.conexion_google_id,
            email: conexion.google_email,
            estado: resultado.completa ? 'encolada' : 'continuara',
            ...resultado,
          }
        } catch (errorConexion) {
          if (colaSaturada(errorConexion)) {
            return {
              conexion_id: conexion.conexion_google_id,
              email: conexion.google_email,
              estado: 'diferida',
              descubiertos: 0,
              encolados: 0,
            }
          }
          if (
            errorConexion instanceof ErrorGoogle
            && errorConexion.codigo === 'GOOGLE_TOKEN_VENCIDO'
          ) {
            await cliente
              .from('conexiones_google')
              .update({
                estado_conexion: 'token_vencido',
                error_ultima_sincronizacion: 'GOOGLE_TOKEN_VENCIDO',
                proxima_sincronizacion: null,
              })
              .eq('id', conexion.conexion_google_id)
              .eq('usuario_id', usuario.id)
          }
          return {
            conexion_id: conexion.conexion_google_id,
            email: conexion.google_email,
            estado: 'error',
            descubiertos: 0,
            encolados: 0,
          }
        }
      }))

      resultados.forEach((resultado) => {
        resumen.descubiertos += resultado.descubiertos
        resumen.encolados += resultado.encolados
        if (resultado.estado === 'error') resumen.errores += 1
        if (resultado.estado === 'diferida') resumen.diferidas += 1
        resumen.cuentas.push(resultado)
      })
    }

    return json({
      estado: resumen.errores || resumen.no_disponibles
        ? 'parcial'
        : resumen.diferidas
          ? 'diferida'
          : 'encolada',
      carga_historica_detenida: !permitirHistorico,
      ...resumen,
    })
  } catch (error) {
    return errorSeguro(error, 400, 'No se pudo iniciar la actualización de Gmail.')
  }
})
