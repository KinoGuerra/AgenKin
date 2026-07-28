import {
  clasificarCorreo,
  debeCrearVencimiento,
  ErrorIA,
  leerConfiguracionIA,
  mensajeSeguroIA,
} from '../_shared/ai.ts'
import { encabezado, extraerTextoPlano } from '../_shared/gmail.ts'
import { googleJson, tokenAcceso } from '../_shared/google.ts'
import { envRequerida, errorSeguro, json, manejarPreflight } from '../_shared/http.ts'
import { clienteServicio, usuarioAutenticado } from '../_shared/supabase.ts'

const LOTE_MAXIMO = 20
const CORREOS_POR_EJECUCION = 2
const CODIGO_EN_PROCESO = 'PROCESAMIENTO_EN_CURSO'
const RECLAMO_VENCE_MS = 5 * 60 * 1_000

type CorreoExistente = {
  id: string
  gmail_message_id: string
  estado_procesamiento: 'procesado' | 'ignorado' | 'error'
  error_procesamiento: string | null
  fecha_procesamiento: string
}

type ClienteSupabase = Awaited<ReturnType<typeof usuarioAutenticado>>['cliente']

function fechaIsoSegura(valor: string) {
  const fecha = new Date(valor)
  return Number.isNaN(fecha.getTime()) ? null : fecha.toISOString()
}

function puedeReintentarse(correo: CorreoExistente) {
  if (correo.estado_procesamiento !== 'error') return false
  if (correo.error_procesamiento !== CODIGO_EN_PROCESO) return true
  const inicio = new Date(correo.fecha_procesamiento).getTime()
  return !Number.isFinite(inicio) || Date.now() - inicio >= RECLAMO_VENCE_MS
}

async function reclamarCorreo(
  cliente: ClienteSupabase,
  usuarioId: string,
  gmailMessageId: string,
  existente?: CorreoExistente,
) {
  const fechaProcesamiento = new Date().toISOString()
  if (!existente) {
    const { data, error } = await cliente.from('correos_procesados').insert({
      usuario_id: usuarioId,
      gmail_message_id: gmailMessageId,
      estado_procesamiento: 'error',
      error_procesamiento: CODIGO_EN_PROCESO,
      fecha_procesamiento: fechaProcesamiento,
    }).select('id').single()
    if (error?.code === '23505') return null
    if (error) throw error
    return data.id as string
  }

  let consulta = cliente
    .from('correos_procesados')
    .update({
      error_procesamiento: CODIGO_EN_PROCESO,
      fecha_procesamiento: fechaProcesamiento,
    })
    .eq('id', existente.id)
    .eq('estado_procesamiento', 'error')

  consulta = existente.error_procesamiento === CODIGO_EN_PROCESO
    ? consulta.lt('fecha_procesamiento', new Date(Date.now() - RECLAMO_VENCE_MS).toISOString())
    : existente.error_procesamiento === null
      ? consulta.is('error_procesamiento', null)
      : consulta.eq('error_procesamiento', existente.error_procesamiento)

  const { data, error } = await consulta.select('id').maybeSingle()
  if (error) throw error
  return data?.id as string | undefined || null
}

function clasificacionIgnorada() {
  return {
    relevante: false,
    categoria: 'irrelevante' as const,
    grupo_resumen: 'otros' as const,
    tipo: 'otro' as const,
    titulo: '',
    descripcion: '',
    entidad: null,
    monto: null,
    fecha: null,
    hora: null,
    zona_horaria: 'America/Argentina/Cordoba' as const,
    confianza: 1,
    requiere_revision: false,
    explicacion: 'Correo ignorado por una regla del usuario.',
  }
}

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    const body = await request.json().catch(() => ({}))
    envRequerida('GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_SECRET', 'TOKEN_ENCRYPTION_KEY')
    leerConfiguracionIA()
    const autorizacion = request.headers.get('Authorization')
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    const invocacionInterna = Boolean(
      serviceRoleKey
      && autorizacion === `Bearer ${serviceRoleKey}`
      && /^[0-9a-f-]{36}$/i.test(body.usuario_id || ''),
    )
    const contexto = invocacionInterna
      ? { usuario: { id: body.usuario_id as string }, cliente: clienteServicio() }
      : await usuarioAutenticado(request)
    const { usuario, cliente } = contexto
    const { data: habilitado } = await cliente.rpc('usuario_habilitado', { usuario: usuario.id })
    if (!habilitado) return json({ error: 'La cuenta o suscripción no está habilitada' }, 403)
    const { data: conexion, error: errorConexion } = await cliente
      .from('conexiones_google')
      .select('refresh_token_cifrado,token_iv,estado_conexion,gmail_conectado')
      .eq('usuario_id', usuario.id)
      .single()
    if (errorConexion || conexion.estado_conexion !== 'activa' || !conexion.gmail_conectado) {
      throw new Error('Configuración requerida: conectá Gmail')
    }

    const acceso = await tokenAcceso(conexion)
    const idsSolicitados = invocacionInterna && Array.isArray(body.gmail_message_ids)
      ? [...new Set(body.gmail_message_ids
        .map((id: unknown) => String(id))
        .filter((id: string) => /^[a-zA-Z0-9_-]{1,128}$/.test(id)))]
        .slice(0, CORREOS_POR_EJECUCION)
      : []
    const referencias = idsSolicitados.length
      ? idsSolicitados.map((id) => ({ id }))
      : (await googleJson(
        `https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=${LOTE_MAXIMO}&q=newer_than%3A90d`,
        acceso,
      )).messages || []
    const ids = referencias.map((mensaje: { id: string }) => mensaje.id)
    const resumen = {
      procesados: 0,
      detectados: 0,
      ignorados: 0,
      errores: 0,
      limite_alcanzado: false,
      hay_mas: false,
      reintentar: false,
    }
    if (!ids.length) {
      const ahora = new Date().toISOString()
      await cliente
        .from('conexiones_google')
        .update({
          fecha_ultima_sincronizacion: ahora,
          gmail_ultima_lectura_en: ahora,
          agenda_ultima_actualizacion_en: ahora,
        })
        .eq('usuario_id', usuario.id)
      return json(resumen)
    }

    const { data: existentes, error: errorExistentes } = await cliente
      .from('correos_procesados')
      .select('id,gmail_message_id,estado_procesamiento,error_procesamiento,fecha_procesamiento')
      .eq('usuario_id', usuario.id)
      .in('gmail_message_id', ids)
    if (errorExistentes) throw errorExistentes
    const porId = new Map((existentes as CorreoExistente[] || []).map((item) => [item.gmail_message_id, item]))
    resumen.reintentar = referencias.some((mensaje: { id: string }) => {
      const existente = porId.get(mensaje.id)
      return existente?.estado_procesamiento === 'error'
        && existente.error_procesamiento === CODIGO_EN_PROCESO
        && !puedeReintentarse(existente)
    })
    const pendientesDisponibles = referencias.filter((mensaje: { id: string }) => {
      const existente = porId.get(mensaje.id)
      return !existente || puedeReintentarse(existente)
    })
    const pendientes = pendientesDisponibles.slice(0, CORREOS_POR_EJECUCION)
    resumen.hay_mas = pendientesDisponibles.length > pendientes.length
    const { data: reglas, error: errorReglas } = await cliente
      .from('reglas_usuario')
      .select('campo,operador,valor,accion')
      .eq('usuario_id', usuario.id)
      .eq('activo', true)
    if (errorReglas) throw errorReglas

    for (const referencia of pendientes) {
      const existente = porId.get(referencia.id)
      const correoId = await reclamarCorreo(cliente, usuario.id, referencia.id, existente)
      if (!correoId) continue

      const { data: cupo, error: errorCupo } = await cliente.rpc('reservar_cupo_correo', {
        p_usuario_id: usuario.id,
      })
      if (errorCupo) throw errorCupo
      if (!cupo) {
        resumen.limite_alcanzado = true
        await cliente.from('correos_procesados').update({
          error_procesamiento: 'LIMITE_MENSUAL',
          fecha_procesamiento: new Date().toISOString(),
        }).eq('id', correoId)
        break
      }

      let asunto = ''
      let remitente = ''
      let fecha = ''
      let threadId: string | null = null
      try {
        const mensaje = await googleJson(
          `https://gmail.googleapis.com/gmail/v1/users/me/messages/${referencia.id}?format=full`,
          acceso,
        )
        threadId = mensaje.threadId || null
        const headers = mensaje.payload?.headers || []
        asunto = encabezado(headers, 'Subject').slice(0, 500)
        remitente = encabezado(headers, 'From').slice(0, 500)
        fecha = encabezado(headers, 'Date')
        const texto = extraerTextoPlano(mensaje.payload || {})
        const ignorar = (reglas || []).some((regla) => {
          if (regla.accion !== 'ignorar') return false
          const fuente = regla.campo === 'remitente' ? remitente : asunto
          return regla.operador === 'igual'
            ? fuente.toLowerCase() === regla.valor.toLowerCase()
            : fuente.toLowerCase().includes(regla.valor.toLowerCase())
        })
        const clasificacion = ignorar
          ? clasificacionIgnorada()
          : await clasificarCorreo({ asunto, remitente, fecha, texto })

        const { data: correo, error: errorCorreo } = await cliente
          .from('correos_procesados')
          .update({
            gmail_thread_id: threadId,
            remitente,
            asunto,
            fecha_correo: fechaIsoSegura(fecha),
            categoria: clasificacion.categoria,
            grupo_resumen: clasificacion.grupo_resumen,
            grupo_asignado_por: ignorar ? 'migracion' : 'ia',
            relevante: clasificacion.relevante,
            estado_procesamiento: ignorar ? 'ignorado' : 'procesado',
            error_procesamiento: null,
            fecha_procesamiento: new Date().toISOString(),
          })
          .eq('id', correoId)
          .select('id')
          .single()
        if (errorCorreo) throw errorCorreo

        if (debeCrearVencimiento(clasificacion)) {
          const { error: errorVencimiento } = await cliente.from('vencimientos_detectados').upsert({
            usuario_id: usuario.id,
            correo_id: correo.id,
            tipo: clasificacion.tipo,
            titulo: clasificacion.titulo || asunto || 'Fecha detectada',
            descripcion: clasificacion.descripcion,
            entidad: clasificacion.entidad,
            monto: clasificacion.monto,
            fecha_vencimiento: clasificacion.fecha,
            hora_vencimiento: clasificacion.hora,
            zona_horaria: clasificacion.zona_horaria,
            confianza: clasificacion.confianza,
            explicacion: clasificacion.explicacion,
            requiere_revision: clasificacion.requiere_revision,
          }, { onConflict: 'correo_id' })
          if (errorVencimiento) throw errorVencimiento
          resumen.detectados += 1
        }
        resumen.procesados += 1
        if (ignorar) resumen.ignorados += 1
      } catch (error) {
        resumen.errores += 1
        await cliente.rpc('liberar_cupo_correo', { p_usuario_id: usuario.id })
        const codigo = error instanceof ErrorIA ? error.codigo : 'PROCESAMIENTO_FALLIDO'
        await cliente.from('correos_procesados').update({
          gmail_thread_id: threadId,
          remitente,
          asunto,
          fecha_correo: fechaIsoSegura(fecha),
          categoria: 'otro',
          grupo_resumen: 'otros',
          grupo_asignado_por: 'migracion',
          relevante: false,
          estado_procesamiento: 'error',
          error_procesamiento: codigo,
          fecha_procesamiento: new Date().toISOString(),
        }).eq('id', correoId)
      }
    }

    const ahora = new Date().toISOString()
    await cliente
      .from('conexiones_google')
      .update({
        fecha_ultima_sincronizacion: ahora,
        gmail_ultima_lectura_en: ahora,
        agenda_ultima_actualizacion_en: ahora,
      })
      .eq('usuario_id', usuario.id)
    return json(resumen)
  } catch (error) {
    if (error instanceof ErrorIA) {
      return json({ error: mensajeSeguroIA(error), codigo: error.codigo }, error.estadoHttp)
    }
    return errorSeguro(error)
  }
})
