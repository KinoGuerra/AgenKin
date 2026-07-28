import '../components/theme.js'
import { mostrarAviso } from '../components/ui.js'
import { rutaPublica } from '../config/env.js'
import { destinoPorPerfil } from '../guards/route-guard.js'
import { obtenerContextoSesion } from '../services/auth.js'

async function completarIngreso() {
  try {
    const contexto = await obtenerContextoSesion()
    if (!contexto) throw new Error('Sesión ausente')
    window.location.replace(rutaPublica(destinoPorPerfil(contexto.perfil)))
  } catch {
    document.querySelector('[data-estado]').textContent = 'No fue posible validar la sesión.'
    document.querySelector('[data-volver]').classList.remove('oculto')
    mostrarAviso('El acceso falló o fue cancelado. Intentá nuevamente.', 'error')
  }
}

completarIngreso()
