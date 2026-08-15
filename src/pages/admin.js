import '../components/theme.js'
import { inicializarColapsoLateral } from '../components/sidebar.js'
import { crearCelda, estadoVacio, mostrarAviso, setCargando } from '../components/ui.js'
import { protegerRuta } from '../guards/route-guard.js'
import { cerrarSesion } from '../services/auth.js'
import { invocarFuncion } from '../services/edge.js'
import { formatearFecha } from '../utils/fechas.js'
import { validarAccionAdministrativa } from '../utils/validaciones.js'

let pagina = 1
let administradorId = null
let planesDisponibles = []
let usuarioGestionado = null
const tbody = document.querySelector('[data-usuarios]')
const dialogo = document.querySelector('[data-admin-dialog]')
const formulario = document.querySelector('[data-admin-form]')
const filtros = document.querySelector('[data-filtros]')
const formularioPrecios = document.querySelector('[data-precios-form]')
const listaPrecios = document.querySelector('[data-precios-lista]')
const botonMenu = document.querySelector('[data-menu]')
const botonActualizar = document.querySelector('[data-admin-actualizar]')
const anclaAlertasOperativas = document.querySelector('[data-alertas-operativas]')
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

function sincronizarCampoFecha() {
  const accion = formulario.elements.accion.value
  const plan = planesDisponibles.find(({ id }) => id === formulario.elements.plan_id.value)
  const requiereAlSalirDeAgenKin = accion === 'cambiar_plan'
    && usuarioGestionado?.es_interno
    && !plan?.es_interno
  const mostrar = ['extender_prueba', 'cambiar_vencimiento'].includes(accion)
    || requiereAlSalirDeAgenKin
  document.querySelector('[data-campo-fecha]').classList.toggle('oculto', !mostrar)
  formulario.elements.fecha_vencimiento.required = mostrar
}

function obtenerIniciales(nombre, email) {
  const partes = (nombre || '').trim().split(/\s+/).filter(Boolean)
  if (partes.length) return partes.slice(0, 2).map((parte) => parte[0]).join('').toUpperCase()
  return (email || 'SA').slice(0, 2).toUpperCase()
}

function renderPerfil(contexto) {
  const perfil = contexto.perfil || {}
  const nombre = perfil.nombre_completo || contexto.user?.user_metadata?.full_name || 'Administrador'
  const email = perfil.email || contexto.user?.email || 'Cuenta superadministradora'
  const imagen = document.querySelector('[data-admin-avatar]')
  const iniciales = document.querySelector('[data-admin-iniciales]')

  document.querySelector('[data-admin-nombre]').textContent = nombre.trim().split(/\s+/)[0] || 'Administrador'
  iniciales.textContent = obtenerIniciales(nombre, email)

  const avatar = perfil.avatar_url || contexto.user?.user_metadata?.avatar_url || contexto.user?.user_metadata?.picture
  if (!avatar) return

  try {
    const url = new URL(avatar)
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

function cerrarMenu({ devolverFoco = false } = {}) {
  document.body.classList.remove('menu-abierto')
  botonMenu.setAttribute('aria-expanded', 'false')
  botonMenu.setAttribute('aria-label', 'Abrir menú')
  if (devolverFoco) botonMenu.focus()
}

function numero(valor) {
  return Number.isFinite(Number(valor)) ? Number(valor) : 0
}

function incidenciasOperativas(metricas) {
  const incidencias = []
  const megabytes = Math.round(numero(metricas.bytes_base) / 1024 / 1024)
  if (metricas.detener_carga_historica) {
    incidencias.push({ nivel: 'critica', texto: `El almacenamiento alcanzó ${megabytes} MB. La carga histórica debe mantenerse detenida.` })
  } else if (metricas.alerta_almacenamiento) {
    incidencias.push({ nivel: 'advertencia', texto: `El almacenamiento alcanzó ${megabytes} MB. Revisá retención y capacidad.` })
  }
  const antiguedad = numero(metricas.alerta_mas_antigua_minutos)
  if (antiguedad > 30) incidencias.push({ nivel: 'critica', texto: `La cola de alertas lleva ${antiguedad} minutos pendiente.` })
  const antiguedadGmail = numero(metricas.gmail_antiguedad_minutos)
  if (antiguedadGmail > 30) incidencias.push({ nivel: 'critica', texto: `La cola de Gmail lleva ${antiguedadGmail} minutos disponible sin procesar.` })
  const antiguedadCalendar = numero(metricas.calendar_antiguedad_minutos)
  if (antiguedadCalendar > 30) incidencias.push({ nivel: 'critica', texto: `La cola de Calendar lleva ${antiguedadCalendar} minutos pendiente.` })
  const tokensVencidos = numero(metricas.conexiones_token_vencido)
  if (tokensVencidos) incidencias.push({ nivel: 'advertencia', texto: `${tokensVencidos} conexión${tokensVencidos === 1 ? '' : 'es'} requiere${tokensVencidos === 1 ? '' : 'n'} volver a autorizar Google.` })
  return incidencias
}

function crearCentroOperativo() {
  const boton = document.createElement('button')
  boton.className = 'campana-operativa material-symbols-rounded'
  boton.type = 'button'
  boton.textContent = 'notifications'
  boton.setAttribute('aria-label', 'Abrir alertas operativas')
  boton.setAttribute('aria-expanded', 'false')
  const badge = document.createElement('span')
  badge.className = 'badge-operativa'
  badge.hidden = true
  badge.setAttribute('aria-hidden', 'true')
  boton.append(badge)

  const panel = document.createElement('section')
  panel.className = 'panel-alertas-operativas'
  panel.hidden = true
  panel.setAttribute('aria-label', 'Alertas operativas')
  const cabecera = document.createElement('div')
  cabecera.className = 'panel-alertas-operativas__cabecera'
  const titulo = document.createElement('h2')
  titulo.textContent = 'Alertas operativas'
  const cerrarAlertas = document.createElement('button')
  cerrarAlertas.className = 'cerrar-alertas-operativas material-symbols-rounded'
  cerrarAlertas.type = 'button'
  cerrarAlertas.textContent = 'close'
  cerrarAlertas.setAttribute('aria-label', 'Cerrar alertas operativas')
  cabecera.append(titulo, cerrarAlertas)
  const lista = document.createElement('ul')
  const contexto = document.createElement('p')
  contexto.className = 'panel-alertas-operativas__contexto'
  const actualizar = document.createElement('button')
  actualizar.className = 'boton boton--secundario boton--mini'
  actualizar.type = 'button'
  actualizar.textContent = 'Actualizar estado'
  panel.append(cabecera, lista, contexto, actualizar)
  anclaAlertasOperativas.append(boton, panel)

  const cerrar = () => {
    panel.hidden = true
    boton.setAttribute('aria-expanded', 'false')
  }
  boton.addEventListener('click', () => {
    const abierto = panel.hidden
    panel.hidden = !abierto
    boton.setAttribute('aria-expanded', String(abierto))
    if (abierto) actualizar.focus()
  })
  actualizar.addEventListener('click', () => actualizarEstadoOperativo(actualizar))
  cerrarAlertas.addEventListener('click', () => {
    cerrar()
    boton.focus()
  })
  document.addEventListener('click', (evento) => {
    if (!anclaAlertasOperativas.contains(evento.target)) cerrar()
  })
  return { boton, badge, lista, contexto, cerrar }
}

const centroOperativo = crearCentroOperativo()

function renderCentroOperativo(metricas) {
  const incidencias = incidenciasOperativas(metricas)
  centroOperativo.badge.hidden = !incidencias.length
  centroOperativo.badge.textContent = incidencias.length > 9 ? '9+' : String(incidencias.length)
  centroOperativo.boton.classList.toggle('campana-operativa--incidencia', Boolean(incidencias.length))
  centroOperativo.boton.setAttribute('aria-label', incidencias.length ? `Abrir alertas operativas: ${incidencias.length} incidencia${incidencias.length === 1 ? '' : 's'}` : 'Abrir alertas operativas')
  centroOperativo.lista.replaceChildren()
  if (!incidencias.length) {
    const item = document.createElement('li')
    item.className = 'alerta-operativa alerta-operativa--estable'
    item.textContent = 'No hay incidencias que requieran atención.'
    centroOperativo.lista.append(item)
  } else {
    incidencias.forEach((incidencia) => {
      const item = document.createElement('li')
      item.className = `alerta-operativa alerta-operativa--${incidencia.nivel}`
      item.textContent = incidencia.texto
      centroOperativo.lista.append(item)
    })
  }
  centroOperativo.contexto.textContent = `Contexto: ${numero(metricas.errores)} errores recientes · ${numero(metricas.gmail_pendientes)} Gmail pendientes · ${numero(metricas.calendar_pendientes)} Calendar pendientes · ${numero(metricas.revisiones_pendientes)} revisiones · ${numero(metricas.alertas_pendientes)} alertas pendientes · ${numero(metricas.push_temporales)} Push en reintento.`
}

function renderUsuarios(usuarios) {
  tbody.replaceChildren()
  document.querySelector('[data-admin-resultados]').textContent = usuarios.length
    ? `${usuarios.length} usuario${usuarios.length === 1 ? '' : 's'} en esta página.`
    : 'No hay usuarios que coincidan con los filtros.'
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
      crearCelda(usuario.es_interno ? 'Sin vencimiento' : formatearFecha(usuario.fecha_vencimiento)),
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

function renderPrecios(planes) {
  listaPrecios.replaceChildren()
  const publicos = planes.filter((plan) => plan.visible_publico && !plan.es_interno)
  if (!publicos.length) {
    listaPrecios.append(estadoVacio('No hay planes públicos activos.'))
    return
  }

  publicos.forEach((plan) => {
    const tarjeta = document.createElement('article')
    tarjeta.dataset.planPrecio = plan.id
    const cabecera = document.createElement('div')
    const nombre = document.createElement('strong')
    const capacidad = document.createElement('small')
    nombre.textContent = plan.nombre
    capacidad.textContent = `${plan.limite_cuentas_gmail} cuenta${plan.limite_cuentas_gmail === 1 ? '' : 's'} Gmail`
    cabecera.append(nombre, capacidad)

    const campoPrecio = document.createElement('label')
    campoPrecio.textContent = 'Precio publicado'
    const precio = document.createElement('input')
    precio.type = 'number'
    precio.min = '0'
    precio.max = '9999999999.99'
    precio.step = '0.01'
    precio.required = true
    precio.value = String(Number(plan.precio || 0))
    precio.dataset.precio = ''
    campoPrecio.append(precio)

    const moneda = document.createElement('div')
    moneda.className = 'precio-admin__moneda'
    moneda.append(
      Object.assign(document.createElement('small'), { textContent: 'Moneda de publicación' }),
      Object.assign(document.createElement('strong'), { textContent: 'USD · Dólares estadounidenses' }),
    )

    tarjeta.append(cabecera, campoPrecio, moneda)
    listaPrecios.append(tarjeta)
  })
}

function abrirAccion(usuario, accion) {
  formulario.reset()
  usuarioGestionado = usuario
  formulario.elements.usuario_id.value = usuario.id
  formulario.elements.accion.value = accion
  const etiqueta = ACCIONES.find(([valor]) => valor === accion)?.[1] || 'Gestionar usuario'
  const nombre = usuario.nombre_completo || usuario.email
  document.querySelector('[data-admin-titulo]').textContent = etiqueta
  document.querySelector('[data-admin-confirmacion]').textContent = `Vas a aplicar “${etiqueta.toLowerCase()}” a ${nombre}. El cambio quedará registrado.`
  document.querySelector('[data-campo-plan]').classList.toggle('oculto', accion !== 'cambiar_plan')
  sincronizarCampoFecha()
  dialogo.showModal()
}

async function cargar() {
  const valores = Object.fromEntries(new FormData(filtros))
  const datos = await invocarFuncion('admin-manage-user', { accion: 'listar', pagina, ...valores })
  const selectorPlanes = formulario.elements.plan_id
  selectorPlanes.replaceChildren()
  planesDisponibles = datos.planes || []
  planesDisponibles.forEach((plan) => selectorPlanes.add(new Option(plan.nombre, plan.id)))
  renderPrecios(planesDisponibles)

  Object.entries(datos.metricas || {}).forEach(([nombre, valor]) => {
    const elemento = document.querySelector(`[data-metrica="${nombre}"]`)
    if (elemento) elemento.textContent = valor
  })
  const metricas = datos.metricas || {}
  document.querySelector('[data-admin-registrados]').textContent = numero(metricas.registrados)
  document.querySelector('[data-admin-activos]').textContent = numero(metricas.activos)
  document.querySelector('[data-admin-cuentas-gmail]').textContent = numero(metricas.cuentas_gmail)
  document.querySelector('[data-admin-errores]').textContent = numero(metricas.errores)
  const antiguedad = Math.max(
    numero(metricas.alerta_mas_antigua_minutos),
    numero(metricas.gmail_antiguedad_minutos),
    numero(metricas.calendar_antiguedad_minutos),
  )
  document.querySelector('[data-admin-cola]').textContent = antiguedad ? `${antiguedad} min` : 'Sin demora'
  renderCentroOperativo(metricas)

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

async function actualizarEstadoOperativo(boton) {
  setCargando(boton, true, 'Actualizando…')
  try {
    await cargar()
  } catch (error) {
    mostrarAviso(error.message || 'No se pudo actualizar el estado operativo.', 'error')
  } finally {
    setCargando(boton, false)
  }
}

async function iniciar() {
  try {
    const contexto = await protegerRuta('admin')
    if (!contexto) return
    administradorId = contexto.user.id
    renderPerfil(contexto)
    document.documentElement.classList.remove('ruta-protegida-pendiente')
    await cargar()
  } catch (error) {
    document.documentElement.classList.remove('ruta-protegida-pendiente')
    mostrarAviso(error.message || 'No se pudo cargar el panel administrativo.', 'error')
  }
}

const menuAdmin = document.querySelector('.barra-lateral')
if (menuAdmin) {
  menuAdmin.id ||= 'menu-administracion'
  botonMenu.setAttribute('aria-controls', menuAdmin.id)
}
inicializarColapsoLateral({ clave: 'agenkin_menu_admin_colapsado', claseCuerpo: 'menu-admin-colapsado' })
botonMenu.addEventListener('click', (evento) => {
  const abierto = document.body.classList.toggle('menu-abierto')
  evento.currentTarget.setAttribute('aria-expanded', String(abierto))
  evento.currentTarget.setAttribute('aria-label', abierto ? 'Cerrar menú' : 'Abrir menú')
})
document.querySelector('[data-menu-overlay]').addEventListener('click', () => cerrarMenu({ devolverFoco: true }))
document.querySelectorAll('.barra-lateral nav a').forEach((enlace) => enlace.addEventListener('click', cerrarMenu))
document.addEventListener('keydown', (evento) => {
  if (evento.key !== 'Escape') return
  if (document.body.classList.contains('menu-abierto')) cerrarMenu({ devolverFoco: true })
  centroOperativo.cerrar()
})
document.querySelector('[data-logout]').addEventListener('click', async () => {
  try {
    await cerrarSesion()
  } catch {
    mostrarAviso('No se pudo cerrar la sesión.', 'error')
  }
})
botonActualizar.addEventListener('click', () => actualizarEstadoOperativo(botonActualizar))
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
formularioPrecios.addEventListener('submit', async (evento) => {
  evento.preventDefault()
  const boton = evento.submitter
  const precios = [...listaPrecios.querySelectorAll('[data-plan-precio]')].map((tarjeta) => ({
    id: tarjeta.dataset.planPrecio,
    precio: Number(tarjeta.querySelector('[data-precio]').value),
  }))
  if (precios.some(({ precio }) => !Number.isFinite(precio) || precio < 0)) {
    mostrarAviso('Revisá los precios antes de guardar.', 'error')
    return
  }
  setCargando(boton, true, 'Guardando…')
  try {
    await invocarFuncion('admin-manage-user', { accion: 'actualizar_precios', precios })
    document.querySelector('[data-precios-estado]').textContent = 'Precios actualizados y registrados en auditoría.'
    mostrarAviso('Los precios públicos se actualizaron correctamente.', 'exito')
    await cargar()
  } catch (error) {
    mostrarAviso(error.message || 'No se pudieron actualizar los precios.', 'error')
  } finally {
    setCargando(boton, false)
  }
})
formulario.elements.plan_id.addEventListener('change', sincronizarCampoFecha)

iniciar()
