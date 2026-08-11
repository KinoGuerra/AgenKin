import {
  clasificarCorreo,
  debeCrearVencimiento,
  ErrorIA,
  leerConfiguracionIA,
  type ClasificacionCorreo,
  type MetricasIA,
} from './ai.ts'
import { encabezado, extraerTextoCorreo } from './gmail.ts'
import { ErrorGoogle, googleJson } from './google.ts'
import {
  analizarLocalmente,
  aplicarPatron,
  aprenderPatron,
  asuntoEsPublicidad,
  buscarPatron,
  clasificacionesCoinciden,
  debeValidarEnSombra,
  evaluarPreviamente,
  huellaFuncional,
  remitenteAutenticado,
  type AnalisisLocal,
} from './patterns.ts'

const CODIGO_EN_PROCESO = 'PROCESAMIENTO_EN_CURSO'
const RECLAMO_VENCE_MS = 10 * 60 * 1_000

type Cliente = {
  from: (tabla: string) => any
  rpc: (funcion: string, argumentos?: Record<string, unknown>) => any
}

export type TareaCorreo = {
  tarea_id: string
  intentos: number
  intentos_ia: number
  origen_sincronizacion: 'incremental' | 'reconciliacion' | 'historica'
  usuario_id: string
  conexion_google_id: string
  gmail_message_id: string
}

export type ConexionCorreo = {
  id: string
  usuario_id: string
  google_email: string
  acceso: string
}

export type ResultadoProcesamiento = {
  estado: 'procesado' | 'ignorado' | 'omitido' | 'reintentar' | 'error'
  detectado: boolean
  codigoError: string | null
  retrasoSegundos: number
  tareaFinalizada: boolean
}

type CorreoExistente = {
  id: string
  estado_procesamiento: 'procesado' | 'ignorado' | 'error'
  error_procesamiento: string | null
  fecha_procesamiento: string
}

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
  cliente: Cliente,
  tarea: TareaCorreo,
) {
  const { data: existente, error: errorExistente } = await cliente
    .from('correos_procesados')
    .select('id,estado_procesamiento,error_procesamiento,fecha_procesamiento')
    .eq('conexion_google_id', tarea.conexion_google_id)
    .eq('gmail_message_id', tarea.gmail_message_id)
    .maybeSingle()
  if (errorExistente) throw errorExistente

  if (existente && !puedeReintentarse(existente as CorreoExistente)) {
    return null
  }

  const fechaProcesamiento = new Date().toISOString()
  if (!existente) {
    const { data, error } = await cliente
      .from('correos_procesados')
      .insert({
        usuario_id: tarea.usuario_id,
        conexion_google_id: tarea.conexion_google_id,
        gmail_message_id: tarea.gmail_message_id,
        estado_procesamiento: 'error',
        error_procesamiento: CODIGO_EN_PROCESO,
        fecha_procesamiento: fechaProcesamiento,
      })
      .select('id')
      .single()
    if (error?.code === '23505') return null
    if (error) throw error
    return data.id as string
  }

  const { data, error } = await cliente
    .from('correos_procesados')
    .update({
      error_procesamiento: CODIGO_EN_PROCESO,
      fecha_procesamiento: fechaProcesamiento,
    })
    .eq('id', existente.id)
    .eq('estado_procesamiento', 'error')
    .select('id')
    .maybeSingle()
  if (error) throw error
  return data?.id as string | undefined || null
}

function coincideRegla(
  regla: { campo: string; operador: string; valor: string; accion: string },
  asunto: string,
  remitente: string,
) {
  if (regla.accion !== 'ignorar') return false
  const fuente = regla.campo === 'remitente' ? remitente : asunto
  return regla.operador === 'igual'
    ? fuente.toLowerCase() === regla.valor.toLowerCase()
    : fuente.toLowerCase().includes(regla.valor.toLowerCase())
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

function clasificacionRevision(
  analisis: AnalisisLocal,
  asunto: string,
): ClasificacionCorreo {
  const fecha = analisis.fechas[0]?.valor || null
  const hora = analisis.horas.length === 1 ? analisis.horas[0].valor : null
  const monto = analisis.montos.length === 1 ? analisis.montos[0].valor : null
  return {
    relevante: Boolean(fecha || analisis.acciones.length || analisis.tieneExpresionTemporal),
    categoria: 'otro',
    grupo_resumen: 'otros',
    tipo: 'otro',
    titulo: asunto || 'Correo pendiente de revisión',
    descripcion: '',
    entidad: analisis.entidad,
    monto,
    fecha,
    hora,
    zona_horaria: 'America/Argentina/Cordoba',
    confianza: 0,
    requiere_revision: true,
    explicacion: 'El correo necesita una confirmación antes de crear un evento.',
  }
}

function candidatosRevision(analisis: AnalisisLocal) {
  return {
    fechas: analisis.fechas.map(({ indice, valor }) => ({ indice, valor })).slice(0, 21),
    horas: analisis.horas.map(({ indice, valor }) => ({ indice, valor })).slice(0, 21),
    montos: analisis.montos.map(({ indice, valor, moneda }) => ({ indice, valor, moneda })).slice(0, 21),
    acciones: analisis.acciones.slice(0, 12),
    entidad: analisis.entidad,
    referencia: analisis.referencia,
  }
}

function errorReintentable(error: unknown) {
  if (error instanceof ErrorIA) {
    return [
      'AI_LIMITE_TEMPORAL',
      'AI_TIMEOUT',
      'AI_PROVEEDOR_NO_DISPONIBLE',
      'AI_PRESUPUESTO_DIARIO',
    ]
      .includes(error.codigo)
  }
  if (error instanceof ErrorGoogle) return error.codigo === 'GOOGLE_TEMPORAL'
  return true
}

function codigoError(error: unknown) {
  if (error instanceof ErrorIA || error instanceof ErrorGoogle) return error.codigo
  return 'PROCESAMIENTO_FALLIDO'
}

function retrasoError(error: unknown) {
  if (error instanceof ErrorIA && [
    'AI_LIMITE_TEMPORAL',
    'AI_TIMEOUT',
    'AI_PROVEEDOR_NO_DISPONIBLE',
  ].includes(error.codigo)) {
    return 86_400_000
  }
  if (error instanceof ErrorIA && error.codigo === 'AI_PRESUPUESTO_DIARIO') {
    return error.reintentoDespuesMs || 900_000
  }
  if (error instanceof ErrorGoogle && error.codigo === 'GOOGLE_TEMPORAL') {
    return error.reintentoDespuesMs || 300_000
  }
  return 300_000
}

export async function procesarCorreoGmail(
  cliente: Cliente,
  tarea: TareaCorreo,
  conexion: ConexionCorreo,
): Promise<ResultadoProcesamiento> {
  const inicioProcesamiento = Date.now()
  const correoId = await reclamarCorreo(cliente, tarea)
  if (!correoId) {
    return {
      estado: 'omitido',
      detectado: false,
      codigoError: null,
      retrasoSegundos: 0,
      tareaFinalizada: false,
    }
  }

  let asunto = ''
  let remitente = ''
  let fecha = ''
  let threadId: string | null = null
  let finalizacionIncierta = false
  let intentoIaActual = tarea.intentos_ia
  const metricasIA: { valor: MetricasIA | null } = { valor: null }

  try {
    const mensaje = await googleJson(
      `https://gmail.googleapis.com/gmail/v1/users/me/messages/${tarea.gmail_message_id}?format=full`,
      conexion.acceso,
    )
    threadId = mensaje.threadId || null
    const headers = mensaje.payload?.headers || []
    asunto = encabezado(headers, 'Subject').slice(0, 500)
    remitente = encabezado(headers, 'From').slice(0, 500)
    fecha = encabezado(headers, 'Date')
    const autenticacion = encabezado(headers, 'Authentication-Results')
    const autenticado = remitenteAutenticado(autenticacion)
    const tieneListUnsubscribe = Boolean(encabezado(headers, 'List-Unsubscribe'))
    const publicidad = asuntoEsPublicidad(asunto)
    const texto = extraerTextoCorreo(mensaje.payload || {})
    const { error: errorMetadatos } = await cliente
      .from('correos_procesados')
      .update({
        gmail_thread_id: threadId,
        remitente,
        asunto,
        fecha_correo: fechaIsoSegura(fecha),
      })
      .eq('id', correoId)
    if (errorMetadatos) throw errorMetadatos

    const { data: reglas, error: errorReglas } = await cliente
      .from('reglas_usuario')
      .select('campo,operador,valor,accion')
      .eq('usuario_id', tarea.usuario_id)
      .eq('activo', true)
    if (errorReglas) throw errorReglas

    const ignorar = !publicidad && (reglas || []).some((regla: {
      campo: string
      operador: string
      valor: string
      accion: string
    }) => coincideRegla(regla, asunto, remitente))
    const analisis = await analizarLocalmente(texto, remitente, fecha)
    const { data: tieneExclusion, error: errorExclusion } = autenticado
      ? await cliente.rpc('correo_tiene_exclusion_agenda', {
          p_usuario_id: tarea.usuario_id,
          p_dominio: analisis.dominioRemitente,
          p_huella: analisis.huellaPlantilla,
        })
      : { data: false, error: null }
    if (errorExclusion) throw errorExclusion

    const exclusion = Boolean(tieneExclusion)
    const patron = publicidad || ignorar || exclusion || !autenticado
      ? null
      : await buscarPatron(cliente, tarea.usuario_id, analisis)
    const clasificacionPatron = patron ? aplicarPatron(patron, analisis) : null
    const evaluacion = ignorar || exclusion || clasificacionPatron
      ? null
      : evaluarPreviamente(analisis, asunto, autenticado, tieneListUnsubscribe)
    let validarSombra = Boolean(
      patron
      && clasificacionPatron
      && await debeValidarEnSombra(tarea.gmail_message_id, patron)
    )

    let motivoRevision: string | null = exclusion ? 'exclusion_aprendida' : null
    let origen = ignorar
      ? 'regla'
      : patron?.alcance === 'global'
        ? 'patron_global'
        : patron
          ? 'patron_personal'
          : evaluacion?.clasificacionLocal
            ? 'local'
            : 'ia'
    let clasificacion = ignorar
      ? clasificacionIgnorada()
      : exclusion
        ? clasificacionRevision(analisis, asunto)
        : clasificacionPatron || evaluacion?.clasificacionLocal || null
    let clasificacionParaAprender: ClasificacionCorreo | null = null
    let validacionPendiente: { patronId: string; coincide: boolean } | null = null

    if (!clasificacion || validarSombra) {
      let configuracionIa
      try {
        configuracionIa = leerConfiguracionIA()
      } catch {
        configuracionIa = null
      }
      if (!configuracionIa || configuracionIa.proveedor === 'none') {
        if (clasificacion && validarSombra) {
          validarSombra = false
        } else {
          clasificacion = clasificacionRevision(analisis, asunto)
          motivoRevision = configuracionIa ? 'ia_deshabilitada' : 'ia_no_configurada'
        }
      }

      if (!clasificacion || validarSombra) {
      const enteroEntorno = (nombre: string, predeterminado: number) => {
        const valor = Number(Deno.env.get(nombre))
        return Number.isInteger(valor) && valor > 0 ? valor : predeterminado
      }
      const reservaTokens = 250
      const { data: reserva, error: errorReserva } = await cliente.rpc(
        'reservar_presupuesto_ia',
        {
          p_tarea_id: tarea.tarea_id,
          p_max_solicitudes: enteroEntorno('AI_MAX_SOLICITUDES_DIA', 300),
          p_max_tokens: enteroEntorno('AI_MAX_TOKENS_DIA', 80_000),
          p_max_historicas: enteroEntorno('AI_MAX_ATRASO_DIA', 20),
          p_tokens_estimados: reservaTokens,
        },
      )
      if (errorReserva) throw errorReserva
      if (!reserva?.permitido) {
        if (clasificacion && validarSombra) {
          validarSombra = false
        } else {
          clasificacion = clasificacionRevision(analisis, asunto)
          motivoRevision = reserva?.motivo === 'intentos_agotados'
            ? 'reintentos_ia_agotados'
            : 'presupuesto_ia_agotado'
        }
      }

      if (reserva?.permitido) {
        intentoIaActual = Number(reserva.intentos_ia || (tarea.intentos_ia + 1))
        let clasificacionIA: ClasificacionCorreo
        let omitirResultadoIa = false
        try {
          clasificacionIA = await clasificarCorreo({
        asunto,
        fecha,
        dominio_remitente: analisis.dominioRemitente,
        entidad_candidata: analisis.entidad,
        acciones: analisis.acciones,
        fechas_candidatas: analisis.fechas.map((candidato) => ({
          indice: candidato.indice,
          valor: candidato.valor,
          contexto: candidato.texto,
        })),
        montos_candidatos: analisis.montos.map((candidato) => ({
          indice: candidato.indice,
          valor: candidato.valor,
          contexto: candidato.texto,
        })),
        horas_candidatas: analisis.horas.map((candidato) => ({
          indice: candidato.indice,
          valor: candidato.valor,
          contexto: candidato.texto,
        })),
        fragmento: analisis.textoRelevante,
      }, {
        registrar: (metricas) => {
          metricasIA.valor = metricas
        },
          })
        } catch (error) {
          const temporal = error instanceof ErrorIA && [
            'AI_LIMITE_TEMPORAL',
            'AI_TIMEOUT',
            'AI_PROVEEDOR_NO_DISPONIBLE',
          ].includes(error.codigo)
          if (temporal && intentoIaActual < 2) throw error
          if (clasificacion && validarSombra) {
            validarSombra = false
            omitirResultadoIa = true
            clasificacionIA = clasificacion
          } else {
            clasificacion = clasificacionRevision(analisis, asunto)
            motivoRevision = temporal
              ? 'reintentos_ia_agotados'
              : error instanceof ErrorIA && error.codigo === 'AI_CONFIGURACION_INCOMPLETA'
                ? 'ia_no_configurada'
                : 'ia_no_disponible'
            clasificacionIA = clasificacion
          }
        }

        const tokensEntrada = metricasIA.valor?.tokens_entrada || 0
        const tokensCache = metricasIA.valor?.tokens_cache || 0
        const tokensSalida = metricasIA.valor?.tokens_salida || 0
        try {
          await cliente.rpc('confirmar_consumo_ia', {
            p_tokens_no_cacheados: Math.max(0, tokensEntrada - tokensCache) + tokensSalida,
            p_tokens_reservados: reservaTokens,
          })
        } catch {
          // La reserva conservadora queda vigente si no puede confirmarse el uso.
        }

        if (omitirResultadoIa) {
          // Una validación auxiliar fallida no invalida un patrón ya seguro.
        } else if (validarSombra && patron && clasificacionPatron) {
          const coincide = clasificacionesCoinciden(clasificacionPatron, clasificacionIA)
          validacionPendiente = { patronId: patron.id, coincide }
          clasificacion = coincide ? clasificacionPatron : clasificacionIA
          if (!coincide) {
            origen = 'ia'
            clasificacionParaAprender = clasificacionIA
          }
        } else {
          clasificacion = clasificacionIA
          origen = 'ia'
          if (!motivoRevision) clasificacionParaAprender = clasificacionIA
        }
      }
      }
    }

    if (!clasificacion) throw new Error('CLASIFICACION_AUSENTE')
    if (!publicidad && !ignorar && !autenticado) {
      clasificacion = {
        ...clasificacion,
        requiere_revision: true,
      }
      motivoRevision = 'remitente_no_autenticado'
    }
    if (clasificacion.requiere_revision && !motivoRevision) {
      motivoRevision = 'clasificacion_ambigua'
    }

    const detectado = !motivoRevision && debeCrearVencimiento(clasificacion)
    const huella = detectado
      ? await huellaFuncional(clasificacion, analisis, asunto)
      : null
    finalizacionIncierta = true
    const { data: finalizado, error: errorFinalizacion } = await cliente.rpc(
      'finalizar_correo_analizado',
      {
        p_tarea_id: tarea.tarea_id,
        p_correo_id: correoId,
        p_usuario_id: tarea.usuario_id,
        p_conexion_google_id: tarea.conexion_google_id,
        p_resultado: {
          gmail_thread_id: threadId,
          remitente,
          dominio_remitente: analisis.dominioRemitente,
          asunto,
          fecha_correo: fechaIsoSegura(fecha),
          categoria: clasificacion.categoria,
          grupo_resumen: clasificacion.grupo_resumen,
          grupo_asignado_por: origen === 'local' ? 'local' : ignorar ? 'migracion' : 'ia',
          relevante: clasificacion.relevante,
          estado: ignorar ? 'ignorado' : 'procesado',
          origen_analisis: origen,
          patron_id: patron?.id || null,
          huella_plantilla: analisis.huellaPlantilla,
          huella_funcional: huella,
          tokens_entrada: metricasIA.valor?.tokens_entrada,
          tokens_cache: metricasIA.valor?.tokens_cache,
          tokens_salida: metricasIA.valor?.tokens_salida,
          duracion_ia_ms: metricasIA.valor?.duracion_ms,
          llamada_ia: Boolean(metricasIA.valor),
          duracion_procesamiento_ms: Date.now() - inicioProcesamiento,
          remitente_autenticado: autenticado,
          requiere_revision: Boolean(motivoRevision),
          motivo_revision: motivoRevision,
          candidatos_revision: motivoRevision ? candidatosRevision(analisis) : null,
          vencimiento: detectado
            ? {
                tipo: clasificacion.tipo,
                titulo: clasificacion.titulo || asunto || 'Fecha detectada',
                descripcion: clasificacion.descripcion,
                entidad: clasificacion.entidad,
                monto: clasificacion.monto,
                fecha: clasificacion.fecha,
                hora: clasificacion.hora,
                zona_horaria: clasificacion.zona_horaria,
                confianza: clasificacion.confianza,
                explicacion: clasificacion.explicacion,
                requiere_revision: clasificacion.requiere_revision,
              }
            : null,
        },
      },
    )
    finalizacionIncierta = false
    if (errorFinalizacion) throw errorFinalizacion
    if (!finalizado) {
      return {
        estado: 'omitido',
        detectado: false,
        codigoError: null,
        retrasoSegundos: 0,
        tareaFinalizada: true,
      }
    }

    if (validacionPendiente) {
      try {
        await cliente.rpc('registrar_validacion_patron', {
          p_patron_id: validacionPendiente.patronId,
          p_coincide: validacionPendiente.coincide,
        })
      } catch {
        // La validación de un patrón no invalida un correo ya finalizado.
      }
    }

    if (clasificacionParaAprender) {
      try {
        const patronAprendidoId = await aprenderPatron(
          cliente,
          tarea.usuario_id,
          analisis,
          clasificacionParaAprender,
          autenticado,
        )
        if (patronAprendidoId && !patron?.id) {
          await cliente
            .from('correos_procesados')
            .update({ patron_id: patronAprendidoId })
            .eq('id', correoId)
        }
      } catch {
        // El aprendizaje es auxiliar y no invalida un correo ya finalizado.
      }
    }

    return {
      estado: ignorar ? 'ignorado' : 'procesado',
      detectado,
      codigoError: null,
      retrasoSegundos: 0,
      tareaFinalizada: true,
    }
  } catch (error) {
    const temporalIa = error instanceof ErrorIA && [
      'AI_LIMITE_TEMPORAL',
      'AI_TIMEOUT',
      'AI_PROVEEDOR_NO_DISPONIBLE',
    ].includes(error.codigo)
    const codigo = temporalIa && intentoIaActual >= 2
      ? 'AI_REINTENTOS_AGOTADOS'
      : codigoError(error)
    if (error instanceof ErrorIA && error.codigo === 'AI_LIMITE_TEMPORAL') {
      try {
        await cliente.rpc('bloquear_proveedor_ia', {
          p_hasta: new Date(Date.now() + (error.reintentoDespuesMs || 900_000)).toISOString(),
        })
      } catch {
        // El error original sigue gobernando el reintento del correo.
      }
    }
    if (!finalizacionIncierta) {
      await cliente.from('correos_procesados').update({
        categoria: 'otro',
        grupo_resumen: 'otros',
        grupo_asignado_por: 'migracion',
        relevante: false,
        estado_procesamiento: 'error',
        error_procesamiento: codigo,
        fecha_procesamiento: new Date().toISOString(),
        origen_analisis: 'ia',
        tokens_entrada: metricasIA.valor?.tokens_entrada,
        tokens_cache: metricasIA.valor?.tokens_cache,
        tokens_salida: metricasIA.valor?.tokens_salida,
        duracion_ia_ms: metricasIA.valor?.duracion_ms,
      }).eq('id', correoId)
    }

    if (codigo !== 'AI_REINTENTOS_AGOTADOS' && errorReintentable(error)) {
      const esperaMs = finalizacionIncierta
        ? RECLAMO_VENCE_MS
        : retrasoError(error)
      return {
        estado: 'reintentar',
        detectado: false,
        codigoError: codigo,
        retrasoSegundos: Math.min(
          604_800,
          Math.max(60, Math.ceil(esperaMs / 1_000)),
        ),
        tareaFinalizada: false,
      }
    }
    return {
      estado: 'error',
      detectado: false,
      codigoError: codigo,
      retrasoSegundos: 0,
      tareaFinalizada: false,
    }
  }
}
