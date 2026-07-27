import { clasificarCorreo } from '../_shared/ai.ts'
import { encabezado, extraerTextoPlano } from '../_shared/gmail.ts'
import { googleJson, tokenAcceso } from '../_shared/google.ts'
import { envRequerida, errorSeguro, json, manejarPreflight } from '../_shared/http.ts'
import { usuarioAutenticado } from '../_shared/supabase.ts'

const LOTE_MAXIMO = 20

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    envRequerida('AI_API_KEY', 'AI_MODEL', 'GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_SECRET', 'TOKEN_ENCRYPTION_KEY')
    const { usuario, cliente } = await usuarioAutenticado(request)
    const { data: habilitado } = await cliente.rpc('usuario_habilitado', { usuario: usuario.id })
    if (!habilitado) return json({ error: 'La cuenta o suscripción no está habilitada' }, 403)
    const { data: conexion, error: errorConexion } = await cliente
      .from('conexiones_google')
      .select('refresh_token_cifrado,token_iv,estado_conexion')
      .eq('usuario_id', usuario.id)
      .single()
    if (errorConexion || conexion.estado_conexion !== 'activa') throw new Error('Configuración requerida: conectá Gmail')
    const acceso = await tokenAcceso(conexion)
    const listado = await googleJson(
      `https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=${LOTE_MAXIMO}&q=newer_than%3A90d`,
      acceso,
    )
    const ids = (listado.messages || []).map((mensaje: { id: string }) => mensaje.id)
    if (!ids.length) return json({ procesados: 0, detectados: 0 })
    const { data: existentes } = await cliente
      .from('correos_procesados')
      .select('gmail_message_id')
      .eq('usuario_id', usuario.id)
      .in('gmail_message_id', ids)
    const yaProcesados = new Set((existentes || []).map((item) => item.gmail_message_id))
    const pendientes = (listado.messages || []).filter((mensaje: { id: string }) => !yaProcesados.has(mensaje.id))
    const { data: reglas } = await cliente.from('reglas_usuario').select('campo,operador,valor,accion').eq('usuario_id', usuario.id).eq('activo', true)
    let procesados = 0
    let detectados = 0

    for (const referencia of pendientes) {
      const { data: cupo } = await cliente.rpc('reservar_cupo_correo', { p_usuario_id: usuario.id })
      if (!cupo) break
      const mensaje = await googleJson(
        `https://gmail.googleapis.com/gmail/v1/users/me/messages/${referencia.id}?format=full`,
        acceso,
      )
      const headers = mensaje.payload?.headers || []
      const asunto = encabezado(headers, 'Subject').slice(0, 500)
      const remitente = encabezado(headers, 'From').slice(0, 500)
      const fecha = encabezado(headers, 'Date')
      const texto = extraerTextoPlano(mensaje.payload || {}).replace(/\0/g, '').slice(0, 12000)
      const ignorar = (reglas || []).some((regla) => {
        if (regla.accion !== 'ignorar') return false
        const fuente = regla.campo === 'remitente' ? remitente : asunto
        return regla.operador === 'igual'
          ? fuente.toLowerCase() === regla.valor.toLowerCase()
          : fuente.toLowerCase().includes(regla.valor.toLowerCase())
      })
      try {
        const clasificacion = ignorar
          ? {
              relevante: false,
              categoria: 'irrelevante',
              tipo: 'otro',
              titulo: '',
              descripcion: '',
              fecha: null,
              hora: null,
              zona_horaria: 'America/Argentina/Cordoba',
              confianza: 1,
              requiere_revision: false,
              explicacion: 'Correo ignorado por una regla del usuario.',
            }
          : await clasificarCorreo({ asunto, remitente, fecha, texto })
        const { data: correo, error: errorCorreo } = await cliente.from('correos_procesados').insert({
          usuario_id: usuario.id,
          gmail_message_id: mensaje.id,
          gmail_thread_id: mensaje.threadId,
          remitente,
          asunto,
          fecha_correo: fecha ? new Date(fecha).toISOString() : null,
          categoria: clasificacion.categoria,
          relevante: clasificacion.relevante,
          estado_procesamiento: ignorar ? 'ignorado' : 'procesado',
        }).select('id').single()
        if (errorCorreo) {
          if (errorCorreo.code === '23505') continue
          throw errorCorreo
        }
        procesados += 1
        if (clasificacion.relevante && clasificacion.fecha) {
          const { error: errorVencimiento } = await cliente.from('vencimientos_detectados').insert({
            usuario_id: usuario.id,
            correo_id: correo.id,
            tipo: clasificacion.tipo,
            titulo: clasificacion.titulo || asunto || 'Fecha detectada',
            descripcion: clasificacion.descripcion,
            fecha_vencimiento: clasificacion.fecha,
            hora_vencimiento: clasificacion.hora,
            zona_horaria: clasificacion.zona_horaria,
            confianza: clasificacion.confianza,
            explicacion: clasificacion.explicacion,
            requiere_revision: clasificacion.requiere_revision,
          })
          if (errorVencimiento) throw errorVencimiento
          detectados += 1
        }
      } catch (error) {
        await cliente.from('correos_procesados').upsert({
          usuario_id: usuario.id,
          gmail_message_id: mensaje.id,
          gmail_thread_id: mensaje.threadId,
          remitente,
          asunto,
          fecha_correo: fecha ? new Date(fecha).toISOString() : null,
          categoria: 'otro',
          relevante: false,
          estado_procesamiento: 'error',
          error_procesamiento: error instanceof Error ? error.message.slice(0, 500) : 'Error de procesamiento',
        }, { onConflict: 'usuario_id,gmail_message_id' })
      }
    }
    await cliente.from('conexiones_google').update({ fecha_ultima_sincronizacion: new Date().toISOString() }).eq('usuario_id', usuario.id)
    return json({ procesados, detectados })
  } catch (error) {
    return errorSeguro(error)
  }
})
