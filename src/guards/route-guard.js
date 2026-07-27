import { rutaPublica } from '../config/env.js'
import { obtenerContextoSesion } from '../services/auth.js'
import { supabase } from '../services/supabase.js'
import { rutaPermitida } from '../utils/validaciones.js'

export async function protegerRuta(pagina) {
  const contexto = await obtenerContextoSesion()
  if (!contexto) {
    window.location.replace(rutaPublica('index.html'))
    return null
  }

  if (['bloqueado', 'suspendido', 'cancelado'].includes(contexto.perfil.estado_acceso)) {
    window.location.replace(rutaPublica('cuenta-bloqueada.html'))
    return null
  }

  if (!rutaPermitida(contexto.perfil, pagina)) {
    window.location.replace(rutaPublica('app.html'))
    return null
  }

  await supabase.rpc('registrar_ultimo_acceso')
  return contexto
}

export function destinoPorPerfil(perfil) {
  if (['bloqueado', 'suspendido', 'cancelado'].includes(perfil.estado_acceso)) {
    return 'cuenta-bloqueada.html'
  }
  return perfil.rol === 'superadministrador' ? 'access.html' : 'app.html'
}
