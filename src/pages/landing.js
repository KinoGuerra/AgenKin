import { mostrarAviso } from '../components/ui.js'
import {
  entornoWebServido,
  googleAuthHabilitado,
  iniciarSesionGoogle,
  obtenerContextoSesion,
} from '../services/auth.js'
import { env, rutaPublica } from '../config/env.js'
import { destinoPorPerfil } from '../guards/route-guard.js'
import { supabase } from '../services/supabase.js'
import { convertirUsdAArs } from '../utils/precios.js'

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
const listaPlanes = document.querySelector('[data-planes-publicos]')
const estadoPlanes = document.querySelector('[data-planes-estado]')
const botonesMoneda = [...document.querySelectorAll('[data-moneda-vista]')]
const estadoCotizacion = document.querySelector('[data-cotizacion-estado]')

let contextoSesion
let estadoGoogle
let ingresoEnCurso = false
let monedaVista = 'USD'
let dolarBlueVenta = null

function elemento(etiqueta, clase, texto) {
  const nodo = document.createElement(etiqueta)
  if (clase) nodo.className = clase
  if (texto !== undefined) nodo.textContent = texto
  return nodo
}

function formatearPrecio(precio, moneda = 'ARS') {
  const valor = Number(precio)
  if (valor === 0) return 'Sin costo'
  try {
    return new Intl.NumberFormat('es-AR', {
      style: 'currency',
      currency: moneda,
      minimumFractionDigits: valor % 1 === 0 ? 0 : 2,
      maximumFractionDigits: moneda === 'USD' ? 2 : valor % 1 === 0 ? 0 : 2,
    }).format(valor)
  } catch {
    return `${moneda} ${valor.toLocaleString('es-AR')}`
  }
}

function precioEnMoneda(precioUsd) {
  return monedaVista === 'ARS' && dolarBlueVenta
    ? convertirUsdAArs(precioUsd, dolarBlueVenta)
    : precioUsd
}

function actualizarPreciosVisibles() {
  botonesMoneda.forEach((boton) => boton.setAttribute('aria-pressed', String(boton.dataset.monedaVista === monedaVista)))
  document.querySelectorAll('[data-precio-plan]').forEach((precio) => {
    const precioUsd = Number(precio.dataset.precioPlan)
    precio.textContent = formatearPrecio(precioEnMoneda(precioUsd), monedaVista)
  })
  document.querySelectorAll('[data-moneda-plan]').forEach((etiqueta) => {
    const tienePrecio = Number(etiqueta.dataset.precioUsd) > 0
    etiqueta.textContent = tienePrecio ? monedaVista : ''
    etiqueta.dataset.monedaPlan = tienePrecio ? monedaVista : ''
  })
}

async function cargarCotizacion() {
  const botonPesos = botonesMoneda.find((boton) => boton.dataset.monedaVista === 'ARS')
  const respuesta = await globalThis.fetch(`${env.supabaseUrl}/functions/v1/public-exchange-rate`, {
    credentials: 'omit',
    referrerPolicy: 'no-referrer',
  })
  if (!respuesta.ok) throw new Error('Cotización no disponible')
  const data = await respuesta.json()
  const venta = Number(data?.venta)
  if (!Number.isFinite(venta) || venta <= 0) {
    estadoCotizacion.textContent = 'La conversión no está disponible. Los importes continúan visibles en USD.'
    return
  }

  dolarBlueVenta = venta
  botonPesos.disabled = false
  estadoCotizacion.textContent = `Conversión orientativa · Dólar Blue Venta ${formatearPrecio(venta, 'ARS')} por USD.`
}

function crearPlan(plan) {
  const tarjeta = elemento('article')
  const esDestacado = String(plan.nombre).toLocaleLowerCase('es') === 'pro'
  tarjeta.dataset.destacado = String(esDestacado)

  const cabecera = elemento('div', 'plan__cabecera')
  cabecera.append(elemento('h3', '', plan.nombre))
  if (esDestacado) cabecera.append(elemento('span', 'plan__insignia', 'Recomendado'))

  const precio = elemento('p', 'plan__precio')
  const importe = elemento('strong', '', formatearPrecio(plan.precio, 'USD'))
  importe.dataset.precioPlan = String(Number(plan.precio))
  const moneda = elemento('span', '', Number(plan.precio) > 0 ? 'USD' : '')
  moneda.dataset.monedaPlan = Number(plan.precio) > 0 ? 'USD' : ''
  moneda.dataset.precioUsd = String(Number(plan.precio))
  precio.append(importe, moneda)

  const descripcion = elemento('p', 'plan__descripcion', plan.descripcion || 'Organizá vencimientos con las funciones esenciales de AgenKin.')
  const detalles = elemento('ul', 'plan__detalle')
  ;[
    `${plan.limite_cuentas_gmail} cuenta${plan.limite_cuentas_gmail === 1 ? '' : 's'} Gmail`,
    'Agenda interna incluida',
    'Google Calendar opcional',
  ].forEach((detalle) => detalles.append(elemento('li', '', detalle)))

  const boton = elemento('button', `boton ${esDestacado ? 'boton--primario' : 'boton--secundario'}`)
  boton.type = 'button'
  boton.dataset.login = ''
  const etiqueta = elemento('span', '', contextoSesion ? 'Abrir mi dashboard' : 'Comenzar con Google')
  etiqueta.dataset.loginLabel = ''
  boton.append(etiqueta)
  boton.addEventListener('click', ingresar)
  botonesIngreso.push(boton)
  etiquetasIniciales.set(boton, etiqueta.textContent)

  tarjeta.append(cabecera, precio, descripcion, detalles, boton)
  return tarjeta
}

async function cargarPlanesPublicos() {
  if (!listaPlanes) return
  const { data, error } = await supabase
    .from('planes')
    .select('nombre,descripcion,precio,moneda,limite_cuentas_gmail,permite_automatizacion')
    .eq('activo', true)
    .eq('visible_publico', true)
    .order('limite_cuentas_gmail')
    .order('nombre')

  listaPlanes.setAttribute('aria-busy', 'false')
  if (error || !data?.length) {
    listaPlanes.replaceChildren(elemento('p', 'planes__estado', 'No pudimos consultar los precios actuales. Podés ingresar y conocer los planes disponibles desde el portal.'))
    estadoPlanes.textContent = 'El catálogo no está disponible en este momento. Intentá nuevamente más tarde.'
    estadoCotizacion.textContent = 'La conversión se habilita cuando el catálogo está disponible.'
    return
  }
  listaPlanes.replaceChildren(...data.map(crearPlan))
  cargarCotizacion().catch(() => {
    estadoCotizacion.textContent = 'La conversión no está disponible. Los importes continúan visibles en USD.'
  })
}

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
  const estabaAbierto = cabecera?.hasAttribute('data-menu-open')
  cabecera?.removeAttribute('data-menu-open')
  botonMenu?.setAttribute('aria-expanded', 'false')
  botonMenu?.setAttribute('aria-label', 'Abrir navegación')
  if (menu && window.matchMedia('(max-width: 720px)').matches) {
    menu.setAttribute('inert', '')
    menu.setAttribute('aria-hidden', 'true')
  }
  return estabaAbierto
}

function sincronizarAccesibilidadMenu() {
  if (!menu) return
  const movil = window.matchMedia('(max-width: 720px)').matches
  const abierto = cabecera?.hasAttribute('data-menu-open')
  if (movil && !abierto) {
    menu.setAttribute('inert', '')
    menu.setAttribute('aria-hidden', 'true')
  } else {
    menu.removeAttribute('inert')
    menu.removeAttribute('aria-hidden')
  }
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
  menu.removeAttribute('inert')
  menu.removeAttribute('aria-hidden')
  cabecera.setAttribute('data-menu-open', '')
  botonMenu.setAttribute('aria-expanded', 'true')
  botonMenu.setAttribute('aria-label', 'Cerrar navegación')
})

menu?.querySelectorAll('a').forEach((enlace) => enlace.addEventListener('click', cerrarMenu))

document.addEventListener('keydown', (evento) => {
  if (evento.key === 'Escape' && cerrarMenu()) {
    botonMenu?.focus()
  }
})

document.addEventListener('click', (evento) => {
  if (cabecera?.hasAttribute('data-menu-open') && !cabecera.contains(evento.target)) cerrarMenu()
})

botonesIngreso.forEach((boton) => boton.addEventListener('click', ingresar))
botonesMoneda.forEach((boton) => boton.addEventListener('click', () => {
  if (boton.disabled || (boton.dataset.monedaVista === 'ARS' && !dolarBlueVenta)) return
  monedaVista = boton.dataset.monedaVista
  actualizarPreciosVisibles()
}))
document.querySelector('[data-current-year]').textContent = String(new Date().getFullYear())
window.addEventListener('resize', sincronizarAccesibilidadMenu)

inicializarAcordeones()
sincronizarAccesibilidadMenu()
cargarPlanesPublicos().catch(() => {
  listaPlanes?.setAttribute('aria-busy', 'false')
  listaPlanes?.replaceChildren(elemento('p', 'planes__estado', 'No pudimos consultar los precios actuales. Intentá nuevamente más tarde.'))
})
prepararAcceso().catch(() => {
  actualizarEstado('No pudimos comprobar el acceso. Intentá nuevamente en unos minutos.', 'error')
})
