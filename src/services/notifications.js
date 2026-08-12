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
  const cabecera = document.querySelector('[data-notificaciones-ancla]')
    || document.querySelector('.cabecera-subpagina__acciones')
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
  icono.className = 'material-symbols-rounded'
  icono.setAttribute('aria-hidden', 'true')
  icono.textContent = 'notifications'
  const contador = document.createElement('strong')
  contador.className = 'badge-notificaciones badge-notificaciones--posicionada'
  contador.dataset.notificacionesContador = ''
  contador.setAttribute('aria-hidden', 'true')
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
  boton.classList.toggle('campana-notificaciones--con-alertas', total > 0)
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

function poblarZonasHorarias(select, zonaDispositivo) {
  const respaldo = [
    'America/Argentina/Cordoba',
    'America/Argentina/Buenos_Aires',
    'America/Santiago',
    'America/Sao_Paulo',
    'America/Mexico_City',
    'Europe/Madrid',
    'UTC',
  ]
  const zonas = typeof Intl.supportedValuesOf === 'function'
    ? Intl.supportedValuesOf('timeZone')
    : respaldo
  const valores = [...new Set([...zonas, zonaDispositivo])].sort()
  select.replaceChildren()
  valores.forEach((valor) => {
    const opcion = document.createElement('option')
    opcion.value = valor
    opcion.textContent = valor
    select.append(opcion)
  })
}

function seleccionarZonaHoraria(select, valor) {
  const zona = typeof valor === 'string' && valor.trim() ? valor.trim() : 'America/Argentina/Cordoba'
  if (![...select.options].some((opcion) => opcion.value === zona)) {
    const opcion = document.createElement('option')
    opcion.value = zona
    opcion.textContent = zona
    select.append(opcion)
  }
  select.value = zona
}

function sincronizarDependenciasNotificaciones(recibir, previo, dia, horaPrevia) {
  const activas = recibir.checked
  if (!activas) {
    previo.checked = false
    dia.checked = false
  }
  previo.disabled = !activas
  dia.disabled = !activas
  horaPrevia.disabled = !activas || !previo.checked
  const controlesDependientes = [previo, dia, horaPrevia]
  controlesDependientes.forEach((control) => {
    control.closest('label')?.classList.toggle('opcion-automatizacion--inactiva', control.disabled)
  })
}

function resumenPreferenciasNotificaciones({ recibir, previo, dia, horaPrevia, zona }) {
  if (!recibir) {
    return 'Se desactivarán los avisos previos y los del día de vencimiento. Las alertas pendientes se cancelarán; tu historial se conserva.'
  }
  const momentos = []
  if (previo) momentos.push(`el día previo a las ${String(horaPrevia).padStart(2, '0')}:00`)
  if (dia) momentos.push('el día del vencimiento a las 09:00')
  return momentos.length
    ? `Se programarán avisos ${momentos.join(' y ')} en ${zona}.`
    : 'No se programarán avisos hasta que actives al menos un momento.'
}

function confirmarPreferenciasNotificaciones(dialogo) {
  if (!dialogo || typeof dialogo.showModal !== 'function') {
    return Promise.resolve(globalThis.confirm('¿Querés guardar estas preferencias de notificaciones?'))
  }
  return new Promise((resolver) => {
    dialogo.addEventListener('close', () => resolver(dialogo.returnValue === 'confirmar'), { once: true })
    dialogo.showModal()
  })
}

export async function inicializarPreferenciasNotificaciones() {
  const formulario = document.querySelector('[data-notificaciones-form]')
  if (!formulario) return
  const recibir = formulario.elements.recibir_notificaciones
  const previo = formulario.elements.notificar_dia_previo
  const dia = formulario.elements.notificar_dia_vencimiento
  const horaPrevia = formulario.elements.hora_notificacion_previa
  const zona = formulario.elements.zona_horaria_notificaciones
  const estado = document.querySelector('[data-push-estado]')
  const dialogo = document.querySelector('[data-confirmar-notificaciones]')
  const resumenConfirmacion = document.querySelector('[data-confirmar-notificaciones-resumen]')
  const zonaDispositivo = Intl.DateTimeFormat().resolvedOptions().timeZone || 'America/Argentina/Cordoba'
  document.querySelector('[data-zona-detectada]').textContent = `Este dispositivo usa ${zonaDispositivo}.`
  poblarZonasHorarias(zona, zonaDispositivo)
  estado.textContent = textoEstadoDispositivo()
  const { data, error } = await supabase
    .from('perfiles')
    .select('recibir_notificaciones,notificar_dia_previo,notificar_dia_vencimiento,zona_horaria_notificaciones,hora_notificacion_previa')
    .single()
  if (error) {
    estado.textContent = 'No pudimos cargar tus preferencias.'
    return
  }
  recibir.checked = data.recibir_notificaciones
  previo.checked = data.notificar_dia_previo
  dia.checked = data.notificar_dia_vencimiento
  seleccionarZonaHoraria(zona, data.zona_horaria_notificaciones)
  horaPrevia.value = String(data.hora_notificacion_previa ?? 9)
  sincronizarDependenciasNotificaciones(recibir, previo, dia, horaPrevia)

  formulario.addEventListener('submit', async (evento) => {
    evento.preventDefault()
    const preferencias = {
      recibir: recibir.checked,
      previo: recibir.checked && previo.checked,
      dia: recibir.checked && dia.checked,
      horaPrevia: Number(horaPrevia.value),
      zona: zona.value,
    }
    resumenConfirmacion.textContent = resumenPreferenciasNotificaciones(preferencias)
    if (!await confirmarPreferenciasNotificaciones(dialogo)) return
    const boton = formulario.querySelector('[type="submit"]')
    boton.disabled = true
    try {
      const { error: errorGuardar } = await supabase.rpc('actualizar_preferencias_notificacion', {
        p_recibir: preferencias.recibir,
        p_dia_previo: preferencias.previo,
        p_dia_vencimiento: preferencias.dia,
        p_zona_horaria: preferencias.zona,
        p_hora_previa: preferencias.horaPrevia,
      })
      if (errorGuardar) throw errorGuardar
      estado.textContent = !preferencias.recibir
        ? 'Notificaciones desactivadas. Los avisos pendientes se cancelaron.'
        : !preferencias.previo && !preferencias.dia
        ? 'Preferencias guardadas. No se programarán avisos hasta elegir al menos un momento.'
        : 'Preferencias guardadas.'
    } catch {
      estado.textContent = 'No pudimos guardar las preferencias.'
    } finally {
      boton.disabled = false
    }
  })

  document.querySelector('[data-zona-dispositivo]').addEventListener('click', () => {
    seleccionarZonaHoraria(zona, zonaDispositivo)
    estado.textContent = `Zona detectada: ${zona.value}. Guardá para aplicarla.`
  })
  recibir.addEventListener('change', () => sincronizarDependenciasNotificaciones(recibir, previo, dia, horaPrevia))
  previo.addEventListener('change', () => sincronizarDependenciasNotificaciones(recibir, previo, dia, horaPrevia))
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
