import '../components/theme.js'
import { crearCelda, estadoVacio, mostrarAviso, setCargando } from '../components/ui.js'
import { protegerRuta } from '../guards/route-guard.js'
import { cerrarSesion } from '../services/auth.js'
import { invocarFuncion } from '../services/edge.js'
import { formatearFecha } from '../utils/fechas.js'
import { validarAccionAdministrativa } from '../utils/validaciones.js'

let pagina = 1
const tbody = document.querySelector('[data-usuarios]')
const dialogo = document.querySelector('[data-admin-dialog]')
const formulario = document.querySelector('[data-admin-form]')

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
    identidad.append(nombre, email)
    fila.append(
      identidad,
      crearCelda(usuario.plan || 'Sin plan'),
      crearCelda(usuario.estado_acceso),
      crearCelda(usuario.estado_suscripcion || '—'),
      crearCelda(formatearFecha(usuario.fecha_vencimiento)),
      crearCelda(`${usuario.correos_procesados || 0}/${usuario.limite_correos_mensuales || '—'}`),
      crearCelda(formatearFecha(usuario.ultimo_acceso)),
    )
    const acciones = document.createElement('td')
    const selector = document.createElement('select')
    selector.setAttribute('aria-label', `Acción para ${usuario.email}`)
    ;[
      ['activar', 'Activar'],
      ['suspender', 'Suspender'],
      ['bloquear', 'Bloquear'],
      ['desbloquear', 'Desbloquear'],
      ['cambiar_plan', 'Cambiar plan'],
      ['extender_prueba', 'Extender prueba'],
      ['cambiar_vencimiento', 'Cambiar vencimiento'],
      ['registrar_observacion', 'Registrar observación'],
      ['cancelar_suscripcion', 'Cancelar suscripción'],
    ].forEach(([valor, texto]) => selector.add(new Option(texto, valor)))
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
  document.querySelector('[data-admin-titulo]').textContent = `${accion.replaceAll('_', ' ')} · ${usuario.email}`
  document.querySelector('[data-campo-plan]').classList.toggle('oculto', accion !== 'cambiar_plan')
  document.querySelector('[data-campo-fecha]').classList.toggle('oculto', !['extender_prueba', 'cambiar_vencimiento'].includes(accion))
  dialogo.showModal()
}

async function cargar() {
  const filtros = Object.fromEntries(new FormData(document.querySelector('[data-filtros]')))
  const datos = await invocarFuncion('admin-manage-user', { accion: 'listar', pagina, ...filtros })
  const selectorPlanes = formulario.elements.plan_id
  selectorPlanes.replaceChildren()
  ;(datos.planes || []).forEach((plan) => selectorPlanes.add(new Option(plan.nombre, plan.id)))
  Object.entries(datos.metricas || {}).forEach(([nombre, valor]) => {
    const elemento = document.querySelector(`[data-metrica="${nombre}"]`)
    if (elemento) elemento.textContent = valor
  })
  renderUsuarios(datos.usuarios || [])
  renderAuditoria(datos.auditoria || [])
  document.querySelector('[data-pagina]').textContent = `${pagina} de ${datos.paginas || 1}`
  document.querySelector('[data-pagina-anterior]').disabled = pagina <= 1
  document.querySelector('[data-pagina-siguiente]').disabled = pagina >= (datos.paginas || 1)
}

async function iniciar() {
  try {
    const contexto = await protegerRuta('admin')
    if (!contexto) return
    await cargar()
  } catch (error) { mostrarAviso(error.message || 'No se pudo cargar el panel administrativo.', 'error') }
}

document.querySelector('[data-menu]').addEventListener('click', (evento) => {
  const abierto = document.body.classList.toggle('menu-abierto')
  evento.currentTarget.setAttribute('aria-expanded', String(abierto))
})
document.querySelector('[data-logout]').addEventListener('click', async () => {
  try { await cerrarSesion() } catch { mostrarAviso('No se pudo cerrar la sesión.', 'error') }
})
document.querySelector('[data-filtros]').addEventListener('submit', async (evento) => {
  evento.preventDefault()
  pagina = 1
  try { await cargar() } catch (error) { mostrarAviso(error.message, 'error') }
})
document.querySelector('[data-pagina-anterior]').addEventListener('click', async () => { pagina -= 1; await cargar() })
document.querySelector('[data-pagina-siguiente]').addEventListener('click', async () => { pagina += 1; await cargar() })
formulario.addEventListener('submit', async (evento) => {
  if (evento.submitter?.value === 'cancel') return
  evento.preventDefault()
  const boton = evento.submitter
  const datos = Object.fromEntries(new FormData(formulario))
  const errores = validarAccionAdministrativa(datos)
  if (Object.keys(errores).length) return mostrarAviso(Object.values(errores)[0], 'error')
  setCargando(boton, true, 'Aplicando…')
  try {
    await invocarFuncion('admin-manage-user', datos)
    dialogo.close()
    mostrarAviso('La acción se aplicó y quedó registrada en auditoría.', 'exito')
    await cargar()
  } catch (error) { mostrarAviso(error.message, 'error') } finally { setCargando(boton, false) }
})

iniciar()
