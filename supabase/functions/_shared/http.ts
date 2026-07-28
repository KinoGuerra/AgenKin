export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
}

export function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: corsHeaders })
}

export function manejarPreflight(request: Request) {
  return request.method === 'OPTIONS' ? new Response('ok', { headers: corsHeaders }) : null
}

export function errorSeguro(error: unknown, status = 400) {
  const mensaje = error instanceof Error ? error.message : 'La operación no pudo completarse'
  return json({ error: mensaje }, status)
}

export function envRequerida(...nombres: string[]) {
  const valores = Object.fromEntries(nombres.map((nombre) => [nombre, Deno.env.get(nombre)]))
  const faltantes = nombres.filter((nombre) => !valores[nombre])
  if (faltantes.length) throw new Error(`Configuración requerida: ${faltantes.join(', ')}`)
  return valores as Record<string, string>
}

export function appUrlSegura() {
  const { APP_PUBLIC_URL } = envRequerida('APP_PUBLIC_URL')
  const url = new URL(APP_PUBLIC_URL)
  if (url.protocol !== 'https:' && url.hostname !== 'localhost') throw new Error('APP_PUBLIC_URL no es segura')
  url.pathname = url.pathname.replace(/\/?$/, '/')
  return url
}
