import type { ClasificacionCorreo } from './ai.ts'

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

export type AnalisisLocal = {
  fechas: CandidatoFecha[]
  montos: CandidatoMonto[]
  entidad: string | null
  acciones: string[]
  dominioRemitente: string
  huellaPlantilla: string
  textoRelevante: string
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
}

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

export function extraerFechas(texto: string): CandidatoFecha[] {
  const resultados: Array<{ posicion: number; valor: string; texto: string }> = []
  const vistas = new Set<string>()
  const agregar = (posicion: number, valor: string | null, original: string) => {
    if (!valor || vistas.has(valor)) return
    vistas.add(valor)
    resultados.push({ posicion, valor, texto: original })
  }

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
    resultados.push({ valor, texto: coincidencia[0], indice: resultados.length })
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
  if (['gmail', 'googlemail', 'hotmail', 'outlook', 'yahoo'].includes(segmento)) {
    return null
  }
  return segmento.length >= 2
    ? `${segmento.charAt(0).toUpperCase()}${segmento.slice(1)}`
    : null
}

export function remitenteAutenticado(authenticationResults: string) {
  const valor = authenticationResults.toLowerCase()
  return /\bdmarc=pass\b/.test(valor)
    && (/\bdkim=pass\b/.test(valor) || /\bspf=pass\b/.test(valor))
}

function lineasRelevantes(texto: string) {
  const lineas = texto.split(/\r?\n/).map((linea) => linea.trim()).filter(Boolean)
  const elegidas = new Set<number>()
  lineas.forEach((linea, indice) => {
    const normalizada = sinAcentos(linea)
    const contieneFecha = /\b\d{1,2}[/-]\d{1,2}[/-]20\d{2}\b/.test(linea)
      || /\b20\d{2}-\d{2}-\d{2}\b/.test(linea)
      || Object.keys(MESES).some((mes) => normalizada.includes(mes))
    const contieneMonto = /(?:\$|ARS)\s*\d/i.test(linea)
    const contieneAccion = PALABRAS_ACCION.some((palabra) => normalizada.includes(palabra))
    if (!contieneFecha && !contieneMonto && !contieneAccion) return
    elegidas.add(Math.max(0, indice - 1))
    elegidas.add(indice)
    elegidas.add(Math.min(lineas.length - 1, indice + 1))
  })
  const relevantes = [...elegidas].sort((a, b) => a - b).map((indice) => lineas[indice])
  return (relevantes.length ? relevantes.join('\n') : lineas.join('\n')).slice(0, 3_000)
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
): Promise<AnalisisLocal> {
  const dominio = dominioRemitente(remitente)
  const normalizado = sinAcentos(texto)
  return {
    fechas: extraerFechas(texto),
    montos: extraerMontos(texto),
    entidad: entidadRemitente(remitente, dominio),
    acciones: PALABRAS_ACCION.filter((accion) => normalizado.includes(accion)),
    dominioRemitente: dominio,
    huellaPlantilla: await huellaPlantilla(texto),
    textoRelevante: lineasRelevantes(texto),
  }
}

export async function buscarPatron(
  cliente: Cliente,
  usuarioId: string,
  analisis: AnalisisLocal,
) {
  if (!analisis.dominioRemitente || !analisis.fechas.length) return null
  const campos = 'id,alcance,selector_fecha,selector_monto,clasificacion'
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
  return {
    relevante: true,
    categoria: patron.clasificacion.categoria,
    grupo_resumen: patron.clasificacion.grupo_resumen,
    tipo: patron.clasificacion.tipo,
    titulo: entidad ? `${patron.clasificacion.tipo} de ${entidad}` : 'Fecha detectada',
    descripcion: 'Fecha detectada mediante un patrón verificado por AgenKin.',
    entidad,
    monto,
    fecha: fecha.valor,
    hora: null,
    zona_horaria: 'America/Argentina/Cordoba',
    confianza: 0.96,
    requiere_revision: false,
    explicacion: 'Coincide con un patrón verificado y una fecha explícita.',
  }
}

export async function debeValidarEnSombra(gmailMessageId: string) {
  const datos = new TextEncoder().encode(gmailMessageId)
  const resumen = new Uint8Array(await crypto.subtle.digest('SHA-256', datos))
  return resumen[0] % 20 === 0
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
