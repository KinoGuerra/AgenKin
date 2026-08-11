import { supabase } from './supabase.js'
import { fechaActualIso } from '../utils/fechas.js'

export async function cargarPortal(pagina = 'inicio', opciones = {}) {
  const consultas = {}
  if (['inicio', 'configuracion'].includes(pagina)) {
    consultas.resumen = supabase.rpc('obtener_panel_usuario')
    consultas.conexion = supabase.rpc('obtener_estado_conexion_google')
  }
  if (pagina === 'correos') {
    const paginaCorreos = Math.max(1, Number(opciones.paginaCorreos) || 1)
    const desde = (paginaCorreos - 1) * 25
    consultas.conexion = supabase.rpc('obtener_estado_conexion_google')
    consultas.correos = supabase
      .from('correos_procesados')
      .select('id,conexion_google_id,gmail_message_id,gmail_thread_id,remitente,asunto,fecha_correo,categoria,grupo_resumen,grupo_asignado_por,relevante,estado_procesamiento,error_procesamiento,detalle_compactado,duplicado_funcional,requiere_revision,motivo_revision,candidatos_revision,remitente_autenticado,vencimientos_detectados!vencimientos_correo_usuario_fkey(titulo,descripcion,fecha_vencimiento,monto)', { count: 'exact' })
      .order('fecha_correo', { ascending: false, nullsFirst: false })
      .range(desde, desde + 24)
  }
  if (pagina === 'vencimientos') {
    consultas.vencimientos = supabase
      .from('vencimientos_detectados')
      .select('id,correo_id,tipo,titulo,descripcion,fecha_vencimiento,hora_vencimiento,zona_horaria,confianza,estado,requiere_revision,correos_procesados!vencimientos_correo_usuario_fkey(asunto),eventos_calendar!eventos_vencimiento_usuario_fkey(estado_google,google_event_id,error_google,estado_sincronizacion)')
      .not('correo_id', 'is', null)
      .gte('fecha_vencimiento', fechaActualIso())
      .in('estado', ['pendiente', 'confirmado', 'evento_creado', 'error'])
      .order('fecha_vencimiento', { ascending: true })
      .limit(50)
  }
  if (pagina === 'reglas') {
    consultas.reglas = supabase.from('reglas_usuario').select('id,nombre,campo,operador,valor,accion,activo').order('creado_en', { ascending: false })
  }
  const entradas = Object.entries(consultas)
  const resultados = await Promise.all(entradas.map(([, consulta]) => consulta))
  const error = resultados.find((resultado) => resultado.error)?.error
  if (error) throw error
  const datos = Object.fromEntries(entradas.map(([clave], indice) => [clave, resultados[indice].data]))
  if (pagina === 'correos') {
    const indiceCorreos = entradas.findIndex(([clave]) => clave === 'correos')
    datos.correos_total = resultados[indiceCorreos]?.count || 0
    const cuentas = Array.isArray(datos.conexion?.gmail?.cuentas) ? datos.conexion.gmail.cuentas : []
    const emailsPorConexion = new Map(cuentas.map((cuenta) => [cuenta.id, cuenta.email]))
    datos.correos = datos.correos.map((correo) => ({
      ...correo,
      google_email: emailsPorConexion.get(correo.conexion_google_id) || null,
    }))
  }
  return { vencimientos: [], correos: [], reglas: [], ...datos }
}

export async function cargarEventosAgenda(desde, hasta) {
  const { data, error } = await supabase
    .from('eventos_calendar')
    .select('id,titulo,descripcion,fecha_evento,zona_horaria,es_dia_completo,estado_google,google_event_id,estado_sincronizacion')
    .gte('fecha_evento', desde)
    .lt('fecha_evento', hasta)
    .neq('estado_sincronizacion', 'eliminado')
    .order('fecha_evento')
  if (error) throw error
  return data
}
