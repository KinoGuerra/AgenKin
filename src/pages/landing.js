import { mostrarAviso, setCargando } from '../components/ui.js'
import {
  entornoWebServido,
  googleAuthHabilitado,
  iniciarSesionGoogle,
  obtenerContextoSesion,
} from '../services/auth.js'
import { rutaPublica } from '../config/env.js'
import { destinoPorPerfil } from '../guards/route-guard.js'

let estadoGoogle
const estadoIngreso = document.querySelector('[data-auth-status]')

async function comprobarGoogleAuth() {
  if (!entornoWebServido()) {
    throw new Error('Abrí AgenKin con “npm run dev” y usá http://localhost:5173/AgenKin/.')
  }
  estadoGoogle ??= googleAuthHabilitado()
  const habilitado = await estadoGoogle
  if (!habilitado) {
    throw new Error('Google Auth todavía no está configurado en Supabase.')
  }
  return true
}

async function mostrarEstadoGoogle() {
  try {
    await comprobarGoogleAuth()
    estadoIngreso.textContent = 'Google Auth disponible · acceso protegido por Supabase'
    estadoIngreso.dataset.estado = 'disponible'
  } catch (error) {
    estadoIngreso.textContent = error.message
    estadoIngreso.dataset.estado = 'pendiente'
  }
}

document.querySelectorAll('[data-login]').forEach((boton) => {
  boton.addEventListener('click', async () => {
    setCargando(boton, true, 'Abriendo Google…')
    try {
      if (!entornoWebServido()) await comprobarGoogleAuth()
      const contexto = await obtenerContextoSesion()
      if (contexto) {
        window.location.assign(rutaPublica(destinoPorPerfil(contexto.perfil)))
        return
      }
      await comprobarGoogleAuth()
      const { error } = await iniciarSesionGoogle()
      if (error) throw error
    } catch (error) {
      mostrarAviso(error.message || 'No pudimos iniciar sesión con Google.', 'error')
      setCargando(boton, false)
    }
  })
})

mostrarEstadoGoogle()
