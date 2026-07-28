import '../components/theme.js'
import { crearCelda, estadoVacio, mostrarAviso, setCargando } from '../components/ui.js'
import { protegerRuta } from '../guards/route-guard.js'
import { cerrarSesion } from '../services/auth.js'
import { invocarFuncion } from '../services/edge.js'
import { cargarEventosAgenda, cargarPortal } from '../services/portal.js'
import { supabase } from '../services/supabase.js'
import { formatearAvisoDia } from '../utils/clasificacion.js'
import { formatearFecha, formatearFechaHora } from '../utils/fechas.js'

let datosPortal
let usuarioActualId
let eventosAgenda = []
let mesAgenda = new Date()
mesAgenda = new Date(mesAgenda.getFullYear(), mesAgenda.getMonth(), 1)
const paginaPortal = document.body.dataset.portalPage || 'inicio'
const tbodyVencimientos = document.querySelector('[data-vencimientos]')
const dialogoEvento = document.querySelector('[data-evento-dialog]')
const formularioEvento = document.querySelector('[data-evento-form]')
const dialogoRegla = document.querySelector('[data-regla-dialog]')
const formularioRegla = document.querySelector('[data-regla-form]')
const formularioAutomatizacion = document.querySelector('[data-auto-form]')
const sincronizacionAutomatica = document.querySelector('[data-auto-sync]')
const eventosAutomaticos = document.querySelector('[data-auto-events]')
const umbralAutomatico = document.querySelector('[data-auto-threshold]')
const GRUPOS = [
  ['tarjetas', 'Tarjetas'],
  ['servicios', 'Servicios'],
  ['suscripciones', 'Suscripciones'],
  ['turnos', 'Turnos'],
  ['otros', 'Otros'],
]

function renderVencimientos(vencimientos) {
  if (!tbodyVencimientos) return
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

function renderCategorias(categorias = {}) {
  const cuerpo = document.querySelector('[data-categorias]')
  if (!cuerpo) return
  cuerpo.replaceChildren()
  const total = GRUPOS.reduce((suma, [clave]) => suma + Number(categorias[clave] || 0), 0)
  GRUPOS.forEach(([clave, etiqueta]) => {
    const cantidad = Number(categorias[clave] || 0)
    const porcentaje = total ? Math.round((cantidad / total) * 100) : 0
    const fila = document.createElement('tr')
    const proporcion = document.createElement('td')
    const medidor = document.createElement('meter')
    medidor.min = 0
    medidor.max = 100
    medidor.value = porcentaje
    medidor.setAttribute('aria-label', `${porcentaje}% de los correos`)
    const valor = document.createElement('span')
    valor.textContent = `${porcentaje}%`
    proporcion.append(medidor, valor)
    fila.append(crearCelda(etiqueta), crearCelda(cantidad), proporcion)
    cuerpo.append(fila)
  })
}

function renderAvisosDia(avisos = []) {
  const lista = document.querySelector('[data-avisos-dia]')
  if (!lista) return
  lista.replaceChildren()
  if (!avisos.length) {
    const vacio = document.createElement('li')
    vacio.className = 'avisos-dia__vacio'
    vacio.textContent = 'No hay vencimientos para hoy.'
    lista.append(vacio)
    return
  }
  avisos.forEach((aviso) => {
    const item = document.createElement('li')
    item.textContent = formatearAvisoDia(aviso)
    lista.append(item)
  })
}

function renderCorreos(correos) {
  const cuerpo = document.querySelector('[data-correos]')
  if (!cuerpo) return
  cuerpo.replaceChildren()
  if (!correos.length) {
    const fila = document.createElement('tr')
    const celda = crearCelda('Todavía no se analizaron correos.')
    celda.colSpan = 6
    fila.append(celda)
    cuerpo.append(fila)
    return
  }
  correos.forEach((item) => {
    const fila = document.createElement('tr')
    fila.append(
      crearCelda(formatearFecha(item.fecha_correo)),
      crearCelda(item.remitente),
      crearCelda(item.asunto),
      crearCelda(item.categoria),
    )
    const grupo = document.createElement('td')
    const selector = document.createElement('select')
    selector.dataset.grupoCorreo = item.id
    selector.setAttribute('aria-label', `Grupo de ${item.asunto || 'correo'}`)
    GRUPOS.forEach(([valor, etiqueta]) => {
      const opcion = document.createElement('option')
      opcion.value = valor
      opcion.textContent = etiqueta
      opcion.selected = item.grupo_resumen === valor
      selector.append(opcion)
    })
    grupo.append(selector)
    fila.append(grupo, crearCelda(item.estado_procesamiento))
    cuerpo.append(fila)
  })
}

function claveFecha(valor) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Argentina/Cordoba',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date(valor))
}

function renderDetalleAgenda(clave) {
  if (!document.querySelector('[data-agenda-dia]')) return
  const seleccionados = eventosAgenda.filter((evento) => claveFecha(evento.fecha_evento) === clave)
  const fecha = new Date(`${clave}T12:00:00`)
  document.querySelector('[data-agenda-dia]').textContent = new Intl.DateTimeFormat('es-AR', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
  }).format(fecha)
  const contenedor = document.querySelector('[data-agenda-eventos]')
  contenedor.replaceChildren()
  if (!seleccionados.length) {
    contenedor.append(estadoVacio('No hay eventos para este día.'))
    return
  }
  seleccionados.forEach((evento) => {
    const tarjeta = document.createElement('article')
    const texto = document.createElement('div')
    const titulo = document.createElement('strong')
    titulo.textContent = evento.titulo || 'Evento de Agenda'
    const fecha = document.createElement('time')
    fecha.dateTime = evento.fecha_evento
    fecha.textContent = evento.es_dia_completo
      ? 'Todo el día'
      : formatearFechaHora(evento.fecha_evento)
    const estado = document.createElement('span')
    estado.textContent = evento.estado_google === 'sincronizado'
      ? 'Sincronizado con Google'
      : evento.estado_google === 'no_conectado'
        ? 'Solo en Agenda'
        : evento.estado_google === 'error'
          ? 'Error de Google · reintento pendiente'
          : 'Google pendiente'
    texto.append(titulo, fecha, estado)
    if (evento.descripcion) {
      const descripcion = document.createElement('p')
      descripcion.textContent = evento.descripcion
      tarjeta.append(texto, descripcion)
    } else {
      tarjeta.append(texto)
    }
    contenedor.append(tarjeta)
  })
}

function renderAgenda() {
  if (!document.querySelector('[data-agenda-grid]')) return
  document.querySelector('[data-agenda-mes]').textContent = new Intl.DateTimeFormat('es-AR', {
    month: 'long',
    year: 'numeric',
  }).format(mesAgenda)
  const grilla = document.querySelector('[data-agenda-grid]')
  grilla.replaceChildren()
  const inicioSemana = (mesAgenda.getDay() + 6) % 7
  const inicio = new Date(mesAgenda)
  inicio.setDate(1 - inicioSemana)
  const hoy = claveFecha(new Date())
  for (let indice = 0; indice < 42; indice += 1) {
    const fecha = new Date(inicio)
    fecha.setDate(inicio.getDate() + indice)
    const clave = [
      fecha.getFullYear(),
      String(fecha.getMonth() + 1).padStart(2, '0'),
      String(fecha.getDate()).padStart(2, '0'),
    ].join('-')
    const eventos = eventosAgenda.filter((evento) => claveFecha(evento.fecha_evento) === clave)
    const dia = document.createElement('button')
    dia.type = 'button'
    dia.className = 'dia-agenda'
    if (fecha.getMonth() !== mesAgenda.getMonth()) dia.classList.add('dia-agenda--otro-mes')
    if (clave === hoy) dia.classList.add('dia-agenda--hoy')
    dia.dataset.agendaFecha = clave
    dia.setAttribute('aria-label', `${fecha.getDate()} de ${new Intl.DateTimeFormat('es-AR', { month: 'long' }).format(fecha)}, ${eventos.length} eventos`)
    const numero = document.createElement('span')
    numero.textContent = fecha.getDate()
    dia.append(numero)
    eventos.slice(0, 2).forEach((evento) => {
      const etiqueta = document.createElement('small')
      etiqueta.textContent = evento.titulo || 'Evento'
      dia.append(etiqueta)
    })
    if (eventos.length > 2) {
      const mas = document.createElement('small')
      mas.textContent = `+${eventos.length - 2} más`
      dia.append(mas)
    }
    grilla.append(dia)
  }
}

async function cargarMesAgenda() {
  if (!document.querySelector('[data-agenda-grid]')) return
  const inicioSemana = (mesAgenda.getDay() + 6) % 7
  const desde = new Date(mesAgenda)
  desde.setDate(1 - inicioSemana)
  const hasta = new Date(desde)
  hasta.setDate(hasta.getDate() + 42)
  eventosAgenda = await cargarEventosAgenda(desde.toISOString(), hasta.toISOString())
  renderAgenda()
  const hoy = new Date()
  const fechaInicial =
    hoy.getFullYear() === mesAgenda.getFullYear() && hoy.getMonth() === mesAgenda.getMonth()
      ? claveFecha(hoy)
      : claveFecha(mesAgenda)
  const diaInicial = document.querySelector(`[data-agenda-fecha="${fechaInicial}"]`)
  if (diaInicial) diaInicial.dataset.seleccionado = 'true'
  renderDetalleAgenda(fechaInicial)
}

function definirTexto(selector, valor) {
  const elemento = document.querySelector(selector)
  if (elemento) elemento.textContent = valor
}

function renderPortal(datos) {
  const resumen = datos.resumen || {}
  renderAvisosDia(Array.isArray(resumen.avisos_del_dia) ? resumen.avisos_del_dia : [])
  Object.entries({
    dias: resumen.dias_usando_agenkin || 1,
    correos: resumen.correos_analizados_total || 0,
    'correos-hoy': resumen.correos_analizados_hoy || 0,
  }).forEach(([nombre, valor]) => definirTexto(`[data-metrica="${nombre}"]`, valor))
  renderVencimientos(datos.vencimientos)
  renderCorreos(datos.correos)
  renderCategorias(resumen.categorias_resumen)

  const reglas = document.querySelector('[data-reglas]')
  if (reglas) {
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
  }

  const conexion = datos.conexion || {}
  const estadoGmail = conexion.gmail_conectado ? 'Conectado' : 'Desconectado'
  const estadoCalendar = conexion.calendar_conectado ? 'Conectado' : 'Desconectado'
  const indicadores = [
    [document.querySelector('[data-header-gmail]'), estadoGmail, conexion.gmail_conectado],
    [document.querySelector('[data-header-calendar]'), estadoCalendar, conexion.calendar_conectado],
    [document.querySelector('[data-servicio-gmail]'), estadoGmail, conexion.gmail_conectado],
    [document.querySelector('[data-servicio-calendar]'), estadoCalendar, conexion.calendar_conectado],
  ].filter(([indicador]) => indicador)
  indicadores.forEach(([indicador, texto, conectado]) => {
    indicador.textContent = texto
    indicador.dataset.estado = conectado ? 'conectado' : 'desconectado'
  })
  definirTexto(
    '[data-servicio-gmail-detalle]',
    conexion.gmail_conectado
      ? `${conexion.gmail_email || conexion.google_email || 'Cuenta de Google'} · última lectura ${formatearFechaHora(conexion.gmail_ultima_lectura_en)}`
      : 'Sin cuenta asociada',
  )
  definirTexto(
    '[data-servicio-calendar-detalle]',
    conexion.calendar_conectado
      ? `${conexion.calendar_email || conexion.google_email || 'Cuenta de Google'} · última sincronización ${formatearFechaHora(conexion.calendar_ultima_sincronizacion_en)}`
      : 'Sin cuenta asociada',
  )
  definirTexto('[data-header-agenda]', formatearFechaHora(conexion.agenda_ultima_actualizacion_en))
  document.querySelector('[data-connect-gmail]')?.classList.toggle('oculto', Boolean(conexion.gmail_conectado))
  document.querySelector('[data-disconnect-gmail]')?.classList.toggle('oculto', !conexion.gmail_conectado)
  document.querySelector('[data-connect-calendar]')?.classList.toggle('oculto', Boolean(conexion.calendar_conectado))
  document.querySelector('[data-disconnect-calendar]')?.classList.toggle('oculto', !conexion.calendar_conectado)
  document.querySelector('[data-revoke-google]')?.classList.toggle('oculto', !conexion.conectado)
  if (formularioAutomatizacion) {
    sincronizacionAutomatica.checked = Boolean(conexion.sincronizacion_automatica)
    eventosAutomaticos.checked = Boolean(conexion.creacion_automatica_eventos)
    umbralAutomatico.value = Number(conexion.umbral_confianza_automatica || 0.9).toFixed(2)
    formularioAutomatizacion.querySelectorAll('input, select, button').forEach((control) => {
      control.disabled = !conexion.gmail_conectado
    })
    definirTexto('[data-auto-estado]', conexion.sincronizacion_automatica ? 'Activa' : 'Desactivada')
    const pendientes = Number(conexion.tareas_pendientes || 0)
    const conError = Number(conexion.tareas_error || 0)
    const ultima = formatearFecha(conexion.ultima_sincronizacion_exitosa)
    definirTexto(
      '[data-auto-detalle]',
      conexion.gmail_conectado
        ? `${pendientes} en cola · ${conError} con error · última revisión completa: ${ultima}`
        : 'Conectá Gmail para activar esta función.',
    )
  }

  const suscripcion = resumen.suscripcion || {}
  definirTexto('[data-plan-cabecera]', suscripcion.plan || 'Sin plan')
  definirTexto(
    '[data-plan-estado]',
    suscripcion.estado ? `${suscripcion.estado} · vence ${formatearFecha(suscripcion.fecha_vencimiento)}` : 'Sin suscripción',
  )
  const campos = {
    plan: suscripcion.plan || 'Sin plan',
    estado: suscripcion.estado || 'Sin suscripción',
    inicio: formatearFecha(suscripcion.fecha_inicio),
    vencimiento: formatearFecha(suscripcion.fecha_vencimiento),
  }
  Object.entries(campos).forEach(([campo, valor]) => definirTexto(`[data-suscripcion="${campo}"]`, valor))
  const usados = Number(suscripcion.correos_mes || 0)
  const limite = Number(suscripcion.limite_correos_mensuales || 0)
  const uso = document.querySelector('[data-uso]')
  if (uso) uso.value = limite ? Math.min(100, (usados / limite) * 100) : 0
  definirTexto('[data-uso-texto]', `${usados} de ${limite || '—'} correos procesados`)
  const botonPlan = document.querySelector('[data-request-plan]')
  if (botonPlan) {
    botonPlan.disabled = Boolean(suscripcion.solicitud_mejora_pendiente)
    botonPlan.textContent = suscripcion.solicitud_mejora_pendiente ? 'Solicitud enviada' : 'Solicitar mejora'
  }
  definirTexto(
    '[data-dashboard-fecha]',
    new Intl.DateTimeFormat('es-AR', { weekday: 'long', day: 'numeric', month: 'long' }).format(new Date()),
  )
}

async function refrescar() {
  datosPortal = await cargarPortal(paginaPortal)
  renderPortal(datosPortal)
  if (paginaPortal === 'agenda') await cargarMesAgenda()
}

async function iniciar() {
  try {
    const contexto = await protegerRuta('app')
    if (!contexto) return
    usuarioActualId = contexto.user.id
    definirTexto('[data-nombre]', contexto.perfil.nombre_completo?.split(' ')[0] || 'bienvenido')
    definirTexto('[data-avatar]', (contexto.perfil.nombre_completo || contexto.perfil.email || 'A').slice(0, 1).toUpperCase())
    await refrescar()
    const parametros = new URLSearchParams(window.location.search)
    if (parametros.get('google') === 'conectado') {
      const servicio = parametros.get('servicio') === 'calendar' ? 'Google Calendar' : 'Gmail'
      mostrarAviso(`${servicio} quedó conectado.`, 'exito')
    } else if (parametros.get('motivo') === 'cuenta_google_distinta') {
      mostrarAviso('Usá la misma cuenta Google que ya está asociada al otro servicio.', 'error')
    } else if (parametros.get('google') === 'error') {
      mostrarAviso('No se pudo completar la conexión con Google. Intentá nuevamente.', 'error')
    }
    if (parametros.has('google')) {
      window.history.replaceState({}, '', `${window.location.pathname}${window.location.hash}`)
    }
  } catch {
    mostrarAviso('No pudimos cargar el portal. Revisá la conexión y la configuración de Supabase.', 'error')
  }
}

document.querySelector('[data-menu]')?.addEventListener('click', (evento) => {
  const abierto = document.body.classList.toggle('menu-abierto')
  evento.currentTarget.setAttribute('aria-expanded', String(abierto))
})
document.querySelector('[data-logout]')?.addEventListener('click', async (evento) => {
  setCargando(evento.currentTarget, true)
  try { await cerrarSesion() } catch { mostrarAviso('No se pudo cerrar la sesión.', 'error') }
})
document.querySelector('[data-request-plan]')?.addEventListener('click', async (evento) => {
  const boton = evento.currentTarget
  let actualizar = false
  setCargando(boton, true, 'Enviando…')
  try {
    const { error } = await supabase.from('solicitudes_mejora_plan').insert({ usuario_id: usuarioActualId })
    if (error?.code === '23505') {
      mostrarAviso('Ya tenés una solicitud de mejora pendiente.', 'info')
    } else if (error) {
      throw error
    } else {
      mostrarAviso('Solicitud enviada. El administrador revisará tu plan.', 'exito')
    }
    actualizar = true
  } catch {
    mostrarAviso('No se pudo enviar la solicitud de mejora.', 'error')
  } finally {
    setCargando(boton, false)
    if (actualizar) await refrescar()
  }
})
document.querySelector('[data-scan]')?.addEventListener('click', async (evento) => {
  const boton = evento.currentTarget
  setCargando(boton, true, 'Actualizando…')
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
    mostrarAviso(`Agenda actualizada. ${mensaje}`, errores ? 'error' : 'exito')
    await refrescar()
  } catch (error) {
    mostrarAviso(error.message, 'error')
  } finally { setCargando(boton, false) }
})
async function conectarServicio(servicio, boton) {
  setCargando(boton, true, 'Preparando conexión…')
  try {
    const { url } = await invocarFuncion('google-oauth-start', { servicio })
    window.location.assign(url)
  } catch (error) {
    mostrarAviso(error.message, 'error')
    setCargando(boton, false)
  }
}

async function desconectarServicio(servicio, boton) {
  const nombre = servicio === 'gmail' ? 'Gmail' : 'Google Calendar'
  if (!confirm(`¿Desactivar ${nombre} en AgenKin?`)) return

  setCargando(boton, true, 'Desactivando…')
  try {
    await invocarFuncion('google-disconnect', { servicio })
    mostrarAviso(`${nombre} fue desactivado.`, 'exito')
    await refrescar()
  } catch (error) {
    mostrarAviso(error.message, 'error')
  } finally {
    setCargando(boton, false)
  }
}

document.querySelector('[data-connect-gmail]')?.addEventListener('click', (evento) => {
  conectarServicio('gmail', evento.currentTarget)
})
document.querySelector('[data-connect-calendar]')?.addEventListener('click', (evento) => {
  conectarServicio('calendar', evento.currentTarget)
})
document.querySelector('[data-disconnect-gmail]')?.addEventListener('click', (evento) => {
  desconectarServicio('gmail', evento.currentTarget)
})
document.querySelector('[data-disconnect-calendar]')?.addEventListener('click', (evento) => {
  desconectarServicio('calendar', evento.currentTarget)
})
document.querySelector('[data-revoke-google]')?.addEventListener('click', async (evento) => {
  if (!confirm('Esto revocará el acceso de AgenKin a Google y desconectará Gmail y Calendar. ¿Continuar?')) return

  const boton = evento.currentTarget
  setCargando(boton, true, 'Revocando…')
  try {
    await invocarFuncion('google-disconnect', { servicio: 'todo' })
    mostrarAviso('El acceso de Google fue revocado.', 'exito')
    await refrescar()
  } catch (error) {
    mostrarAviso(error.message, 'error')
  } finally {
    setCargando(boton, false)
  }
})

document.querySelector('[data-correos]')?.addEventListener('change', async (evento) => {
  const selector = evento.target.closest('[data-grupo-correo]')
  if (!selector) return

  selector.disabled = true
  try {
    const { error } = await supabase.rpc('actualizar_grupo_correo', {
      correo_id: selector.dataset.grupoCorreo,
      grupo: selector.value,
    })
    if (error) throw error
    mostrarAviso('La categoría fue actualizada.', 'exito')
    await refrescar()
  } catch (error) {
    mostrarAviso(error.message, 'error')
    await refrescar()
  }
})

document.querySelector('[data-agenda-anterior]')?.addEventListener('click', async () => {
  mesAgenda = new Date(mesAgenda.getFullYear(), mesAgenda.getMonth() - 1, 1)
  await cargarMesAgenda()
})
document.querySelector('[data-agenda-siguiente]')?.addEventListener('click', async () => {
  mesAgenda = new Date(mesAgenda.getFullYear(), mesAgenda.getMonth() + 1, 1)
  await cargarMesAgenda()
})
document.querySelector('[data-agenda-hoy]')?.addEventListener('click', async () => {
  const hoy = new Date()
  mesAgenda = new Date(hoy.getFullYear(), hoy.getMonth(), 1)
  await cargarMesAgenda()
})
document.querySelector('[data-agenda-grid]')?.addEventListener('click', (evento) => {
  const dia = evento.target.closest('[data-agenda-fecha]')
  if (!dia) return
  document.querySelectorAll('[data-agenda-fecha]').forEach((elemento) => {
    elemento.dataset.seleccionado = String(elemento === dia)
  })
  renderDetalleAgenda(dia.dataset.agendaFecha)
})
eventosAutomaticos?.addEventListener('change', () => {
  if (eventosAutomaticos.checked) sincronizacionAutomatica.checked = true
})
sincronizacionAutomatica?.addEventListener('change', () => {
  if (!sincronizacionAutomatica.checked) eventosAutomaticos.checked = false
})
formularioAutomatizacion?.addEventListener('submit', async (evento) => {
  evento.preventDefault()
  const activarEventos = eventosAutomaticos.checked
  if (activarEventos && !datosPortal.conexion?.creacion_automatica_eventos) {
    const aceptado = confirm(
      'AgenKin creará eventos futuros automáticamente cuando la IA no requiera revisión y alcance la confianza elegida. ¿Querés activarlo?',
    )
    if (!aceptado) return
  }
  const boton = evento.submitter
  setCargando(boton, true, 'Guardando…')
  try {
    const { error } = await supabase.rpc('configurar_automatizacion_google', {
      p_sincronizacion_automatica: sincronizacionAutomatica.checked,
      p_creacion_automatica_eventos: activarEventos,
      p_umbral_confianza: Number(umbralAutomatico.value),
    })
    if (error) throw error
    mostrarAviso('La automatización fue actualizada.', 'exito')
    await refrescar()
  } catch {
    mostrarAviso('No se pudo actualizar la automatización.', 'error')
  } finally {
    setCargando(boton, false)
  }
})
tbodyVencimientos?.addEventListener('click', async (evento) => {
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
formularioEvento?.addEventListener('submit', async (evento) => {
  if (evento.submitter?.value === 'cancel') return
  evento.preventDefault()
  const boton = evento.submitter
  setCargando(boton, true, 'Creando…')
  try {
    const payload = Object.fromEntries(new FormData(formularioEvento))
    payload.recordatorio = Number(payload.recordatorio)
    const respuesta = await invocarFuncion('create-calendar-event', payload)
    dialogoEvento.close()
    const detalleGoogle =
      respuesta.google_estado === 'sincronizado'
        ? ' y sincronizado con Google Calendar'
        : respuesta.google_estado === 'pendiente'
          ? '; Google Calendar quedó pendiente de reintento'
          : ''
    mostrarAviso(`Evento guardado en Agenda${detalleGoogle}.`, 'exito')
    await refrescar()
  } catch (error) { mostrarAviso(error.message, 'error') } finally { setCargando(boton, false) }
})
document.querySelector('[data-nueva-regla]')?.addEventListener('click', () => dialogoRegla.showModal())
formularioRegla?.addEventListener('submit', async (evento) => {
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
document.querySelector('[data-reglas]')?.addEventListener('click', async (evento) => {
  const id = evento.target.dataset.eliminarRegla
  if (!id || !confirm('¿Eliminar esta regla?')) return
  const { error } = await supabase.from('reglas_usuario').delete().eq('id', id)
  if (error) mostrarAviso('No se pudo eliminar la regla.', 'error')
  else await refrescar()
})

iniciar()
