import { mostrarAviso } from '../components/ui.js'
import {
  entornoWebServido,
  googleAuthHabilitado,
  iniciarSesionGoogle,
  obtenerContextoSesion,
} from '../services/auth.js'
import { rutaPublica } from '../config/env.js'
import { destinoPorPerfil } from '../guards/route-guard.js'

const botonesIngreso = [...document.querySelectorAll('[data-login]')]
const etiquetasIniciales = new Map(
  botonesIngreso.map((boton) => [
    boton,
    boton.querySelector('[data-login-label]')?.textContent || boton.textContent.trim(),
  ]),
)
const estadoIngreso = document.querySelector('[data-auth-status]')
const cabecera = document.querySelector('[data-public-header]')
const menu = document.querySelector('[data-public-menu]')
const botonMenu = document.querySelector('[data-menu-toggle]')

let contextoSesion
let estadoGoogle
let ingresoEnCurso = false

function escribirEtiqueta(boton, texto) {
  const etiqueta = boton.querySelector('[data-login-label]')
  if (etiqueta) etiqueta.textContent = texto
  else boton.textContent = texto
}

function actualizarEstado(mensaje, estado) {
  estadoIngreso.textContent = mensaje
  estadoIngreso.dataset.estado = estado
}

function actualizarBotonesPorSesion(contexto) {
  contextoSesion = contexto
  botonesIngreso.forEach((boton) => escribirEtiqueta(boton, 'Abrir mi dashboard'))
  actualizarEstado('Tu sesión está activa · podés continuar al dashboard', 'sesion')
}

function establecerCarga(cargando) {
  ingresoEnCurso = cargando
  botonesIngreso.forEach((boton) => {
    boton.disabled = cargando
    boton.setAttribute('aria-busy', String(cargando))
    if (cargando) escribirEtiqueta(boton, 'Abriendo Google…')
    else if (contextoSesion) escribirEtiqueta(boton, 'Abrir mi dashboard')
    else escribirEtiqueta(boton, etiquetasIniciales.get(boton))
  })
}

async function comprobarGoogleAuth() {
  if (!entornoWebServido()) {
    throw new Error('Abrí la versión publicada de AgenKin o ejecutá npm run dev para ingresar.')
  }
  if (!navigator.onLine) {
    throw new Error('No hay conexión a internet. Revisá tu red e intentá nuevamente.')
  }
  estadoGoogle ??= googleAuthHabilitado()
  if (!(await estadoGoogle)) {
    throw new Error('El ingreso con Google todavía no está disponible.')
  }
}

async function prepararAcceso() {
  if (!entornoWebServido()) {
    actualizarEstado('La vista como archivo es solo informativa · usá la versión web para ingresar', 'error')
    return
  }

  const contexto = await obtenerContextoSesion()
  if (contexto) {
    actualizarBotonesPorSesion(contexto)
    return
  }

  try {
    await comprobarGoogleAuth()
    actualizarEstado('Acceso disponible · AgenKin nunca solicita tu contraseña de Google', 'disponible')
  } catch (error) {
    actualizarEstado(error.message, 'error')
  }
}

async function ingresar() {
  if (ingresoEnCurso) return
  establecerCarga(true)

  try {
    if (contextoSesion) {
      window.location.assign(rutaPublica(destinoPorPerfil(contextoSesion.perfil)))
      return
    }

    if (!entornoWebServido()) await comprobarGoogleAuth()
    const contexto = await obtenerContextoSesion()
    if (contexto) {
      actualizarBotonesPorSesion(contexto)
      window.location.assign(rutaPublica(destinoPorPerfil(contexto.perfil)))
      return
    }

    await comprobarGoogleAuth()
    const { error } = await iniciarSesionGoogle()
    if (error) throw error
  } catch (error) {
    const mensaje = error instanceof Error && (
      error.message.startsWith('Abrí la versión')
      || error.message.startsWith('No hay conexión')
      || error.message.startsWith('El ingreso con Google')
    )
      ? error.message
      : 'No pudimos abrir el ingreso con Google. Intentá nuevamente.'
    mostrarAviso(mensaje, 'error')
    establecerCarga(false)
  }
}

function cerrarMenu() {
  cabecera?.removeAttribute('data-menu-open')
  botonMenu?.setAttribute('aria-expanded', 'false')
  botonMenu?.setAttribute('aria-label', 'Abrir navegación')
}

function inicializarAcordeones() {
  const acordeones = [...document.querySelectorAll('.preguntas details')]
  if (!acordeones.length || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return

  acordeones.forEach((acordeon) => {
    const resumen = acordeon.querySelector('summary')
    const contenido = acordeon.querySelector('.respuesta-frecuente')
    if (!resumen || !contenido) return

    resumen.addEventListener('click', (evento) => {
      evento.preventDefault()
      if (acordeon.dataset.animando === 'true') return

      const abrir = !acordeon.open
      acordeon.dataset.animando = 'true'
      if (abrir) acordeon.open = true
      else acordeon.dataset.cerrando = 'true'

      const alturaContenido = contenido.scrollHeight
      contenido.style.transition = 'none'
      contenido.style.maxHeight = abrir ? '0px' : `${alturaContenido}px`
      contenido.style.opacity = abrir ? '0' : '1'
      contenido.style.transform = abrir ? 'translateY(-.35rem)' : 'translateY(0)'
      void contenido.offsetHeight

      const finalizar = (eventoFinal) => {
        if (eventoFinal.target !== contenido || eventoFinal.propertyName !== 'max-height') return
        contenido.removeEventListener('transitionend', finalizar)
        if (!abrir) acordeon.open = false
        contenido.style.maxHeight = ''
        contenido.style.opacity = ''
        contenido.style.transform = ''
        contenido.style.transition = ''
        delete acordeon.dataset.cerrando
        delete acordeon.dataset.animando
      }
      contenido.addEventListener('transitionend', finalizar)
      window.requestAnimationFrame(() => {
        contenido.style.transition = ''
        window.requestAnimationFrame(() => {
          contenido.style.maxHeight = abrir ? `${alturaContenido}px` : '0px'
          contenido.style.opacity = abrir ? '1' : '0'
          contenido.style.transform = abrir ? 'translateY(0)' : 'translateY(-.35rem)'
        })
      })
    })
  })
}

botonMenu?.addEventListener('click', () => {
  const abierto = cabecera.hasAttribute('data-menu-open')
  if (abierto) {
    cerrarMenu()
    return
  }
  cabecera.setAttribute('data-menu-open', '')
  botonMenu.setAttribute('aria-expanded', 'true')
  botonMenu.setAttribute('aria-label', 'Cerrar navegación')
})

menu?.querySelectorAll('a').forEach((enlace) => enlace.addEventListener('click', cerrarMenu))

document.addEventListener('keydown', (evento) => {
  if (evento.key === 'Escape') {
    cerrarMenu()
    botonMenu?.focus()
  }
})

document.addEventListener('click', (evento) => {
  if (cabecera?.hasAttribute('data-menu-open') && !cabecera.contains(evento.target)) cerrarMenu()
})

botonesIngreso.forEach((boton) => boton.addEventListener('click', ingresar))
document.querySelector('[data-current-year]').textContent = String(new Date().getFullYear())

inicializarAcordeones()
prepararAcceso().catch(() => {
  actualizarEstado('No pudimos comprobar el acceso. Intentá nuevamente en unos minutos.', 'error')
})
