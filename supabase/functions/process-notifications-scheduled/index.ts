// @deno-types="npm:@types/web-push@3.6.4"
import webpush from 'npm:web-push@3.6.7'
import { descifrarToken } from '../_shared/crypto.ts'
import { errorSeguro, json, manejarPreflight, verificarCron } from '../_shared/http.ts'
import { clienteServicio } from '../_shared/supabase.ts'
import { hashEndpointPush, validarSuscripcionPush } from '../_shared/web-push.ts'

const CONCURRENCIA = 4
const PRESUPUESTO_MS = 50_000
const ESPERAS_SEGUNDOS = [60, 300, 1_800]

type Entrega = {
  entrega_id: string
  usuario_id: string
  suscripcion_id: string
  notificacion_id: string
  version_evento: number
  intento: number
  datos_cifrados: string
  iv: string
}

function estadoHttp(error: unknown) {
  if (!error || typeof error !== 'object') return null
  const valor = Number((error as { statusCode?: unknown }).statusCode)
  return Number.isInteger(valor) ? valor : null
}

function retryAfterSegundos(error: unknown) {
  if (!error || typeof error !== 'object') return null
  const headers = (error as { headers?: Record<string, string | string[]> }).headers
  const bruto = headers?.['retry-after']
  const valor = Array.isArray(bruto) ? bruto[0] : bruto
  if (!valor) return null
  const segundos = Number(valor)
  if (Number.isFinite(segundos) && segundos >= 0) {
    return Math.min(segundos, 21_600)
  }
  const fecha = Date.parse(valor)
  return Number.isFinite(fecha) ? Math.min(Math.max(0, Math.ceil((fecha - Date.now()) / 1_000)), 21_600) : null
}

function temporal(estado: number | null) {
  return estado === null || estado === 408 || estado === 429 || estado >= 500
}

async function finalizar(
  cliente: ReturnType<typeof clienteServicio>,
  entrega: Pick<Entrega, 'entrega_id' | 'intento'>,
  estado: 'exitosa' | 'reintento' | 'terminal',
  codigo: string | null,
  disponibleEn: string | null = null,
) {
  const { error } = await cliente.rpc('finalizar_entrega_push_web', {
    p_entrega_id: entrega.entrega_id,
    p_intento: entrega.intento,
    p_estado: estado,
    p_codigo_error: codigo,
    p_disponible_en: disponibleEn,
  })
  if (error) throw error
}

async function enviarEntrega(
  cliente: ReturnType<typeof clienteServicio>,
  entrega: Entrega,
) {
  try {
    const plana = await descifrarToken(entrega.datos_cifrados, entrega.iv)
    const suscripcion = validarSuscripcionPush(JSON.parse(plana))
    await webpush.sendNotification(
      suscripcion,
      JSON.stringify({ notification_id: entrega.notificacion_id }),
      { TTL: 86_400, timeout: 8_000, urgency: 'normal' },
    )
    await finalizar(cliente, entrega, 'exitosa', null)
  } catch (error) {
    const estado = estadoHttp(error)
    const codigo = estado ? `PUSH_HTTP_${estado}` : 'PUSH_RED_O_TIMEOUT'
    if (estado === 404 || estado === 410) {
      await finalizar(cliente, entrega, 'terminal', codigo)
      try {
        const plana = await descifrarToken(entrega.datos_cifrados, entrega.iv)
        const suscripcion = validarSuscripcionPush(JSON.parse(plana))
        await cliente.rpc('desactivar_suscripcion_push_web', {
          p_usuario_id: entrega.usuario_id,
          p_endpoint_hash: await hashEndpointPush(suscripcion.endpoint),
          p_motivo: 'expirada',
        })
      } catch {
        // La entrega terminal ya quedó registrada; la limpieza puede reintentarse luego.
      }
      return
    }
    if (temporal(estado) && entrega.intento < 4) {
      const espera = retryAfterSegundos(error) ??
        ESPERAS_SEGUNDOS[
          Math.min(entrega.intento - 1, ESPERAS_SEGUNDOS.length - 1)
        ]
      await finalizar(
        cliente,
        entrega,
        'reintento',
        codigo,
        new Date(Date.now() + espera * 1_000).toISOString(),
      )
      return
    }
    await finalizar(cliente, entrega, 'terminal', codigo)
  }
}

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  let cronAutorizado = false
  try {
    verificarCron(request)
    cronAutorizado = true
    const inicio = Date.now()
    const cliente = clienteServicio()
    const { data: reconciliadas, error: errorReconciliar } = await cliente
      .rpc('reconciliar_notificaciones_eventos', { p_limite: 40 })
    if (errorReconciliar) throw errorReconciliar
    const { data: entregadas, error: errorEntregar } = await cliente
      .rpc('entregar_notificaciones_pendientes', { p_limite: 20 })
    if (errorEntregar) throw errorEntregar

    const vapidSubject = Deno.env.get('VAPID_SUBJECT')?.trim()
    const vapidPublicKey = Deno.env.get('VAPID_PUBLIC_KEY')?.trim()
    const vapidPrivateKey = Deno.env.get('VAPID_PRIVATE_KEY')?.trim()
    if (!vapidSubject || !vapidPublicKey || !vapidPrivateKey) {
      return json({
        eventos_reconciliados: Number(reconciliadas || 0),
        alertas_entregadas: Array.isArray(entregadas) ? entregadas.length : 0,
        push_reclamados: 0,
        push_procesados: 0,
        push_configurado: false,
      })
    }
    webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey)

    const { data, error } = await cliente.rpc('reclamar_entregas_push_web', {
      p_limite: 40,
    })
    if (error) throw error
    const entregas = (data || []) as Entrega[]
    let procesadas = 0
    for (let indice = 0; indice < entregas.length; indice += CONCURRENCIA) {
      if (Date.now() - inicio >= PRESUPUESTO_MS) break
      const grupo = entregas.slice(indice, indice + CONCURRENCIA)
      await Promise.all(
        grupo.map((entrega) => enviarEntrega(cliente, entrega)),
      )
      procesadas += grupo.length
    }
    return json({
      eventos_reconciliados: Number(reconciliadas || 0),
      alertas_entregadas: Array.isArray(entregadas) ? entregadas.length : 0,
      push_reclamados: entregas.length,
      push_procesados: procesadas,
    })
  } catch (error) {
    return errorSeguro(
      error,
      cronAutorizado ? 500 : 401,
      'No se pudo ejecutar el proceso programado.',
    )
  }
})
