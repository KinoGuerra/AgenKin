import { supabase } from './supabase.js'

export async function cargarPortal(pagina = 'inicio') {
  const consultas = {}
  if (['inicio', 'configuracion'].includes(pagina)) {
    consultas.resumen = supabase.rpc('obtener_panel_usuario')
    consultas.conexion = supabase.rpc('obtener_estado_conexion_google')
  }
  if (pagina === 'correos') {
    consultas.correos = supabase.from('correos_procesados').select('id,remitente,asunto,fecha_correo,categoria,grupo_resumen,grupo_asignado_por,estado_procesamiento').order('fecha_correo', { ascending: false }).limit(50)
  }
  if (pagina === 'vencimientos') {
    consultas.vencimientos = supabase.from('vencimientos_detectados').select('id,tipo,titulo,descripcion,fecha_vencimiento,hora_vencimiento,zona_horaria,confianza,estado,requiere_revision,correos_procesados(asunto)').order('creado_en', { ascending: false }).limit(50)
  }
  if (pagina === 'reglas') {
    consultas.reglas = supabase.from('reglas_usuario').select('id,nombre,campo,operador,valor,accion,activo').order('creado_en', { ascending: false })
  }
  const entradas = Object.entries(consultas)
  const resultados = await Promise.all(entradas.map(([, consulta]) => consulta))
  const error = resultados.find((resultado) => resultado.error)?.error
  if (error) throw error
  const datos = Object.fromEntries(entradas.map(([clave], indice) => [clave, resultados[indice].data]))
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
