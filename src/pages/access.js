import '../components/theme.js'
import { cerrarSesion } from '../services/auth.js'
import { protegerRuta } from '../guards/route-guard.js'
import { mostrarAviso, setCargando } from '../components/ui.js'

protegerRuta('access').catch(() => mostrarAviso('No se pudo validar el acceso.', 'error'))
document.querySelector('[data-logout]').addEventListener('click', async (evento) => {
  setCargando(evento.currentTarget, true)
  try { await cerrarSesion() } catch { mostrarAviso('No se pudo cerrar la sesión.', 'error') }
})
