function decodificarBase64Url(valor: string) {
  const normalizado = valor.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(valor.length / 4) * 4, '=')
  const binario = atob(normalizado)
  return new TextDecoder().decode(Uint8Array.from(binario, (caracter) => caracter.charCodeAt(0)))
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

export function encabezado(headers: Array<{ name: string; value: string }>, nombre: string) {
  return headers.find((header) => header.name.toLowerCase() === nombre.toLowerCase())?.value || ''
}
