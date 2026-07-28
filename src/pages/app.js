import '../components/theme.js'
import { crearCelda, estadoVacio, mostrarAviso, setCargando } from '../components/ui.js'
import { protegerRuta } from '../guards/route-guard.js'
import { cerrarSesion } from '../services/auth.js'
import { invocarFuncion } from '../services/edge.js'
import { cargarPortal } from '../services/portal.js'
import { supabase } from '../services/supabase.js'
import { formatearFecha } from '../utils/fechas.js'

let datosPortal
const tbodyVencimientos = document.querySelector('[data-vencimientos]')
const dialogoEvento = document.querySelector('[data-evento-dialog]')
const formularioEvento = document.querySelector('[data-evento-form]')
const dialogoRegla = document.querySelector('[data-regla-dialog]')
const formularioRegla = document.querySelector('[data-regla-form]')

function renderFilas(contenedor, datos, columnas, mensajeVacio) {
  contenedor.replaceChildren()
  if (!datos.length) {
    const fila = document.createElement('tr')
    const celda = crearCelda(mensajeVacio)
    celda.colSpan = columnas.length
    fila.append(celda)
    contenedor.append(fila)
    return
  }
  datos.forEach((dato) => {
    const fila = document.createElement('tr')
    columnas.forEach((obtener) => fila.append(crearCelda(obtener(dato))))
    contenedor.append(fila)
  })
}

function renderVencimientos(vencimientos) {
  tbodyVencimientos.replaceChildren()
  if (!vencimientos.length) {
    const fila = document.createElement('tr')
    const celda = crearCelda('Todavía no hay vencimientos detectados.')
    celda.colSpan = 6
    fila.append(celda)
    tbodyVencimientos.append(fila)
    return
  }
  vencimientos.forEach((item) => {
    const fila = document.createElement('tr')
    fila.append(
      crearCelda(item.correos_procesados?.asunto || item.titulo),
      crearCelda(item.tipo),
      crearCelda(formatearFecha(item.fecha_vencimiento)),
      crearCelda(`${Math.round(item.confianza * 100)}%`),
      crearCelda(item.estado),
    )
    const acciones = document.createElement('td')
    const revisar = document.createElement('button')
    revisar.className = 'boton boton--mini'
    revisar.textContent = item.estado === 'confirmado' ? 'Crear evento' : 'Revisar'
    revisar.dataset.revisar = item.id
    const descartar = document.createElement('button')
    descartar.className = 'boton boton--mini boton--texto'
    descartar.textContent = 'Descartar'
    descartar.dataset.descartar = item.id
    descartar.disabled = ['descartado', 'evento_creado'].includes(item.estado)
    acciones.append(revisar, descartar)
    fila.append(acciones)
    tbodyVencimientos.append(fila)
  })
}

function renderPortal(datos) {
  const resumen = datos.resumen || {}
  Object.entries({
    correos: resumen.correos_procesados || 0,
    vencimientos: resumen.vencimientos_detectados || 0,
    eventos: resumen.eventos_creados || 0,
    pendientes: resumen.pendientes_revision || 0,
  }).forEach(([nombre, valor]) => {
    document.querySelector(`[data-metrica="${nombre}"]`).textContent = valor
  })
  renderVencimientos(datos.vencimientos)
  renderFilas(document.querySelector('[data-correos]'), datos.correos, [
    (item) => formatearFecha(item.fecha_correo),
    (item) => item.remitente,
    (item) => item.asunto,
    (item) => item.categoria,
    (item) => item.estado_procesamiento,
  ], 'Todavía no se analizaron correos.')

  const eventos = document.querySelector('[data-eventos]')
  eventos.replaceChildren()
  if (!datos.eventos.length) eventos.append(estadoVacio('Todavía no se crearon eventos.'))
  datos.eventos.forEach((item) => {
    const tarjeta = document.createElement('article')
    const titulo = document.createElement('strong')
    titulo.textContent = item.vencimientos_detectados?.titulo || 'Evento de AgenKin'
    const detalle = document.createElement('span')
    detalle.textContent = `${formatearFecha(item.fecha_evento)} · ${item.estado_sincronizacion}`
    tarjeta.append(titulo, detalle)
    eventos.append(tarjeta)
  })

  const reglas = document.querySelector('[data-reglas]')
  reglas.replaceChildren()
  if (!datos.reglas.length) reglas.append(estadoVacio('No tenés reglas personales. Podés crear la primera.'))
  datos.reglas.forEach((item) => {
    const tarjeta = document.createElement('article')
    const texto = document.createElement('div')
    const titulo = document.createElement('strong')
    titulo.textContent = item.nombre
    const detalle = document.createElement('span')
    detalle.textContent = `${item.campo} ${item.operador} “${item.valor}” → ${item.accion}`
    texto.append(titulo, detalle)
    const eliminar = document.createElement('button')
    eliminar.className = 'boton boton--mini boton--texto'
    eliminar.textContent = 'Eliminar'
    eliminar.dataset.eliminarRegla = item.id
    tarjeta.append(texto, eliminar)
    reglas.append(tarjeta)
  })

  const conexion = datos.conexion || {}
  document.querySelector('[data-google-estado]').textContent = conexion.conectado
    ? `${conexion.google_email || 'Cuenta conectada'} · última sincronización: ${formatearFecha(conexion.fecha_ultima_sincronizacion)}`
    : 'Los servicios no están conectados. Se requiere configurar Google OAuth en el servidor.'
  document.querySelector('[data-connect-google]').classList.toggle('oculto', Boolean(conexion.conectado))
  document.querySelector('[data-disconnect-google]').classList.toggle('oculto', !conexion.conectado)

  const suscripcion = resumen.suscripcion || {}
  const campos = {
    plan: suscripcion.plan || 'Sin plan',
    estado: suscripcion.estado || 'Sin suscripción',
    inicio: formatearFecha(suscripcion.fecha_inicio),
    vencimiento: formatearFecha(suscripcion.fecha_vencimiento),
  }
  Object.entries(campos).forEach(([campo, valor]) => {
    document.querySelector(`[data-suscripcion="${campo}"]`).textContent = valor
  })
  const usados = Number(resumen.correos_procesados || 0)
  const limite = Number(suscripcion.limite_correos_mensuales || 0)
  document.querySelector('[data-uso]').value = limite ? Math.min(100, (usados / limite) * 100) : 0
  document.querySelector('[data-uso-texto]').textContent = `${usados} de ${limite || '—'} correos procesados`
}

async function refrescar() {
  datosPortal = await cargarPortal()
  renderPortal(datosPortal)
}

async function iniciar() {
  try {
    const contexto = await protegerRuta('app')
    if (!contexto) return
    document.querySelector('[data-nombre]').textContent = contexto.perfil.nombre_completo?.split(' ')[0] || 'bienvenido'
    document.querySelector('[data-avatar]').textContent = (contexto.perfil.nombre_completo || contexto.perfil.email || 'A').slice(0, 1).toUpperCase()
    await refrescar()
  } catch {
    mostrarAviso('No pudimos cargar el portal. Revisá la conexión y la configuración de Supabase.', 'error')
  }
}

document.querySelector('[data-menu]').addEventListener('click', (evento) => {
  const abierto = document.body.classList.toggle('menu-abierto')
  evento.currentTarget.setAttribute('aria-expanded', String(abierto))
})
document.querySelector('[data-logout]').addEventListener('click', async (evento) => {
  setCargando(evento.currentTarget, true)
  try { await cerrarSesion() } catch { mostrarAviso('No se pudo cerrar la sesión.', 'error') }
})
document.querySelector('[data-scan]').addEventListener('click', async (evento) => {
  const boton = evento.currentTarget
  setCargando(boton, true, 'Analizando…')
  try {
    const resultado = await invocarFuncion('scan-gmail', {})
    const procesados = resultado.procesados || 0
    const errores = resultado.errores || 0
    const ignorados = resultado.ignorados || 0
    const detectados = resultado.detectados || 0
    const limite = resultado.limite_alcanzado ? ' Se alcanzó el límite mensual.' : ''
    const pendientes = resultado.hay_mas
      ? ' Quedan correos pendientes; volvé a ejecutar el análisis para continuar.'
      : ''
    const mensaje = errores
      ? `Análisis terminado: ${procesados} correctos, ${errores} con error, ${ignorados} ignorados y ${detectados} vencimientos detectados.${limite}${pendientes}`
      : `Análisis terminado: ${procesados} correos, ${ignorados} ignorados y ${detectados} vencimientos detectados.${limite}${pendientes}`
    mostrarAviso(mensaje, errores ? 'error' : 'exito')
    await refrescar()
  } catch (error) {
    mostrarAviso(error.message, 'error')
  } finally { setCargando(boton, false) }
})
document.querySelector('[data-connect-google]').addEventListener('click', async (evento) => {
  const boton = evento.currentTarget
  setCargando(boton, true, 'Preparando conexión…')
  try {
    const { url } = await invocarFuncion('google-oauth-start', {})
    window.location.assign(url)
  } catch {
    mostrarAviso('Configuración requerida: el propietario debe configurar las credenciales de Google.', 'error')
    setCargando(boton, false)
  }
})
document.querySelector('[data-disconnect-google]').addEventListener('click', async () => {
  if (!confirm('¿Desconectar Gmail y Calendar? AgenKin dejará de poder analizarlos.')) return
  try {
    await invocarFuncion('google-disconnect', {})
    mostrarAviso('La cuenta de Google fue desconectada.', 'exito')
    await refrescar()
  } catch (error) { mostrarAviso(error.message, 'error') }
})
tbodyVencimientos.addEventListener('click', async (evento) => {
  const id = evento.target.dataset.revisar || evento.target.dataset.descartar
  if (!id) return
  const item = datosPortal.vencimientos.find((vencimiento) => vencimiento.id === id)
  if (evento.target.dataset.descartar) {
    if (!confirm('¿Descartar este vencimiento?')) return
    const { error } = await supabase.from('vencimientos_detectados').update({ estado: 'descartado' }).eq('id', id)
    if (error) mostrarAviso('No se pudo descartar el vencimiento.', 'error')
    else await refrescar()
    return
  }
  formularioEvento.elements.vencimiento_id.value = item.id
  formularioEvento.elements.titulo.value = item.titulo
  formularioEvento.elements.descripcion.value = item.descripcion || ''
  formularioEvento.elements.fecha.value = item.fecha_vencimiento
  formularioEvento.elements.hora.value = item.hora_vencimiento?.slice(0, 5) || ''
  dialogoEvento.showModal()
})
formularioEvento.addEventListener('submit', async (evento) => {
  if (evento.submitter?.value === 'cancel') return
  evento.preventDefault()
  const boton = evento.submitter
  setCargando(boton, true, 'Creando…')
  try {
    const payload = Object.fromEntries(new FormData(formularioEvento))
    payload.recordatorio = Number(payload.recordatorio)
    await invocarFuncion('create-calendar-event', payload)
    dialogoEvento.close()
    mostrarAviso('Evento creado correctamente en Google Calendar.', 'exito')
    await refrescar()
  } catch (error) { mostrarAviso(error.message, 'error') } finally { setCargando(boton, false) }
})
document.querySelector('[data-nueva-regla]').addEventListener('click', () => dialogoRegla.showModal())
formularioRegla.addEventListener('submit', async (evento) => {
  if (evento.submitter?.value === 'cancel') return
  evento.preventDefault()
  const boton = evento.submitter
  setCargando(boton, true, 'Guardando…')
  const { error } = await supabase.from('reglas_usuario').insert(Object.fromEntries(new FormData(formularioRegla)))
  setCargando(boton, false)
  if (error) return mostrarAviso('No se pudo guardar la regla.', 'error')
  dialogoRegla.close()
  formularioRegla.reset()
  await refrescar()
})
document.querySelector('[data-reglas]').addEventListener('click', async (evento) => {
  const id = evento.target.dataset.eliminarRegla
  if (!id || !confirm('¿Eliminar esta regla?')) return
  const { error } = await supabase.from('reglas_usuario').delete().eq('id', id)
  if (error) mostrarAviso('No se pudo eliminar la regla.', 'error')
  else await refrescar()
})

iniciar()
