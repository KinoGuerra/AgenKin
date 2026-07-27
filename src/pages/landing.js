import { mostrarAviso, setCargando } from '../components/ui.js'
import { iniciarSesionGoogle, obtenerContextoSesion } from '../services/auth.js'
import { rutaPublica } from '../config/env.js'
import { destinoPorPerfil } from '../guards/route-guard.js'

document.querySelectorAll('[data-login]').forEach((boton) => {
  boton.addEventListener('click', async () => {
    setCargando(boton, true, 'Abriendo Google…')
    try {
      const contexto = await obtenerContextoSesion()
      if (contexto) {
        window.location.assign(rutaPublica(destinoPorPerfil(contexto.perfil)))
        return
      }
      const { error } = await iniciarSesionGoogle()
      if (error) throw error
    } catch {
      mostrarAviso('No pudimos iniciar sesión. Verificá la configuración de Google en Supabase.', 'error')
      setCargando(boton, false)
    }
  })
})
