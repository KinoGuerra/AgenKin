const FALLBACK_URL = 'https://kpqzwbhprqlapwhadejt.supabase.co'
const FALLBACK_KEY = 'sb_publishable_RYsbufUA91Oy-cmI4bZD4Q_Q54aE9KL'

export const env = Object.freeze({
  supabaseUrl: import.meta.env.VITE_SUPABASE_URL || FALLBACK_URL,
  supabaseKey: import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY || FALLBACK_KEY,
  baseUrl: import.meta.env.BASE_URL,
})

export function validarConfiguracionPublica(config = env) {
  const errores = []

  try {
    const url = new URL(config.supabaseUrl)
    if (url.protocol !== 'https:' || !url.hostname.endsWith('.supabase.co')) {
      errores.push('La URL de Supabase no es válida.')
    }
  } catch {
    errores.push('La URL de Supabase no es válida.')
  }

  if (!config.supabaseKey?.startsWith('sb_publishable_')) {
    errores.push('La clave pública de Supabase no es válida.')
  }

  return errores
}

export function rutaPublica(archivo = '') {
  return `${env.baseUrl}${archivo}`.replace(/([^:]\/)\/+/g, '$1')
}
