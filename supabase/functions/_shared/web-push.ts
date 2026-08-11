export type SuscripcionPushSegura = {
  endpoint: string
  expirationTime: number | null
  keys: { p256dh: string; auth: string }
}

const HOSTS_EXACTOS = new Set([
  'fcm.googleapis.com',
  'updates.push.services.mozilla.com',
  'web.push.apple.com',
])
const BASE64_URL = /^[A-Za-z0-9_-]+={0,2}$/

function hostPermitido(host: string) {
  return HOSTS_EXACTOS.has(host) || (
    host.endsWith('.notify.windows.com') &&
    host.length > '.notify.windows.com'.length
  )
}

export function validarSuscripcionPush(valor: unknown): SuscripcionPushSegura {
  if (!valor || typeof valor !== 'object' || Array.isArray(valor)) {
    throw new Error('SUSCRIPCION_PUSH_INVALIDA')
  }
  const entrada = valor as Record<string, unknown>
  const claves = entrada.keys as Record<string, unknown> | undefined
  const endpoint = String(entrada.endpoint || '')
  let url: URL
  try {
    url = new URL(endpoint)
  } catch {
    throw new Error('ENDPOINT_PUSH_INVALIDO')
  }
  const host = url.hostname.toLowerCase()
  const esIp = /^\d{1,3}(?:\.\d{1,3}){3}$/.test(host) || host.includes(':')
  if (
    url.protocol !== 'https:' ||
    Boolean(url.username || url.password) ||
    (url.port && url.port !== '443') ||
    esIp ||
    host === 'localhost' ||
    !hostPermitido(host) ||
    endpoint.length > 2048
  ) throw new Error('ENDPOINT_PUSH_NO_PERMITIDO')

  const p256dh = String(claves?.p256dh || '')
  const auth = String(claves?.auth || '')
  if (
    p256dh.length < 40 || p256dh.length > 256 || !BASE64_URL.test(p256dh) ||
    auth.length < 8 || auth.length > 128 || !BASE64_URL.test(auth)
  ) throw new Error('CLAVES_PUSH_INVALIDAS')

  const expirationTime = entrada.expirationTime === null ||
      entrada.expirationTime === undefined
    ? null
    : Number(entrada.expirationTime)
  if (
    expirationTime !== null &&
    (!Number.isFinite(expirationTime) || expirationTime < 0)
  ) {
    throw new Error('EXPIRACION_PUSH_INVALIDA')
  }
  return { endpoint: url.toString(), expirationTime, keys: { p256dh, auth } }
}

export async function hashEndpointPush(endpoint: string) {
  const bytes = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(endpoint),
  )
  return [...new Uint8Array(bytes)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}
