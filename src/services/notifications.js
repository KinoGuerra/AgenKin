import { rutaPublica } from '../config/env.js'
import { invocarFuncion } from './edge.js'
import { supabase } from './supabase.js'

const TAMANO_PAGINA = 25
let cursor = null
let cargadas = []
let actualizando = false

function fechaNotificacion(valor) {
  return new Intl.DateTimeFormat('es-AR', {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(valor))
}

function urlBase64ABytes(valor) {
  const normalizado = valor.replace(/-/g, '+').replace(/_/g, '/')
    .padEnd(Math.ceil(valor.length / 4) * 4, '=')
  return Uint8Array.from(globalThis.atob(normalizado), (caracter) => caracter.charCodeAt(0))
}

async function registrarServiceWorker() {
  if (!('serviceWorker' in navigator)) return null
  return navigator.serviceWorker.register(rutaPublica('sw.js'), { scope: rutaPublica('') })
}

function crearCentro() {
  const cabecera = document.querySelector('.cabecera-subpagina__acciones')
    || document.querySelector('.cabecera-identidad__superior')
  if (!cabecera || document.querySelector('[data-centro-notificaciones]')) return null

  const raiz = document.createElement('div')
  raiz.className = 'centro-notificaciones'
  raiz.dataset.centroNotificaciones = ''
  const boton = document.createElement('button')
  boton.type = 'button'
  boton.className = 'campana-notificaciones'
  boton.dataset.notificacionesAbrir = ''
  boton.setAttribute('aria-label', 'Abrir notificaciones')
  boton.setAttribute('aria-expanded', 'false')
  const icono = document.createElement('span')
  icono.setAttribute('aria-hidden', 'true')
  icono.textContent = '🔔'
  const contador = document.createElement('strong')
  contador.dataset.notificacionesContador = ''
  contador.textContent = '0'
  contador.hidden = true
  boton.append(icono, contador)

  const panel = document.createElement('section')
  panel.className = 'panel-notificaciones'
  panel.dataset.notificacionesPanel = ''
  panel.setAttribute('aria-label', 'Notificaciones')
  panel.hidden = true
  const cabeceraPanel = document.createElement('header')
  const titulo = document.createElement('h2')
  titulo.textContent = 'Notificaciones'
  titulo.tabIndex = -1
  const leerTodas = document.createElement('button')
  leerTodas.type = 'button'
  leerTodas.className = 'accion-sutil'
  leerTodas.dataset.notificacionesLeerTodas = ''
  leerTodas.textContent = 'Marcar todas como leídas'
  cabeceraPanel.append(titulo, leerTodas)
  const estado = document.createElement('p')
  estado.className = 'estado-notificaciones'
  estado.dataset.notificacionesEstado = ''
  estado.setAttribute('role', 'status')
  const lista = document.createElement('div')
  lista.className = 'lista-notificaciones'
  lista.dataset.notificacionesLista = ''
  const mas = document.createElement('button')
  mas.type = 'button'
  mas.className = 'boton boton--secundario boton--notificaciones-mas'
  mas.dataset.notificacionesMas = ''
  mas.textContent = 'Cargar anteriores'
  mas.hidden = true
  panel.append(cabeceraPanel, estado, lista, mas)
  raiz.append(boton, panel)
  cabecera.prepend(raiz)
  return raiz
}

function renderLista(hayMas = false) {
  const lista = document.querySelector('[data-notificaciones-lista]')
  const estado = document.querySelector('[data-notificaciones-estado]')
  const mas = document.querySelector('[data-notificaciones-mas]')
  if (!lista || !estado || !mas) return
  lista.replaceChildren()
  estado.textContent = cargadas.length ? '' : 'Todavía no hay notificaciones.'
  cargadas.forEach((notificacion) => {
    const articulo = document.createElement('article')
    if (!notificacion.leida_en) articulo.classList.add('notificacion--no-leida')
    const enlace = document.createElement('a')
    enlace.href = rutaPublica(`agenda.html?notificacion=${encodeURIComponent(notificacion.id)}`)
    enlace.dataset.notificacionId = notificacion.id
    const titulo = document.createElement('strong')
    titulo.textContent = notificacion.titulo
    const mensaje = document.createElement('span')
    mensaje.textContent = notificacion.mensaje || 'Revisá el compromiso en tu Agenda.'
    const fecha = document.createElement('time')
    fecha.dateTime = notificacion.entregada_en
    fecha.textContent = fechaNotificacion(notificacion.entregada_en)
    enlace.append(titulo, mensaje, fecha)
    articulo.append(enlace)
    lista.append(articulo)
  })
  mas.hidden = !hayMas
}

async function actualizarContador() {
  const { count, error } = await supabase
    .from('notificaciones')
    .select('id', { count: 'exact', head: true })
    .eq('estado', 'entregada')
    .is('leida_en', null)
  if (error) throw error
  const contador = document.querySelector('[data-notificaciones-contador]')
  const boton = document.querySelector('[data-notificaciones-abrir]')
  if (!contador || !boton) return
  const total = Number(count || 0)
  contador.textContent = total > 99 ? '99+' : String(total)
  contador.hidden = total === 0
  boton.setAttribute('aria-label', total
    ? `Abrir notificaciones, ${total} sin leer`
    : 'Abrir notificaciones')
}

async function cargarNotificaciones(reiniciar = true) {
  if (actualizando) return
  actualizando = true
  const estado = document.querySelector('[data-notificaciones-estado]')
  if (estado) estado.textContent = reiniciar ? 'Cargando…' : 'Cargando anteriores…'
  try {
    if (reiniciar) {
      cargadas = []
      cursor = null
    }
    let consulta = supabase
      .from('notificaciones')
      .select('id,titulo,mensaje,entregada_en,leida_en,evento_id')
      .eq('estado', 'entregada')
      .order('entregada_en', { ascending: false })
      .order('id', { ascending: false })
      .limit(TAMANO_PAGINA + 1)
    if (cursor) {
      consulta = consulta.or(
        `entregada_en.lt.${cursor.fecha},and(entregada_en.eq.${cursor.fecha},id.lt.${cursor.id})`,
      )
    }
    const { data, error } = await consulta
    if (error) throw error
    const pagina = data || []
    const hayMas = pagina.length > TAMANO_PAGINA
    const visibles = pagina.slice(0, TAMANO_PAGINA)
    cargadas.push(...visibles)
    const ultima = visibles.at(-1)
    cursor = ultima ? { fecha: ultima.entregada_en, id: ultima.id } : cursor
    renderLista(hayMas)
    await actualizarContador()
  } catch {
    if (estado) estado.textContent = 'No pudimos cargar las notificaciones.'
  } finally {
    actualizando = false
  }
}

export async function inicializarCentroNotificaciones() {
  const raiz = crearCentro()
  if (!raiz) return
  const boton = raiz.querySelector('[data-notificaciones-abrir]')
  const panel = raiz.querySelector('[data-notificaciones-panel]')
  boton.addEventListener('click', async () => {
    panel.hidden = !panel.hidden
    boton.setAttribute('aria-expanded', String(!panel.hidden))
    if (!panel.hidden) {
      await cargarNotificaciones(true)
      panel.querySelector('h2')?.focus?.()
    }
  })
  raiz.querySelector('[data-notificaciones-mas]').addEventListener('click', () => cargarNotificaciones(false))
  raiz.querySelector('[data-notificaciones-leer-todas]').addEventListener('click', async () => {
    const { error } = await supabase.rpc('marcar_notificaciones_leidas')
    if (!error) await cargarNotificaciones(true)
  })
  raiz.querySelector('[data-notificaciones-lista]').addEventListener('click', async (evento) => {
    const enlace = evento.target.closest('[data-notificacion-id]')
    if (!enlace) return
    evento.preventDefault()
    await supabase.rpc('marcar_notificacion_leida', { p_notificacion_id: enlace.dataset.notificacionId })
    window.location.assign(enlace.href)
  })
  document.addEventListener('click', (evento) => {
    if (!panel.hidden && !raiz.contains(evento.target)) {
      panel.hidden = true
      boton.setAttribute('aria-expanded', 'false')
    }
  })
  document.addEventListener('keydown', (evento) => {
    if (evento.key === 'Escape' && !panel.hidden) {
      panel.hidden = true
      boton.setAttribute('aria-expanded', 'false')
      boton.focus()
    }
  })
  window.addEventListener('focus', () => {
    const actualizacion = panel.hidden ? actualizarContador() : cargarNotificaciones(true)
    actualizacion.catch(() => null)
  })
  navigator.serviceWorker?.addEventListener('message', () => cargarNotificaciones(true))
  await registrarServiceWorker().catch(() => null)
  await actualizarContador().catch(() => null)
}

function textoEstadoDispositivo() {
  if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) {
    return 'Este navegador no admite avisos del dispositivo. Las alertas internas siguen disponibles.'
  }
  if (globalThis.Notification.permission === 'denied') return 'El navegador bloqueó los avisos. Podés habilitarlos desde sus permisos.'
  if (globalThis.Notification.permission === 'granted') return 'El navegador permite avisos; activalos para este dispositivo si todavía no lo hiciste.'
  return 'Compatible. El permiso se solicitará únicamente al usar el botón de activación.'
}

export async function inicializarPreferenciasNotificaciones() {
  const formulario = document.querySelector('[data-notificaciones-form]')
  if (!formulario) return
  const recibir = formulario.elements.recibir_notificaciones
  const previo = formulario.elements.notificar_dia_previo
  const dia = formulario.elements.notificar_dia_vencimiento
  const zona = formulario.elements.zona_horaria_notificaciones
  const estado = document.querySelector('[data-push-estado]')
  const zonaDispositivo = Intl.DateTimeFormat().resolvedOptions().timeZone || 'America/Argentina/Cordoba'
  document.querySelector('[data-zona-detectada]').textContent = `Este dispositivo usa ${zonaDispositivo}.`
  estado.textContent = textoEstadoDispositivo()
  const { data, error } = await supabase
    .from('perfiles')
    .select('recibir_notificaciones,notificar_dia_previo,notificar_dia_vencimiento,zona_horaria_notificaciones')
    .single()
  if (error) {
    estado.textContent = 'No pudimos cargar tus preferencias.'
    return
  }
  recibir.checked = data.recibir_notificaciones
  previo.checked = data.notificar_dia_previo
  dia.checked = data.notificar_dia_vencimiento
  zona.value = data.zona_horaria_notificaciones

  formulario.addEventListener('submit', async (evento) => {
    evento.preventDefault()
    const boton = evento.submitter
    boton.disabled = true
    try {
      const { error: errorGuardar } = await supabase.rpc('actualizar_preferencias_notificacion', {
        p_recibir: recibir.checked,
        p_dia_previo: previo.checked,
        p_dia_vencimiento: dia.checked,
        p_zona_horaria: zona.value,
      })
      if (errorGuardar) throw errorGuardar
      estado.textContent = !previo.checked && !dia.checked
        ? 'Preferencias guardadas. No se programarán avisos hasta elegir al menos un momento.'
        : 'Preferencias guardadas.'
    } catch {
      estado.textContent = 'No pudimos guardar las preferencias.'
    } finally {
      boton.disabled = false
    }
  })

  document.querySelector('[data-zona-dispositivo]').addEventListener('click', () => {
    zona.value = zonaDispositivo
    estado.textContent = `Zona detectada: ${zona.value}. Guardá para aplicarla.`
  })
  document.querySelector('[data-push-activar]').addEventListener('click', async (evento) => {
    const boton = evento.currentTarget
    if (!recibir.checked) {
      estado.textContent = 'Primero activá “Recibir notificaciones” y guardá la preferencia.'
      return
    }
    if (!previo.checked && !dia.checked) {
      estado.textContent = 'Elegí y guardá al menos un momento de aviso antes de activar el dispositivo.'
      return
    }
    if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) {
      estado.textContent = textoEstadoDispositivo()
      return
    }
    boton.disabled = true
    try {
      const permiso = await globalThis.Notification.requestPermission()
      if (permiso !== 'granted') {
        estado.textContent = textoEstadoDispositivo()
        return
      }
      const configuracion = await invocarFuncion('manage-web-push', { accion: 'estado' })
      if (!configuracion.disponible || !configuracion.vapid_public_key) {
        throw new Error('Los avisos del dispositivo todavía no están configurados por el administrador.')
      }
      const registro = await registrarServiceWorker()
      const existente = await registro.pushManager.getSubscription()
      const suscripcion = existente || await registro.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ABytes(configuracion.vapid_public_key),
      })
      await invocarFuncion('manage-web-push', {
        accion: 'suscribir',
        suscripcion: suscripcion.toJSON(),
      })
      estado.textContent = 'Avisos activados en este dispositivo.'
    } catch (error) {
      estado.textContent = error.message || 'No pudimos activar los avisos del dispositivo.'
    } finally {
      boton.disabled = false
    }
  })
  document.querySelector('[data-push-desactivar]').addEventListener('click', async () => {
    await desactivarPushDispositivoActual()
    estado.textContent = 'Avisos desactivados en este dispositivo. Las alertas internas continúan.'
  })
}

export async function desactivarPushDispositivoActual() {
  if (!('serviceWorker' in navigator)) return
  const registro = await navigator.serviceWorker.getRegistration(rutaPublica(''))
  const suscripcion = await registro?.pushManager?.getSubscription()
  if (!suscripcion) return
  try {
    await invocarFuncion('manage-web-push', {
      accion: 'desuscribir',
      suscripcion: suscripcion.toJSON(),
    })
  } finally {
    await suscripcion.unsubscribe().catch(() => false)
  }
}
