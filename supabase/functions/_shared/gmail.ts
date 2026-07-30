export const MAXIMO_TEXTO_CORREO = 120_000

function decodificarBase64Url(valor: string, maximoBytes = MAXIMO_TEXTO_CORREO) {
  const maximoBase64 = Math.ceil(maximoBytes * 4 / 3) + 4
  const recortado = valor.slice(0, maximoBase64)
  const util = valor.length > maximoBase64
    ? recortado.slice(0, recortado.length - (recortado.length % 4))
    : recortado
  const normalizado = util.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(util.length / 4) * 4, '=')
  const binario = atob(normalizado)
  return new TextDecoder().decode(
    Uint8Array.from(binario, (caracter) => caracter.charCodeAt(0)).slice(0, maximoBytes),
  )
}

type ParteGmail = {
  mimeType?: string
  body?: { data?: string }
  parts?: ParteGmail[]
}

export function extraerTextoPlano(payload: ParteGmail): string {
  if (payload.mimeType === 'text/plain' && payload.body?.data) return decodificarBase64Url(payload.body.data)
  for (const parte of payload.parts || []) {
    const texto = extraerTextoPlano(parte)
    if (texto) return texto
  }
  return ''
}

function decodificarEntidadesHtml(valor: string) {
  const entidades: Record<string, string> = {
    amp: '&',
    apos: "'",
    gt: '>',
    lt: '<',
    nbsp: ' ',
    quot: '"',
  }
  return valor.replace(/&(#x?[0-9a-f]+|[a-z]+);/gi, (coincidencia, entidad: string) => {
    if (entidad.startsWith('#')) {
      const hexadecimal = entidad[1]?.toLowerCase() === 'x'
      const numero = Number.parseInt(entidad.slice(hexadecimal ? 2 : 1), hexadecimal ? 16 : 10)
      return Number.isInteger(numero) && numero > 0 && numero <= 0x10ffff
        ? String.fromCodePoint(numero)
        : coincidencia
    }
    return entidades[entidad.toLowerCase()] ?? coincidencia
  })
}

export function htmlATexto(valor: string) {
  return decodificarEntidadesHtml(
    valor
      .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, ' ')
      .replace(/<(br|hr)\b[^>]*>/gi, '\n')
      .replace(/<\/(p|div|li|tr|h[1-6])\s*>/gi, '\n')
      .replace(/<[^>]+>/g, ' '),
  )
    .replace(/\r/g, '')
    .replace(/[ \t]+/g, ' ')
    .replace(/ *\n */g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

function extraerHtml(payload: ParteGmail): string {
  if (payload.mimeType === 'text/html' && payload.body?.data) {
    return htmlATexto(decodificarBase64Url(payload.body.data))
  }
  for (const parte of payload.parts || []) {
    const texto = extraerHtml(parte)
    if (texto) return texto
  }
  return ''
}

export function extraerTextoCorreo(payload: ParteGmail): string {
  return extraerTextoPlano(payload) || extraerHtml(payload)
}

export function encabezado(headers: Array<{ name: string; value: string }>, nombre: string) {
  return headers.find((header) => header.name.toLowerCase() === nombre.toLowerCase())?.value || ''
}
