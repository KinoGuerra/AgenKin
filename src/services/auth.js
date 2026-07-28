import { env, rutaPublica } from '../config/env.js'
import { supabase } from './supabase.js'

export function entornoWebServido(location = window.location) {
  return location.protocol === 'http:' || location.protocol === 'https:'
}

export async function googleAuthHabilitado(fetcher = globalThis.fetch) {
  const respuesta = await fetcher(`${env.supabaseUrl}/auth/v1/settings`, {
    headers: { apikey: env.supabaseKey },
  })
  if (!respuesta.ok) throw new Error('No se pudo consultar el estado de Google Auth.')
  const configuracion = await respuesta.json()
  return configuracion?.external?.google === true
}

export async function iniciarSesionGoogle() {
  if (!entornoWebServido()) {
    throw new Error('Abrí AgenKin desde npm run dev; el acceso no funciona como archivo local.')
  }
  return supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: new URL(rutaPublica('auth-callback.html'), window.location.origin).href,
      scopes: 'openid email profile',
      queryParams: { prompt: 'select_account' },
    },
  })
}

export async function cerrarSesion() {
  const { error } = await supabase.auth.signOut()
  if (error) throw error
  window.location.assign(rutaPublica('index.html'))
}

export async function obtenerContextoSesion() {
  const { data, error } = await supabase.auth.getUser()
  if (error || !data.user) return null

  const { data: perfil, error: errorPerfil } = await supabase
    .from('perfiles')
    .select('id,nombre_completo,email,avatar_url,rol,estado_acceso,ultimo_acceso')
    .eq('id', data.user.id)
    .single()

  if (errorPerfil) throw new Error('No se pudo validar el perfil.')
  return { user: data.user, perfil }
}
