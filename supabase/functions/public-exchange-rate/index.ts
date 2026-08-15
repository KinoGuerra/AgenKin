import { extraerVentaDolarBlue } from './dolar-blue.ts'

const FUENTE = 'https://dolarhoy.com/i/cotizaciones/dolar-blue'
const VIGENCIA_MS = 15 * 60 * 1000
const MAXIMO_HTML = 2_000_000
const headersBase = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8',
  'X-Content-Type-Options': 'nosniff',
}

type Cotizacion = { venta: number; moneda: 'ARS'; fuente: 'DolarHoy'; actualizado_en: string }
let cache: { dato: Cotizacion; expiraEn: number } | null = null

function responder(dato: unknown, status = 200, cacheControl = 'no-store') {
  return new Response(JSON.stringify(dato), {
    status,
    headers: { ...headersBase, 'Cache-Control': cacheControl },
  })
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: headersBase })
  if (request.method !== 'GET') {
    return responder({ error: 'Método no permitido' }, 405)
  }

  try {
    if (cache && cache.expiraEn > Date.now()) {
      return responder(cache.dato, 200, 'public, max-age=900')
    }

    const respuesta = await fetch(FUENTE, {
      headers: { Accept: 'text/html', 'User-Agent': 'AgenKin/1.0' },
      signal: AbortSignal.timeout(8000),
      redirect: 'error',
    })
    if (!respuesta.ok) throw new Error('Fuente no disponible')

    const html = await respuesta.text()
    if (html.length > MAXIMO_HTML) throw new Error('Respuesta demasiado extensa')

    const dato: Cotizacion = {
      venta: extraerVentaDolarBlue(html),
      moneda: 'ARS',
      fuente: 'DolarHoy',
      actualizado_en: new Date().toISOString(),
    }
    cache = { dato, expiraEn: Date.now() + VIGENCIA_MS }
    return responder(dato, 200, 'public, max-age=900')
  } catch (error) {
    console.warn('Cotización no disponible', {
      tipo: error instanceof Error ? error.name : 'ErrorDesconocido',
    })
    return responder({ error: 'La cotización no está disponible temporalmente.' }, 503)
  }
})
