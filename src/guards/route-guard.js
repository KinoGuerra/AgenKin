import { rutaPublica } from '../config/env.js'
import { obtenerContextoSesion } from '../services/auth.js'
import { supabase } from '../services/supabase.js'
import { requiereMfaAdministrativa, rutaPermitida } from '../utils/validaciones.js'

const CLAVE_DESTINO_NOTIFICACION = 'agenkin_destino_notificacion'
const DESTINO_NOTIFICACION = /^agenda\.html\?notificacion=[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

function guardarDestinoNotificacion() {
  if (!window.location.pathname.endsWith('/agenda.html')) return
  const id = new URLSearchParams(window.location.search).get('notificacion')
  const destino = `agenda.html?notificacion=${id || ''}`
  if (DESTINO_NOTIFICACION.test(destino)) {
    window.sessionStorage.setItem(CLAVE_DESTINO_NOTIFICACION, destino)
  }
}

export async function protegerRuta(pagina) {
  const contexto = await obtenerContextoSesion()
  if (!contexto) {
    guardarDestinoNotificacion()
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

  if (pagina === 'admin') {
    const { data: nivel, error: errorNivel } = await supabase.auth.mfa
      .getAuthenticatorAssuranceLevel()
    if (errorNivel) throw new Error('No se pudo validar el segundo factor.')
    if (requiereMfaAdministrativa(pagina, nivel?.currentLevel)) {
      window.location.replace(rutaPublica('mfa.html?destino=admin.html'))
      return null
    }
  }

  await supabase.rpc('registrar_ultimo_acceso')
  return contexto
}

export function destinoPorPerfil(perfil) {
  if (['bloqueado', 'suspendido', 'cancelado'].includes(perfil.estado_acceso)) {
    return 'cuenta-bloqueada.html'
  }
  if (perfil.rol === 'superadministrador') return 'access.html'
  const pendiente = window.sessionStorage.getItem(CLAVE_DESTINO_NOTIFICACION) || ''
  if (DESTINO_NOTIFICACION.test(pendiente)) {
    window.sessionStorage.removeItem(CLAVE_DESTINO_NOTIFICACION)
    return pendiente
  }
  return 'app.html'
}
