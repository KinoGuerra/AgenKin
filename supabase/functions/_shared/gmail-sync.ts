import { googleJson } from './google.ts'

const RESULTADOS_POR_PAGINA = 50
const RESULTADOS_RECONCILIACION = 100
const DIAS_RECONCILIACION = 7

type Cliente = {
  from: (tabla: string) => any
  rpc: (funcion: string, argumentos?: Record<string, unknown>) => any
}

export type ConexionSincronizable = {
  conexion_google_id: string
  usuario_id: string
  refresh_token_cifrado: string
  token_iv: string
  gmail_history_id: string | null
  gmail_history_objetivo: string | null
  gmail_page_token: string | null
  sincronizacion_inicial_completa: boolean
  gmail_reconciliacion_desde: string | null
  gmail_reconciliacion_page_token: string | null
  gmail_ultima_reconciliacion_en: string | null
}

function idsMensajes(valor: unknown) {
  if (!Array.isArray(valor)) return []
  return [...new Set(valor
    .map((mensaje) => String(
      typeof mensaje === 'object' && mensaje !== null && 'id' in mensaje
        ? mensaje.id
        : '',
    ))
    .filter((id) => /^[a-zA-Z0-9_-]{1,128}$/.test(id)))]
}

async function registrarTareas(
  cliente: Cliente,
  conexion: Pick<ConexionSincronizable, 'usuario_id' | 'conexion_google_id'>,
  ids: string[],
  origen: 'incremental' | 'reconciliacion' | 'historica',
) {
  if (!ids.length) return 0
  let total = 0
  for (let indice = 0; indice < ids.length; indice += 50) {
    const { data, error } = await cliente.rpc('registrar_tareas_correos_gmail', {
      p_usuario_id: conexion.usuario_id,
      p_conexion_google_id: conexion.conexion_google_id,
      p_gmail_message_ids: ids.slice(indice, indice + 50),
      p_origen_sincronizacion: origen,
    })
    if (error) throw error
    total += Number(data || 0)
  }
  return total
}

async function actualizarConexion(
  cliente: Cliente,
  conexionId: string,
  cambios: Record<string, unknown>,
) {
  const { error } = await cliente
    .from('conexiones_google')
    .update(cambios)
    .eq('id', conexionId)
  if (error) throw error
}

async function iniciarSoloIncremental(
  cliente: Cliente,
  conexion: ConexionSincronizable,
  acceso: string,
) {
  const perfil = await googleJson(
    'https://gmail.googleapis.com/gmail/v1/users/me/profile',
    acceso,
  )
  const historyId = String(perfil.historyId || '')
  if (!historyId) throw new Error('Gmail no devolvió el cursor de sincronización')
  const ahora = new Date().toISOString()
  await actualizarConexion(cliente, conexion.conexion_google_id, {
    gmail_history_id: historyId,
    gmail_history_objetivo: null,
    gmail_page_token: null,
    sincronizacion_inicial_completa: true,
    ultima_sincronizacion_exitosa: ahora,
    gmail_ultima_lectura_en: ahora,
    agenda_ultima_actualizacion_en: ahora,
    error_ultima_sincronizacion: null,
    proxima_sincronizacion: new Date(Date.now() + 5 * 60_000).toISOString(),
  })
  return { descubiertos: 0, encolados: 0, completa: true, origen: 'incremental' as const }
}

async function sincronizacionInicial(
  cliente: Cliente,
  conexion: ConexionSincronizable,
  acceso: string,
) {
  let historyObjetivo = conexion.gmail_history_objetivo
  if (!historyObjetivo) {
    const perfil = await googleJson(
      'https://gmail.googleapis.com/gmail/v1/users/me/profile',
      acceso,
    )
    historyObjetivo = String(perfil.historyId || '')
    if (!historyObjetivo) throw new Error('Gmail no devolvió el cursor de sincronización')
    await actualizarConexion(cliente, conexion.conexion_google_id, {
      gmail_history_objetivo: historyObjetivo,
    })
  }

  const parametros = new URLSearchParams({
    maxResults: String(RESULTADOS_POR_PAGINA),
    q: 'newer_than:90d',
  })
  if (conexion.gmail_page_token) {
    parametros.set('pageToken', conexion.gmail_page_token)
  }
  const pagina = await googleJson(
    `https://gmail.googleapis.com/gmail/v1/users/me/messages?${parametros}`,
    acceso,
  )
  const ids = idsMensajes(pagina.messages)
  const encolados = await registrarTareas(cliente, conexion, ids, 'historica')
  const siguiente = pagina.nextPageToken ? String(pagina.nextPageToken) : null
  const completa = !siguiente
  const ahora = new Date().toISOString()
  const cambios: Record<string, unknown> = {
    gmail_page_token: siguiente,
    gmail_history_id: completa ? historyObjetivo : conexion.gmail_history_id,
    gmail_history_objetivo: completa ? null : historyObjetivo,
    sincronizacion_inicial_completa: completa,
    error_ultima_sincronizacion: null,
    ultima_sincronizacion_exitosa: ahora,
    gmail_ultima_lectura_en: ahora,
    agenda_ultima_actualizacion_en: ahora,
    proxima_sincronizacion: new Date(
      Date.now() + (completa ? 5 : 1) * 60_000,
    ).toISOString(),
  }
  await actualizarConexion(cliente, conexion.conexion_google_id, cambios)
  return { descubiertos: ids.length, encolados, completa, origen: 'historica' as const }
}

async function sincronizacionIncremental(
  cliente: Cliente,
  conexion: ConexionSincronizable,
  acceso: string,
) {
  const parametros = new URLSearchParams({
    startHistoryId: conexion.gmail_history_id || '',
    maxResults: String(RESULTADOS_POR_PAGINA),
    historyTypes: 'messageAdded',
  })
  if (conexion.gmail_page_token) {
    parametros.set('pageToken', conexion.gmail_page_token)
  }
  const pagina = await googleJson(
    `https://gmail.googleapis.com/gmail/v1/users/me/history?${parametros}`,
    acceso,
  )
  const ids = idsMensajes((pagina.history || []).flatMap((cambio: {
    messagesAdded?: Array<{ message?: { id?: string } }>
  }) => (cambio.messagesAdded || []).map((item) => item.message)))
  const encolados = await registrarTareas(cliente, conexion, ids, 'incremental')
  const siguiente = pagina.nextPageToken ? String(pagina.nextPageToken) : null
  const historyObjetivo = String(
    pagina.historyId
      || conexion.gmail_history_objetivo
      || conexion.gmail_history_id,
  )
  const completa = !siguiente
  const ahora = new Date().toISOString()
  const cambios: Record<string, unknown> = {
    gmail_page_token: siguiente,
    gmail_history_id: completa ? historyObjetivo : conexion.gmail_history_id,
    gmail_history_objetivo: completa ? null : historyObjetivo,
    error_ultima_sincronizacion: null,
    ultima_sincronizacion_exitosa: ahora,
    gmail_ultima_lectura_en: ahora,
    agenda_ultima_actualizacion_en: ahora,
    proxima_sincronizacion: new Date(
      Date.now() + (completa ? 5 : 1) * 60_000,
    ).toISOString(),
  }
  await actualizarConexion(cliente, conexion.conexion_google_id, cambios)
  return { descubiertos: ids.length, encolados, completa, origen: 'incremental' as const }
}

function fechaHaceDias(dias: number) {
  const fecha = new Date()
  fecha.setUTCDate(fecha.getUTCDate() - dias)
  return fecha.toISOString().slice(0, 10)
}

function reconciliacionPendiente(conexion: ConexionSincronizable) {
  if (conexion.gmail_reconciliacion_desde) return true
  if (!conexion.gmail_ultima_reconciliacion_en) return true
  const ultima = new Date(conexion.gmail_ultima_reconciliacion_en).getTime()
  return !Number.isFinite(ultima) || Date.now() - ultima >= 86_400_000
}

async function reconciliarMensajesRecientes(
  cliente: Cliente,
  conexion: ConexionSincronizable,
  acceso: string,
) {
  const desde = conexion.gmail_reconciliacion_desde || fechaHaceDias(DIAS_RECONCILIACION)
  const parametros = new URLSearchParams({
    maxResults: String(RESULTADOS_RECONCILIACION),
    q: `after:${desde.replaceAll('-', '/')}`,
  })
  if (conexion.gmail_reconciliacion_page_token) {
    parametros.set('pageToken', conexion.gmail_reconciliacion_page_token)
  }
  const pagina = await googleJson(
    `https://gmail.googleapis.com/gmail/v1/users/me/messages?${parametros}`,
    acceso,
  )
  const ids = idsMensajes(pagina.messages)
  const encolados = await registrarTareas(cliente, conexion, ids, 'reconciliacion')
  const siguiente = pagina.nextPageToken ? String(pagina.nextPageToken) : null
  const completa = !siguiente
  const ahora = new Date().toISOString()
  await actualizarConexion(cliente, conexion.conexion_google_id, {
    gmail_reconciliacion_desde: completa ? null : desde,
    gmail_reconciliacion_page_token: siguiente,
    gmail_ultima_reconciliacion_en: completa ? ahora : conexion.gmail_ultima_reconciliacion_en,
    error_ultima_sincronizacion: null,
    ultima_sincronizacion_exitosa: ahora,
    gmail_ultima_lectura_en: ahora,
    agenda_ultima_actualizacion_en: ahora,
    proxima_sincronizacion: new Date(Date.now() + (completa ? 5 : 1) * 60_000).toISOString(),
  })
  return { descubiertos: ids.length, encolados, completa, origen: 'reconciliacion' as const }
}

export async function descubrirCambiosGmail(
  cliente: Cliente,
  conexion: ConexionSincronizable,
  acceso: string,
  permitirCargaHistorica = true,
) {
  if (!conexion.sincronizacion_inicial_completa || !conexion.gmail_history_id) {
    if (!permitirCargaHistorica) {
      return iniciarSoloIncremental(cliente, conexion, acceso)
    }
    return sincronizacionInicial(cliente, conexion, acceso)
  }
  if (reconciliacionPendiente(conexion)) {
    return reconciliarMensajesRecientes(cliente, conexion, acceso)
  }
  return sincronizacionIncremental(cliente, conexion, acceso)
}
