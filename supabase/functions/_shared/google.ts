import { descifrarToken } from './crypto.ts'
import { envRequerida } from './http.ts'

const TIMEOUT_GOOGLE_MS = 20_000

export type ConexionGoogle = {
  refresh_token_cifrado: string
  token_iv: string
  calendar_id?: string | null
}

export class ErrorGoogle extends Error {
  status: number
  codigo: 'GOOGLE_TEMPORAL' | 'GOOGLE_TOKEN_VENCIDO' | 'GOOGLE_RECHAZADO'
  reintentoDespuesMs: number | null

  constructor(
    status: number,
    codigo: ErrorGoogle['codigo'] = status === 401
      ? 'GOOGLE_TOKEN_VENCIDO'
      : status === 0 || status === 408 || status === 429 || status >= 500
        ? 'GOOGLE_TEMPORAL'
        : 'GOOGLE_RECHAZADO',
    reintentoDespuesMs: number | null = null,
  ) {
    super(`Google rechazó la operación (${status})`)
    this.name = 'ErrorGoogle'
    this.status = status
    this.codigo = codigo
    this.reintentoDespuesMs = reintentoDespuesMs
  }
}

function retryAfterMs(valor: string | null) {
  if (!valor) return null
  const segundos = Number(valor)
  if (Number.isFinite(segundos) && segundos >= 0) return segundos * 1_000
  const fecha = Date.parse(valor)
  return Number.isFinite(fecha) ? Math.max(0, fecha - Date.now()) : null
}

export async function fetchGoogle(url: string, init: RequestInit = {}) {
  try {
    return await fetch(url, {
      ...init,
      signal: init.signal || AbortSignal.timeout(TIMEOUT_GOOGLE_MS),
    })
  } catch (error) {
    if (error instanceof ErrorGoogle) throw error
    throw new ErrorGoogle(0, 'GOOGLE_TEMPORAL')
  }
}

export async function tokenAcceso(conexion: ConexionGoogle) {
  const { GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET } = envRequerida('GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_SECRET')
  const refreshToken = await descifrarToken(conexion.refresh_token_cifrado, conexion.token_iv)
  const respuesta = await fetchGoogle('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }),
  })
  const datos = await respuesta.json().catch(() => ({}))
  if (!respuesta.ok || !datos.access_token) {
    const tokenVencido = respuesta.status === 400 && datos?.error === 'invalid_grant'
    throw new ErrorGoogle(
      tokenVencido ? 401 : respuesta.status,
      tokenVencido ? 'GOOGLE_TOKEN_VENCIDO' : undefined,
      retryAfterMs(respuesta.headers.get('retry-after')),
    )
  }
  return datos.access_token as string
}

export async function googleJson(url: string, token: string, init: RequestInit = {}) {
  const respuesta = await fetchGoogle(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...init.headers,
    },
  })
  const datos = await respuesta.json().catch(() => ({}))
  if (!respuesta.ok) {
    throw new ErrorGoogle(
      respuesta.status,
      undefined,
      retryAfterMs(respuesta.headers.get('retry-after')),
    )
  }
  return datos
}
