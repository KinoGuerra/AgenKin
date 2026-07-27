import { envRequerida } from './http.ts'

function base64(bytes: Uint8Array) {
  let binario = ''
  bytes.forEach((byte) => { binario += String.fromCharCode(byte) })
  return btoa(binario)
}

function desdeBase64(valor: string) {
  const normalizado = valor.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(valor.length / 4) * 4, '=')
  return Uint8Array.from(atob(normalizado), (caracter) => caracter.charCodeAt(0))
}

async function claveCifrado() {
  const { TOKEN_ENCRYPTION_KEY } = envRequerida('TOKEN_ENCRYPTION_KEY')
  const bytes = desdeBase64(TOKEN_ENCRYPTION_KEY)
  if (bytes.length !== 32) throw new Error('TOKEN_ENCRYPTION_KEY debe ser una clave base64 de 32 bytes')
  return crypto.subtle.importKey('raw', bytes, 'AES-GCM', false, ['encrypt', 'decrypt'])
}

export async function cifrarToken(token: string) {
  const iv = crypto.getRandomValues(new Uint8Array(12))
  const cifrado = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, await claveCifrado(), new TextEncoder().encode(token))
  return { token_cifrado: base64(new Uint8Array(cifrado)), iv: base64(iv) }
}

export async function descifrarToken(tokenCifrado: string, iv: string) {
  const plano = await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv: desdeBase64(iv) },
    await claveCifrado(),
    desdeBase64(tokenCifrado),
  )
  return new TextDecoder().decode(plano)
}

export async function hashEstado(estado: string) {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(estado))
  return base64(new Uint8Array(hash))
}
