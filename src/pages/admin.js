import '../components/theme.js'
import { crearCelda, estadoVacio, mostrarAviso, setCargando } from '../components/ui.js'
import { protegerRuta } from '../guards/route-guard.js'
import { cerrarSesion } from '../services/auth.js'
import { invocarFuncion } from '../services/edge.js'
import { formatearFecha } from '../utils/fechas.js'
import { validarAccionAdministrativa } from '../utils/validaciones.js'

let pagina = 1
let administradorId = null
const tbody = document.querySelector('[data-usuarios]')
const dialogo = document.querySelector('[data-admin-dialog]')
const formulario = document.querySelector('[data-admin-form]')
const filtros = document.querySelector('[data-filtros]')
const botonMenu = document.querySelector('[data-menu]')
const ACCIONES = [
  ['activar', 'Activar acceso'],
  ['suspender', 'Suspender acceso'],
  ['bloquear', 'Bloquear acceso'],
  ['desbloquear', 'Desbloquear acceso'],
  ['cambiar_plan', 'Cambiar plan'],
  ['extender_prueba', 'Extender prueba'],
  ['cambiar_vencimiento', 'Cambiar vencimiento'],
  ['registrar_observacion', 'Registrar observación'],
  ['cancelar_suscripcion', 'Cancelar suscripción'],
]

function accionesDisponibles(usuario) {
  const accionesEstado = {
    activo: new Set(['suspender', 'bloquear']),
    suspendido: new Set(['activar', 'bloquear']),
    bloqueado: new Set(['desbloquear']),
    cancelado: new Set(['activar', 'bloquear']),
  }
  const accionesAcceso = new Set(['activar', 'suspender', 'bloquear', 'desbloquear'])
  const prohibidasEnCuentaPropia = new Set(['suspender', 'bloquear', 'cancelar_suscripcion'])

  return ACCIONES.filter(([valor]) => {
    if (usuario.id === administradorId && prohibidasEnCuentaPropia.has(valor)) return false
    if (!accionesAcceso.has(valor)) return true
    return accionesEstado[usuario.estado_acceso]?.has(valor) ?? true
  })
}

function obtenerIniciales(nombre, email) {
  const partes = (nombre || '').trim().split(/\s+/).filter(Boolean)
  if (partes.length) return partes.slice(0, 2).map((parte) => parte[0]).join('').toUpperCase()
  return (email || 'SA').slice(0, 2).toUpperCase()
}

function renderPerfil(perfil) {
  const nombre = perfil.nombre_completo || 'Administrador'
  const email = perfil.email || 'Cuenta superadministradora'
  const imagen = document.querySelector('[data-admin-avatar]')
  const iniciales = document.querySelector('[data-admin-iniciales]')

  document.querySelector('[data-admin-nombre]').textContent = nombre
  document.querySelector('[data-admin-email]').textContent = email
  iniciales.textContent = obtenerIniciales(nombre, email)

  if (!perfil.avatar_url) return

  try {
    const url = new URL(perfil.avatar_url)
    if (url.protocol !== 'https:') return
    imagen.src = url.href
    imagen.alt = `Foto de ${nombre}`
    imagen.hidden = false
    iniciales.hidden = true
    imagen.addEventListener('error', () => {
      imagen.hidden = true
      iniciales.hidden = false
    }, { once: true })
  } catch {
    // Las iniciales mantienen el perfil identificable si la URL no es válida.
  }
}

function cerrarMenu() {
  document.body.classList.remove('menu-abierto')
  botonMenu.setAttribute('aria-expanded', 'false')
  botonMenu.setAttribute('aria-label', 'Abrir menú')
}

function renderUsuarios(usuarios) {
  tbody.replaceChildren()
  if (!usuarios.length) {
    const fila = document.createElement('tr')
    const celda = crearCelda('No hay usuarios que coincidan con los filtros.')
    celda.colSpan = 8
    fila.append(celda)
    tbody.append(fila)
    return
  }

  usuarios.forEach((usuario) => {
    const fila = document.createElement('tr')
    const identidad = document.createElement('td')
    const nombre = document.createElement('strong')
    nombre.textContent = usuario.nombre_completo || 'Sin nombre'
    const email = document.createElement('small')
    email.textContent = usuario.email
    identidad.append(nombre)
    if (usuario.id === administradorId) {
      const cuentaActual = document.createElement('span')
      cuentaActual.className = 'etiqueta-cuenta'
      cuentaActual.textContent = 'Tu cuenta'
      identidad.append(cuentaActual)
    }
    identidad.append(email)
    fila.append(
      identidad,
      crearCelda(usuario.plan || 'Sin plan'),
      crearCelda(usuario.estado_acceso),
      crearCelda(usuario.estado_suscripcion || '—'),
      crearCelda(formatearFecha(usuario.fecha_vencimiento)),
      crearCelda(`${usuario.cuentas_gmail || 0}/${usuario.limite_cuentas_gmail || '—'} cuentas`),
      crearCelda(formatearFecha(usuario.ultimo_acceso)),
    )

    const acciones = document.createElement('td')
    const selector = document.createElement('select')
    selector.setAttribute('aria-label', `Acción para ${usuario.email}`)
    accionesDisponibles(usuario).forEach(([valor, texto]) => selector.add(new Option(texto, valor)))

    const aplicar = document.createElement('button')
    aplicar.className = 'boton boton--mini'
    aplicar.textContent = 'Gestionar'
    aplicar.addEventListener('click', () => abrirAccion(usuario, selector.value))
    acciones.append(selector, aplicar)
    fila.append(acciones)
    tbody.append(fila)
  })
}

function renderAuditoria(items) {
  const contenedor = document.querySelector('[data-auditoria]')
  contenedor.replaceChildren()
  contenedor.classList.remove('lista-vacia')
  contenedor.classList.toggle('lista-auditoria', Boolean(items.length))
  if (!items.length) return contenedor.append(estadoVacio('Todavía no hay acciones administrativas registradas.'))

  items.forEach((item) => {
    const tarjeta = document.createElement('article')
    const titulo = document.createElement('strong')
    titulo.textContent = item.accion
    const detalle = document.createElement('span')
    detalle.textContent = `${item.administrador_email || 'Administrador'} · ${formatearFecha(item.creado_en)} · ${item.detalle || 'Sin detalle'}`
    tarjeta.append(titulo, detalle)
    contenedor.append(tarjeta)
  })
}

function abrirAccion(usuario, accion) {
  formulario.reset()
  formulario.elements.usuario_id.value = usuario.id
  formulario.elements.accion.value = accion
  const etiqueta = ACCIONES.find(([valor]) => valor === accion)?.[1] || 'Gestionar usuario'
  const nombre = usuario.nombre_completo || usuario.email
  document.querySelector('[data-admin-titulo]').textContent = etiqueta
  document.querySelector('[data-admin-confirmacion]').textContent = `Vas a aplicar “${etiqueta.toLowerCase()}” a ${nombre}. El cambio quedará registrado.`
  document.querySelector('[data-campo-plan]').classList.toggle('oculto', accion !== 'cambiar_plan')
  document.querySelector('[data-campo-fecha]').classList.toggle('oculto', !['extender_prueba', 'cambiar_vencimiento'].includes(accion))
  dialogo.showModal()
}

async function cargar() {
  const valores = Object.fromEntries(new FormData(filtros))
  const datos = await invocarFuncion('admin-manage-user', { accion: 'listar', pagina, ...valores })
  const selectorPlanes = formulario.elements.plan_id
  selectorPlanes.replaceChildren()
  ;(datos.planes || []).forEach((plan) => selectorPlanes.add(new Option(plan.nombre, plan.id)))

  Object.entries(datos.metricas || {}).forEach(([nombre, valor]) => {
    const elemento = document.querySelector(`[data-metrica="${nombre}"]`)
    if (elemento) elemento.textContent = valor
  })
  if (datos.metricas?.alerta_almacenamiento) {
    const megabytes = Math.round(Number(datos.metricas.bytes_base || 0) / 1024 / 1024)
    mostrarAviso(
      `La base usa aproximadamente ${megabytes} MB. Revisá retención y el paso a Supabase Pro.`,
      'advertencia',
    )
  }

  renderUsuarios(datos.usuarios || [])
  renderAuditoria(datos.auditoria || [])
  document.querySelector('[data-pagina]').textContent = `${pagina} de ${datos.paginas || 1}`
  document.querySelector('[data-pagina-anterior]').disabled = pagina <= 1
  document.querySelector('[data-pagina-siguiente]').disabled = pagina >= (datos.paginas || 1)
  document.querySelector('[data-actualizado]').textContent = `Actualizado ${new Intl.DateTimeFormat('es-AR', {
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date())}`
}

async function iniciar() {
  try {
    const contexto = await protegerRuta('admin')
    if (!contexto) return
    administradorId = contexto.user.id
    renderPerfil(contexto.perfil)
    document.documentElement.classList.remove('ruta-protegida-pendiente')
    await cargar()
  } catch (error) {
    document.documentElement.classList.remove('ruta-protegida-pendiente')
    mostrarAviso(error.message || 'No se pudo cargar el panel administrativo.', 'error')
  }
}

botonMenu.addEventListener('click', (evento) => {
  const abierto = document.body.classList.toggle('menu-abierto')
  evento.currentTarget.setAttribute('aria-expanded', String(abierto))
  evento.currentTarget.setAttribute('aria-label', abierto ? 'Cerrar menú' : 'Abrir menú')
})
document.querySelector('[data-menu-overlay]').addEventListener('click', cerrarMenu)
document.querySelectorAll('.barra-lateral nav a').forEach((enlace) => enlace.addEventListener('click', cerrarMenu))
document.addEventListener('keydown', (evento) => {
  if (evento.key === 'Escape' && document.body.classList.contains('menu-abierto')) cerrarMenu()
})
document.querySelector('[data-logout]').addEventListener('click', async () => {
  try {
    await cerrarSesion()
  } catch {
    mostrarAviso('No se pudo cerrar la sesión.', 'error')
  }
})
filtros.addEventListener('submit', async (evento) => {
  evento.preventDefault()
  pagina = 1
  const boton = evento.submitter
  setCargando(boton, true, 'Filtrando…')
  try {
    await cargar()
  } catch (error) {
    mostrarAviso(error.message, 'error')
  } finally {
    setCargando(boton, false)
  }
})
document.querySelector('[data-limpiar-filtros]').addEventListener('click', async (evento) => {
  filtros.reset()
  pagina = 1
  setCargando(evento.currentTarget, true, 'Limpiando…')
  try {
    await cargar()
  } catch (error) {
    mostrarAviso(error.message, 'error')
  } finally {
    setCargando(evento.currentTarget, false)
  }
})
document.querySelector('[data-pagina-anterior]').addEventListener('click', async () => {
  pagina -= 1
  await cargar()
})
document.querySelector('[data-pagina-siguiente]').addEventListener('click', async () => {
  pagina += 1
  await cargar()
})
formulario.addEventListener('submit', async (evento) => {
  if (evento.submitter?.value === 'cancel') return
  evento.preventDefault()
  const boton = evento.submitter
  const datos = Object.fromEntries(new FormData(formulario))
  const errores = validarAccionAdministrativa(datos)
  if (Object.keys(errores).length) return mostrarAviso(Object.values(errores)[0], 'error')

  setCargando(boton, true, 'Aplicando…')
  try {
    const resultado = await invocarFuncion('admin-manage-user', datos)
    dialogo.close()
    mostrarAviso(
      resultado?.advertencia
        || 'La acción se aplicó y quedó registrada en auditoría.',
      resultado?.advertencia ? 'advertencia' : 'exito',
    )
    await cargar()
  } catch (error) {
    mostrarAviso(error.message, 'error')
  } finally {
    setCargando(boton, false)
  }
})

iniciar()
