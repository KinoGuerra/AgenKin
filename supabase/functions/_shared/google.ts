import { descifrarToken } from './crypto.ts'
import { envRequerida } from './http.ts'

export type ConexionGoogle = {
  refresh_token_cifrado: string
  token_iv: string
  calendar_id?: string | null
}

export async function tokenAcceso(conexion: ConexionGoogle) {
  const { GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET } = envRequerida('GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_SECRET')
  const refreshToken = await descifrarToken(conexion.refresh_token_cifrado, conexion.token_iv)
  const respuesta = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }),
  })
  const datos = await respuesta.json()
  if (!respuesta.ok || !datos.access_token) throw new Error('La autorización de Google venció o fue revocada')
  return datos.access_token as string
}

export async function googleJson(url: string, token: string, init: RequestInit = {}) {
  const respuesta = await fetch(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...init.headers,
    },
  })
  const datos = await respuesta.json().catch(() => ({}))
  if (!respuesta.ok) throw new Error(`Google rechazó la operación (${respuesta.status})`)
  return datos
}
