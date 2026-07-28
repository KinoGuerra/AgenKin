import { ErrorGoogle, googleJson, tokenAcceso } from '../_shared/google.ts'
import { errorSeguro, json, manejarPreflight, verificarCron } from '../_shared/http.ts'
import { clienteServicio } from '../_shared/supabase.ts'

const RESULTADOS_POR_PAGINA = 500

type ConexionProgramada = {
  usuario_id: string
  refresh_token_cifrado: string
  token_iv: string
  gmail_history_id: string | null
  gmail_history_objetivo: string | null
  gmail_page_token: string | null
  sincronizacion_inicial_completa: boolean
}

function idsMensajes(valor: unknown) {
  if (!Array.isArray(valor)) return []
  return valor
    .map((mensaje) => String(
      typeof mensaje === 'object' && mensaje !== null && 'id' in mensaje
        ? mensaje.id
        : '',
    ))
    .filter((id) => /^[a-zA-Z0-9_-]{1,128}$/.test(id))
}

async function registrarTareas(
  cliente: ReturnType<typeof clienteServicio>,
  usuarioId: string,
  ids: string[],
) {
  if (!ids.length) return 0
  const { data, error } = await cliente.rpc('registrar_tareas_correos_gmail', {
    p_usuario_id: usuarioId,
    p_gmail_message_ids: [...new Set(ids)],
  })
  if (error) throw error
  return Number(data || 0)
}

async function actualizarConexion(
  cliente: ReturnType<typeof clienteServicio>,
  usuarioId: string,
  cambios: Record<string, unknown>,
) {
  const { error } = await cliente
    .from('conexiones_google')
    .update(cambios)
    .eq('usuario_id', usuarioId)
  if (error) throw error
}

async function sincronizacionInicial(
  cliente: ReturnType<typeof clienteServicio>,
  conexion: ConexionProgramada,
  acceso: string,
) {
  let historyObjetivo = conexion.gmail_history_objetivo
  if (!historyObjetivo) {
    const perfil = await googleJson('https://gmail.googleapis.com/gmail/v1/users/me/profile', acceso)
    historyObjetivo = String(perfil.historyId || '')
    if (!historyObjetivo) throw new Error('Gmail no devolvió el cursor de sincronización')
    await actualizarConexion(cliente, conexion.usuario_id, { gmail_history_objetivo: historyObjetivo })
  }

  const parametros = new URLSearchParams({
    maxResults: String(RESULTADOS_POR_PAGINA),
    q: 'newer_than:90d',
  })
  if (conexion.gmail_page_token) parametros.set('pageToken', conexion.gmail_page_token)
  const pagina = await googleJson(
    `https://gmail.googleapis.com/gmail/v1/users/me/messages?${parametros}`,
    acceso,
  )
  const encolados = await registrarTareas(cliente, conexion.usuario_id, idsMensajes(pagina.messages))
  const siguiente = pagina.nextPageToken ? String(pagina.nextPageToken) : null
  const completada = !siguiente

  const cambios: Record<string, unknown> = {
    gmail_page_token: siguiente,
    gmail_history_id: completada ? historyObjetivo : conexion.gmail_history_id,
    gmail_history_objetivo: completada ? null : historyObjetivo,
    sincronizacion_inicial_completa: completada,
    error_ultima_sincronizacion: null,
    proxima_sincronizacion: new Date(Date.now() + (completada ? 5 : 1) * 60_000).toISOString(),
  }
  if (completada) {
    const ahora = new Date().toISOString()
    cambios.ultima_sincronizacion_exitosa = ahora
    cambios.gmail_ultima_lectura_en = ahora
    cambios.agenda_ultima_actualizacion_en = ahora
  }
  await actualizarConexion(cliente, conexion.usuario_id, cambios)
  return encolados
}

async function sincronizacionIncremental(
  cliente: ReturnType<typeof clienteServicio>,
  conexion: ConexionProgramada,
  acceso: string,
) {
  const parametros = new URLSearchParams({
    startHistoryId: conexion.gmail_history_id || '',
    maxResults: String(RESULTADOS_POR_PAGINA),
    historyTypes: 'messageAdded',
  })
  if (conexion.gmail_page_token) parametros.set('pageToken', conexion.gmail_page_token)
  const pagina = await googleJson(
    `https://gmail.googleapis.com/gmail/v1/users/me/history?${parametros}`,
    acceso,
  )
  const ids = (pagina.history || []).flatMap((cambio: {
    messagesAdded?: Array<{ message?: { id?: string } }>
  }) => idsMensajes((cambio.messagesAdded || []).map((item) => item.message)))
  const encolados = await registrarTareas(cliente, conexion.usuario_id, ids)
  const siguiente = pagina.nextPageToken ? String(pagina.nextPageToken) : null
  const historyObjetivo = String(pagina.historyId || conexion.gmail_history_objetivo || conexion.gmail_history_id)
  const completada = !siguiente

  const cambios: Record<string, unknown> = {
    gmail_page_token: siguiente,
    gmail_history_id: completada ? historyObjetivo : conexion.gmail_history_id,
    gmail_history_objetivo: completada ? null : historyObjetivo,
    error_ultima_sincronizacion: null,
    proxima_sincronizacion: new Date(Date.now() + (completada ? 5 : 1) * 60_000).toISOString(),
  }
  if (completada) {
    const ahora = new Date().toISOString()
    cambios.ultima_sincronizacion_exitosa = ahora
    cambios.gmail_ultima_lectura_en = ahora
    cambios.agenda_ultima_actualizacion_en = ahora
  }
  await actualizarConexion(cliente, conexion.usuario_id, cambios)
  return encolados
}

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    verificarCron(request)
    const cliente = clienteServicio()
    const { data: conexiones, error } = await cliente.rpc('reclamar_sincronizaciones_google', {
      p_limite: 3,
    })
    if (error) throw error

    const resumen = { revisadas: 0, encolados: 0, errores: 0 }
    for (const conexion of (conexiones || []) as ConexionProgramada[]) {
      try {
        const { data: habilitado } = await cliente.rpc('usuario_habilitado', {
          usuario: conexion.usuario_id,
        })
        if (!habilitado) continue
        const acceso = await tokenAcceso(conexion)
        const encolados = conexion.sincronizacion_inicial_completa && conexion.gmail_history_id
          ? await sincronizacionIncremental(cliente, conexion, acceso)
          : await sincronizacionInicial(cliente, conexion, acceso)
        resumen.revisadas += 1
        resumen.encolados += encolados
      } catch (errorConexion) {
        resumen.errores += 1
        const historyVencido = errorConexion instanceof ErrorGoogle && errorConexion.status === 404
        const paginaInvalida = errorConexion instanceof ErrorGoogle && errorConexion.status === 400
        const cambios: Record<string, unknown> = {
          error_ultima_sincronizacion: historyVencido ? 'GMAIL_HISTORY_VENCIDO' : 'SINCRONIZACION_FALLIDA',
          proxima_sincronizacion: new Date(Date.now() + 5 * 60_000).toISOString(),
        }
        if (historyVencido) {
          Object.assign(cambios, {
            gmail_history_id: null,
            gmail_history_objetivo: null,
            gmail_page_token: null,
            sincronizacion_inicial_completa: false,
          })
        } else if (paginaInvalida) {
          cambios.gmail_page_token = null
        }
        await actualizarConexion(cliente, conexion.usuario_id, cambios)
      }
    }
    return json(resumen)
  } catch (error) {
    return errorSeguro(error)
  }
})
