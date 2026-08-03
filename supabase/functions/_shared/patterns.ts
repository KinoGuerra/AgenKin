import {
  derivarCategoria,
  derivarDescripcion,
  derivarExplicacion,
  derivarGrupoResumen,
  derivarTitulo,
  type ClasificacionCorreo,
} from './ai.ts'

type Cliente = {
  from: (tabla: string) => any
  rpc: (funcion: string, argumentos?: Record<string, unknown>) => any
}

export type CandidatoFecha = {
  valor: string
  texto: string
  indice: number
}

export type CandidatoMonto = {
  valor: number
  texto: string
  indice: number
}

export type CandidatoHora = {
  valor: string
  texto: string
  indice: number
}

export type AnalisisLocal = {
  fechas: CandidatoFecha[]
  montos: CandidatoMonto[]
  horas: CandidatoHora[]
  entidad: string | null
  referencia: string | null
  acciones: string[]
  dominioRemitente: string
  huellaPlantilla: string
  textoRelevante: string
  tieneExpresionTemporal: boolean
}

export type PatronCorreo = {
  id: string
  alcance: 'personal' | 'global'
  selector_fecha: number
  selector_monto: number | null
  clasificacion: {
    categoria: ClasificacionCorreo['categoria']
    grupo_resumen: ClasificacionCorreo['grupo_resumen']
    tipo: ClasificacionCorreo['tipo']
    entidad?: string | null
  }
  coincidencias?: number
  discrepancias?: number
  ultima_discrepancia_en?: string | null
}

export const MAXIMO_FRAGMENTO_IA = 1_200
export const MAXIMO_CONTEXTO_CANDIDATO = 240
const ZONA_HORARIA = 'America/Argentina/Cordoba'

const MESES: Record<string, number> = {
  enero: 1,
  febrero: 2,
  marzo: 3,
  abril: 4,
  mayo: 5,
  junio: 6,
  julio: 7,
  agosto: 8,
  septiembre: 9,
  setiembre: 9,
  octubre: 10,
  noviembre: 11,
  diciembre: 12,
}

const PALABRAS_ACCION = [
  'abonar',
  'asistir',
  'entregar',
  'pagar',
  'presentar',
  'renovar',
  'responder',
  'turno',
  'vence',
  'vencimiento',
  'cita',
  'completar',
  'documentacion',
  'factura',
  'reunion',
  'renovacion',
  'ultimo dia',
]

function sinAcentos(valor: string) {
  return valor.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase()
}

function fechaIso(anio: number, mes: number, dia: number) {
  const fecha = new Date(Date.UTC(anio, mes - 1, dia))
  if (
    anio < 2000
    || anio > new Date().getUTCFullYear() + 20
    || fecha.getUTCFullYear() !== anio
    || fecha.getUTCMonth() !== mes - 1
    || fecha.getUTCDate() !== dia
  ) return null
  return `${anio}-${String(mes).padStart(2, '0')}-${String(dia).padStart(2, '0')}`
}

function fechaReferencia(valor: string | Date = new Date()) {
  const fecha = valor instanceof Date ? valor : new Date(valor)
  const segura = Number.isNaN(fecha.getTime()) ? new Date() : fecha
  const partes = new Intl.DateTimeFormat('en-US', {
    timeZone: ZONA_HORARIA,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(segura)
  const obtener = (tipo: string) => Number(partes.find((parte) => parte.type === tipo)?.value)
  return { anio: obtener('year'), mes: obtener('month'), dia: obtener('day') }
}

function sumarDias(base: { anio: number; mes: number; dia: number }, dias: number) {
  const fecha = new Date(Date.UTC(base.anio, base.mes - 1, base.dia + dias))
  return fechaIso(fecha.getUTCFullYear(), fecha.getUTCMonth() + 1, fecha.getUTCDate())
}

function contextoCercano(texto: string, posicion: number, longitud: number) {
  const inicio = Math.max(0, texto.lastIndexOf('\n', posicion - 1) + 1)
  const finLinea = texto.indexOf('\n', posicion + longitud)
  return texto.slice(inicio, finLinea < 0 ? texto.length : finLinea).trim().slice(0, MAXIMO_CONTEXTO_CANDIDATO)
}

export function extraerFechas(
  texto: string,
  referencia: string | Date = new Date(),
): CandidatoFecha[] {
  const resultados: Array<{ posicion: number; valor: string; texto: string }> = []
  const vistas = new Set<string>()
  const agregar = (posicion: number, valor: string | null, original: string) => {
    if (!valor || vistas.has(valor)) return
    vistas.add(valor)
    resultados.push({ posicion, valor, texto: contextoCercano(texto, posicion, original.length) })
  }
  const base = fechaReferencia(referencia)
  const normalizado = sinAcentos(texto)

  for (const coincidencia of texto.matchAll(/\b(\d{1,2})[/-](\d{1,2})[/-](20\d{2})\b/g)) {
    agregar(
      coincidencia.index || 0,
      fechaIso(Number(coincidencia[3]), Number(coincidencia[2]), Number(coincidencia[1])),
      coincidencia[0],
    )
  }
  for (const coincidencia of texto.matchAll(/\b(20\d{2})-(\d{2})-(\d{2})\b/g)) {
    agregar(
      coincidencia.index || 0,
      fechaIso(Number(coincidencia[1]), Number(coincidencia[2]), Number(coincidencia[3])),
      coincidencia[0],
    )
  }
  for (const coincidencia of sinAcentos(texto).matchAll(
    /\b(\d{1,2})\s+de\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre)(?:\s+de)?\s+(20\d{2})\b/g,
  )) {
    agregar(
      coincidencia.index || 0,
      fechaIso(Number(coincidencia[3]), MESES[coincidencia[2]], Number(coincidencia[1])),
      coincidencia[0],
    )
  }
  for (const coincidencia of texto.matchAll(/\b(\d{1,2})[/-](\d{1,2})(?![/-]\d)\b/g)) {
    const dia = Number(coincidencia[1])
    const mes = Number(coincidencia[2])
    let anio = base.anio
    let valor = fechaIso(anio, mes, dia)
    if (valor && valor < fechaIso(base.anio, base.mes, base.dia)!) valor = fechaIso(++anio, mes, dia)
    agregar(coincidencia.index || 0, valor, coincidencia[0])
  }
  for (const coincidencia of normalizado.matchAll(
    /\b(\d{1,2})\s+de\s+(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre)(?!\s+(?:de\s+)?20\d{2})\b/g,
  )) {
    const dia = Number(coincidencia[1])
    const mes = MESES[coincidencia[2]]
    let anio = base.anio
    let valor = fechaIso(anio, mes, dia)
    if (valor && valor < fechaIso(base.anio, base.mes, base.dia)!) valor = fechaIso(++anio, mes, dia)
    agregar(coincidencia.index || 0, valor, coincidencia[0])
  }

  const relativas = [
    { patron: /\bpasado manana\b/g, dias: 2 },
    { patron: /(?<!pasado )\bmanana\b/g, dias: 1 },
    { patron: /\bhoy\b/g, dias: 0 },
  ]
  for (const relativa of relativas) {
    for (const coincidencia of normalizado.matchAll(relativa.patron)) {
      agregar(coincidencia.index || 0, sumarDias(base, relativa.dias), coincidencia[0])
    }
  }
  for (const coincidencia of normalizado.matchAll(/\b(?:dentro de|en)\s+(\d{1,3})\s+dias?\b/g)) {
    agregar(coincidencia.index || 0, sumarDias(base, Number(coincidencia[1])), coincidencia[0])
  }
  const diasSemana: Record<string, number> = {
    domingo: 0, lunes: 1, martes: 2, miercoles: 3, jueves: 4, viernes: 5, sabado: 6,
  }
  const baseUtc = new Date(Date.UTC(base.anio, base.mes - 1, base.dia))
  for (const coincidencia of normalizado.matchAll(
    /\b(este|proximo)\s+(lunes|martes|miercoles|jueves|viernes|sabado|domingo)\b/g,
  )) {
    let dias = (diasSemana[coincidencia[2]] - baseUtc.getUTCDay() + 7) % 7
    if (coincidencia[1] === 'proximo' && dias === 0) dias = 7
    agregar(coincidencia.index || 0, sumarDias(base, dias), coincidencia[0])
  }

  return resultados
    .sort((a, b) => a.posicion - b.posicion)
    .slice(0, 21)
    .map((item, indice) => ({ ...item, indice }))
}

function numeroArgentino(valor: string) {
  const limpio = valor.replace(/[^\d.,]/g, '')
  if (!limpio) return null
  const ultimaComa = limpio.lastIndexOf(',')
  const ultimoPunto = limpio.lastIndexOf('.')
  const separadorDecimal = ultimaComa > ultimoPunto ? ',' : '.'
  const partes = limpio.split(separadorDecimal)
  const tieneDecimales = partes.length > 1 && partes.at(-1)?.length === 2
  const normalizado = tieneDecimales
    ? `${partes.slice(0, -1).join('').replace(/[.,]/g, '')}.${partes.at(-1)}`
    : limpio.replace(/[.,]/g, '')
  const numero = Number(normalizado)
  return Number.isFinite(numero) && numero >= 0 && numero <= 999_999_999_999.99
    ? numero
    : null
}

export function extraerMontos(texto: string): CandidatoMonto[] {
  const resultados: CandidatoMonto[] = []
  const vistas = new Set<number>()
  const patron = /(?:\$\s*|ARS\s*)(\d{1,3}(?:[.\s]\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)/gi
  for (const coincidencia of texto.matchAll(patron)) {
    const valor = numeroArgentino(coincidencia[1])
    if (valor === null || vistas.has(valor)) continue
    vistas.add(valor)
    resultados.push({
      valor,
      texto: contextoCercano(texto, coincidencia.index || 0, coincidencia[0].length),
      indice: resultados.length,
    })
    if (resultados.length >= 21) break
  }
  return resultados
}

export function extraerHoras(texto: string): CandidatoHora[] {
  const resultados: CandidatoHora[] = []
  const vistas = new Set<string>()
  for (const coincidencia of texto.matchAll(/\b(?:a\s+las\s+)?([01]?\d|2[0-3])[:.]([0-5]\d)\s*(?:h(?:s)?\b)?/gi)) {
    const valor = `${String(Number(coincidencia[1])).padStart(2, '0')}:${coincidencia[2]}`
    if (vistas.has(valor)) continue
    vistas.add(valor)
    resultados.push({
      valor,
      texto: contextoCercano(texto, coincidencia.index || 0, coincidencia[0].length),
      indice: resultados.length,
    })
    if (resultados.length >= 21) break
  }
  return resultados
}

export function dominioRemitente(remitente: string) {
  const coincidencia = remitente.match(/@([a-z0-9.-]+\.[a-z]{2,})/i)
  return coincidencia?.[1]?.toLowerCase().replace(/\.+$/, '') || ''
}

function entidadRemitente(_remitente: string, dominio: string) {
  const segmento = dominio.split('.')[0] || ''
  if (['example', 'gmail', 'googlemail', 'hotmail', 'outlook', 'yahoo'].includes(segmento)) {
    return null
  }
  return segmento.length >= 2
    ? `${segmento.charAt(0).toUpperCase()}${segmento.slice(1)}`
    : null
}

function referenciaCompromiso(texto: string) {
  const coincidencia = sinAcentos(texto).match(
    /\b(?:factura|comprobante|cuota|reserva|turno)\s*(?:n(?:ro|umero)?\.?|[n°º#])?\s*[:.-]?\s*([a-z]*-?\d[\w-]{1,40})\b/,
  )
  return coincidencia?.[1]?.toUpperCase() || null
}

export function remitenteAutenticado(authenticationResults: string) {
  const valor = authenticationResults.toLowerCase()
  return /\bdmarc=pass\b/.test(valor)
    && (/\bdkim=pass\b/.test(valor) || /\bspf=pass\b/.test(valor))
}

function lineasRelevantes(texto: string) {
  const vistas = new Set<string>()
  const lineas = texto.split(/\r?\n/)
    .map((linea) => linea.trim())
    .filter((linea) => {
      if (!linea || /^(?:--\s*$|saludos(?: cordiales)?[,!:]?|atentamente[,!:]?)/i.test(linea)) return false
      if (/confidencial|aviso legal|todos los derechos reservados|seguinos en|facebook|instagram|linkedin/i.test(linea)) return false
      if (/^(?:de|from):\s|^el .+ escribio:$/i.test(linea)) return false
      const clave = sinAcentos(linea)
      if (vistas.has(clave)) return false
      vistas.add(clave)
      return true
    })
  const elegidas = new Set<number>()
  lineas.forEach((linea, indice) => {
    const normalizada = sinAcentos(linea)
    const contieneFecha = /\b\d{1,2}[/-]\d{1,2}(?:[/-]20\d{2})?\b/.test(linea)
      || /\b20\d{2}-\d{2}-\d{2}\b/.test(linea)
      || Object.keys(MESES).some((mes) => normalizada.includes(mes))
      || /\b(?:hoy|manana|pasado manana|dentro de \d+ dias?|en \d+ dias?|este|proximo)\b/.test(normalizada)
    const contieneMonto = /(?:\$|ARS)\s*\d/i.test(linea)
    const contieneAccion = PALABRAS_ACCION.some((palabra) => normalizada.includes(palabra))
    if (!contieneFecha && !contieneMonto && !contieneAccion) return
    elegidas.add(Math.max(0, indice - 1))
    elegidas.add(indice)
    elegidas.add(Math.min(lineas.length - 1, indice + 1))
  })
  const relevantes = [...elegidas].sort((a, b) => a - b).map((indice) => lineas[indice])
  return (relevantes.length ? relevantes.join('\n') : '').slice(0, MAXIMO_FRAGMENTO_IA)
}

export async function huellaPlantilla(texto: string) {
  const plantilla = sinAcentos(texto)
    .replace(/\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b/g, '[email]')
    .replace(/https?:\/\/\S+/g, '[url]')
    .replace(/\b\d{1,2}[/-]\d{1,2}[/-]20\d{2}\b/g, '[fecha]')
    .replace(/\b20\d{2}-\d{2}-\d{2}\b/g, '[fecha]')
    .replace(/(?:\$|ars)\s*[\d.,\s]+/g, '[monto]')
    .replace(/\b\d+\b/g, '[n]')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 8_000)
  const datos = new TextEncoder().encode(plantilla)
  const resumen = await crypto.subtle.digest('SHA-256', datos)
  return [...new Uint8Array(resumen)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

export async function analizarLocalmente(
  texto: string,
  remitente: string,
  fechaCorreo: string | Date = new Date(),
): Promise<AnalisisLocal> {
  const dominio = dominioRemitente(remitente)
  const normalizado = sinAcentos(texto)
  return {
    fechas: extraerFechas(texto, fechaCorreo),
    montos: extraerMontos(texto),
    horas: extraerHoras(texto),
    entidad: entidadRemitente(remitente, dominio),
    referencia: referenciaCompromiso(texto),
    acciones: PALABRAS_ACCION.filter((accion) => normalizado.includes(accion)),
    dominioRemitente: dominio,
    huellaPlantilla: await huellaPlantilla(texto),
    textoRelevante: lineasRelevantes(texto),
    tieneExpresionTemporal: /\b(?:hoy|manana|pasado manana|dentro de \d+ dias?|en \d+ dias?|este|proximo|72 horas?|ultimo dia|proximamente)\b/.test(normalizado),
  }
}

export type EvaluacionPrevia = {
  requiereIa: boolean
  clasificacionLocal: ClasificacionCorreo | null
  motivo: string
  confianza: number
}

export function momentoVigente(
  fecha: string,
  hora: string | null,
  ahora: Date = new Date(),
) {
  if (hora) return new Date(`${fecha}T${hora}:00-03:00`).getTime() > ahora.getTime()
  const hoy = fechaReferencia(ahora)
  return fecha >= fechaIso(hoy.anio, hoy.mes, hoy.dia)!
}

export function asuntoEsPublicidad(asunto: string) {
  return /\(\s*publicidad\s*\)/i.test(asunto)
}

function tipoLocal(acciones: string[], asunto: string): ClasificacionCorreo['tipo'] | null {
  const texto = sinAcentos(`${asunto} ${acciones.join(' ')}`)
  const candidatos = new Set<ClasificacionCorreo['tipo']>()
  if (/\b(turno|cita)\b/.test(texto)) candidatos.add('turno')
  if (/\breunion\b/.test(texto)) candidatos.add('reunion')
  if (/\brenov/.test(texto)) candidatos.add('renovacion')
  if (/\b(documentacion|presentar)\b/.test(texto)) candidatos.add('documentacion')
  if (/\b(entregar|entrega)\b/.test(texto)) candidatos.add('entrega')
  if (/\b(responder|respuesta|completar)\b/.test(texto)) candidatos.add('respuesta')
  if (/\b(pagar|abonar|factura|vence|vencimiento)\b/.test(texto)) candidatos.add('pago')
  return candidatos.size === 1 ? [...candidatos][0] : null
}

function clasificacionLocal(
  analisis: AnalisisLocal,
  asunto: string,
  tipo: ClasificacionCorreo['tipo'],
  vigente: boolean,
) {
  const fecha = analisis.fechas[0]?.valor || null
  const hora = analisis.horas[0]?.valor || null
  const monto = analisis.montos[0]?.valor ?? null
  const entidad = analisis.entidad
  return {
    relevante: true,
    categoria: derivarCategoria(tipo, asunto),
    grupo_resumen: derivarGrupoResumen(tipo, asunto),
    tipo,
    titulo: derivarTitulo(tipo, entidad),
    descripcion: derivarDescripcion(fecha, monto, entidad),
    entidad,
    monto,
    fecha,
    hora,
    zona_horaria: ZONA_HORARIA,
    confianza: 0.97,
    requiere_revision: false,
    explicacion: vigente
      ? derivarExplicacion(tipo, false, 1)
      : 'Se detectó un compromiso ya vencido; se conserva como antecedente.',
  } satisfies ClasificacionCorreo
}

export function evaluarPreviamente(
  analisis: AnalisisLocal,
  asunto: string,
  autenticado: boolean,
  tieneListUnsubscribe = false,
  ahora: Date = new Date(),
): EvaluacionPrevia {
  if (asuntoEsPublicidad(asunto)) {
    return {
      requiereIa: false,
      clasificacionLocal: {
        relevante: false,
        categoria: 'promocion',
        grupo_resumen: 'otros',
        tipo: 'otro',
        titulo: '',
        descripcion: '',
        entidad: null,
        monto: null,
        fecha: null,
        hora: null,
        zona_horaria: ZONA_HORARIA,
        confianza: 1,
        requiere_revision: false,
        explicacion: 'El asunto identifica explícitamente el correo como publicidad.',
      },
      motivo: 'publicidad_declarada',
      confianza: 1,
    }
  }

  const tipo = tipoLocal(analisis.acciones, asunto)
  if (autenticado
    && tipo
    && analisis.fechas.length === 1
    && analisis.montos.length <= 1
    && analisis.horas.length <= 1) {
    const vigente = momentoVigente(analisis.fechas[0].valor, analisis.horas[0]?.valor || null, ahora)
    return {
      requiereIa: false,
      clasificacionLocal: clasificacionLocal(analisis, asunto, tipo, vigente),
      motivo: vigente ? 'compromiso_local_seguro' : 'compromiso_historico_claro',
      confianza: 0.97,
    }
  }

  const sinSenales = !analisis.fechas.length
    && !analisis.montos.length
    && !analisis.acciones.length
    && !analisis.tieneExpresionTemporal
  const promocional = /\b(?:newsletter|ofertas? exclusivas?|descuentos?|novedades del mes|promocion)\b/i.test(sinAcentos(asunto))
  if (sinSenales && promocional && tieneListUnsubscribe) {
    return {
      requiereIa: false,
      clasificacionLocal: {
        relevante: false,
        categoria: 'promocion',
        grupo_resumen: 'otros',
        tipo: 'otro',
        titulo: '',
        descripcion: '',
        entidad: null,
        monto: null,
        fecha: null,
        hora: null,
        zona_horaria: ZONA_HORARIA,
        confianza: 0.99,
        requiere_revision: false,
        explicacion: 'Promoción sin señales de compromiso.',
      },
      motivo: 'promocion_inequivoca',
      confianza: 0.99,
    }
  }
  return { requiereIa: true, clasificacionLocal: null, motivo: 'requiere_contexto', confianza: 0 }
}

export async function huellaFuncional(
  clasificacion: ClasificacionCorreo,
  analisis: AnalisisLocal,
  asunto: string,
) {
  if (!clasificacion.fecha || !analisis.referencia) return null
  const asuntoNormalizado = asunto.toLowerCase()
    .replace(/^(?:(?:re|rv|fw|fwd):\s*)+/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 240)
  const partes = [
    clasificacion.tipo,
    (clasificacion.entidad || '').toLowerCase(),
    clasificacion.fecha,
    clasificacion.hora || '',
    clasificacion.monto === null ? '' : clasificacion.monto.toFixed(2),
    analisis.referencia,
    asuntoNormalizado,
    analisis.huellaPlantilla,
  ]
  const resumen = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(partes.join('|')))
  return [...new Uint8Array(resumen)].map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

export async function buscarPatron(
  cliente: Cliente,
  usuarioId: string,
  analisis: AnalisisLocal,
) {
  if (!analisis.dominioRemitente || !analisis.fechas.length) return null
  const campos = 'id,alcance,selector_fecha,selector_monto,clasificacion,coincidencias,discrepancias,ultima_discrepancia_en'
  const { data: personal } = await cliente
    .from('patrones_correo')
    .select(campos)
    .eq('alcance', 'personal')
    .eq('usuario_id', usuarioId)
    .eq('dominio_remitente', analisis.dominioRemitente)
    .eq('huella_plantilla', analisis.huellaPlantilla)
    .eq('estado', 'activo')
    .maybeSingle()
  if (personal) return personal as PatronCorreo

  const { data: global } = await cliente
    .from('patrones_correo')
    .select(campos)
    .eq('alcance', 'global')
    .is('usuario_id', null)
    .eq('dominio_remitente', analisis.dominioRemitente)
    .eq('huella_plantilla', analisis.huellaPlantilla)
    .eq('estado', 'activo')
    .maybeSingle()
  return global as PatronCorreo | null
}

export function aplicarPatron(
  patron: PatronCorreo,
  analisis: AnalisisLocal,
): ClasificacionCorreo | null {
  const fecha = analisis.fechas[patron.selector_fecha]
  if (!fecha) return null
  const monto = patron.selector_monto === null
    ? null
    : analisis.montos[patron.selector_monto]?.valor ?? null
  const entidad = patron.clasificacion.entidad || analisis.entidad
  const tipo = patron.clasificacion.tipo
  return {
    relevante: true,
    categoria: patron.clasificacion.categoria,
    grupo_resumen: patron.clasificacion.grupo_resumen,
    tipo,
    titulo: derivarTitulo(tipo, entidad),
    descripcion: derivarDescripcion(fecha.valor, monto, entidad),
    entidad,
    monto,
    fecha: fecha.valor,
    hora: analisis.horas.length === 1 ? analisis.horas[0].valor : null,
    zona_horaria: ZONA_HORARIA,
    confianza: 0.96,
    requiere_revision: false,
    explicacion: derivarExplicacion(tipo, false, 1),
  }
}

export async function debeValidarEnSombra(
  gmailMessageId: string,
  patron: PatronCorreo | null = null,
  ahora = Date.now(),
) {
  const datos = new TextEncoder().encode(gmailMessageId)
  const resumen = new Uint8Array(await crypto.subtle.digest('SHA-256', datos))
  const discrepanciaReciente = patron?.ultima_discrepancia_en
    && ahora - new Date(patron.ultima_discrepancia_en).getTime() < 7 * 86_400_000
  const tasa = discrepanciaReciente
    ? 100
    : (patron?.coincidencias || 0) < 10
      ? 15
      : (patron?.coincidencias || 0) >= 100 && (patron?.discrepancias || 0) === 0
        ? 2
        : 5
  const muestra = ((resumen[0] << 8) + resumen[1]) % 100
  return muestra < tasa
}

function indiceFecha(
  fechas: CandidatoFecha[],
  valor: string | null,
) {
  return valor ? fechas.findIndex((fecha) => fecha.valor === valor) : -1
}

function indiceMonto(
  montos: CandidatoMonto[],
  valor: number | null,
) {
  if (valor === null) return null
  const indice = montos.findIndex((monto) => Math.abs(monto.valor - valor) < 0.01)
  return indice >= 0 ? indice : null
}

export async function aprenderPatron(
  cliente: Cliente,
  usuarioId: string,
  analisis: AnalisisLocal,
  clasificacion: ClasificacionCorreo,
  autenticado: boolean,
) {
  const selectorFecha = indiceFecha(analisis.fechas, clasificacion.fecha)
  if (
    !autenticado
    || !analisis.dominioRemitente
    || selectorFecha < 0
    || clasificacion.requiere_revision
    || clasificacion.confianza < 0.85
  ) return null

  const { data, error } = await cliente.rpc('registrar_evidencia_patron', {
    p_usuario_id: usuarioId,
    p_dominio_remitente: analisis.dominioRemitente,
    p_huella_plantilla: analisis.huellaPlantilla,
    p_selector_fecha: selectorFecha,
    p_selector_monto: indiceMonto(analisis.montos, clasificacion.monto),
    p_clasificacion: {
      categoria: clasificacion.categoria,
      grupo_resumen: clasificacion.grupo_resumen,
      tipo: clasificacion.tipo,
      entidad: clasificacion.entidad,
    },
  })
  if (error) throw error
  return data as string
}

export function clasificacionesCoinciden(
  patron: ClasificacionCorreo,
  ia: ClasificacionCorreo,
) {
  return patron.fecha === ia.fecha
    && patron.grupo_resumen === ia.grupo_resumen
    && patron.tipo === ia.tipo
    && (patron.monto === null
      ? ia.monto === null
      : ia.monto !== null && Math.abs(patron.monto - ia.monto) < 0.01)
}
