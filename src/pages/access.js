import '../components/theme.js'
import { cerrarSesion } from '../services/auth.js'
import { protegerRuta } from '../guards/route-guard.js'
import { mostrarAviso, setCargando } from '../components/ui.js'

const accesoValidado = protegerRuta('access')
  .catch(() => {
    mostrarAviso('No se pudo validar el acceso.', 'error')
    return null
  })
const enlaceAdmin = document.querySelector('[data-admin-access]')

enlaceAdmin.addEventListener('click', async (evento) => {
  evento.preventDefault()
  if (enlaceAdmin.getAttribute('aria-busy') === 'true') return
  enlaceAdmin.setAttribute('aria-busy', 'true')
  enlaceAdmin.setAttribute('aria-disabled', 'true')
  try {
    if (!await accesoValidado) return
    const contextoAdmin = await protegerRuta('admin')
    if (contextoAdmin) window.location.assign(enlaceAdmin.href)
  } catch (error) {
    mostrarAviso(error.message || 'No se pudo validar el segundo factor.', 'error')
  } finally {
    enlaceAdmin.removeAttribute('aria-busy')
    enlaceAdmin.removeAttribute('aria-disabled')
  }
})

document.querySelector('[data-logout]').addEventListener('click', async (evento) => {
  setCargando(evento.currentTarget, true)
  try { await cerrarSesion() } catch { mostrarAviso('No se pudo cerrar la sesión.', 'error') }
})
