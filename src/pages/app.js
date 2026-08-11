import '../components/theme.js'
import { crearCelda, estadoVacio, mostrarAviso, setCargando } from '../components/ui.js'
import { protegerRuta } from '../guards/route-guard.js'
import { cerrarSesion } from '../services/auth.js'
import { invocarFuncion } from '../services/edge.js'
import { cargarEventosAgenda, cargarPortal } from '../services/portal.js'
import {
  desactivarPushDispositivoActual,
  inicializarCentroNotificaciones,
  inicializarPreferenciasNotificaciones,
} from '../services/notifications.js'
import { supabase } from '../services/supabase.js'
import { formatearAvisoDia, formatearMontoARS } from '../utils/clasificacion.js'
import { esFechaActualOFutura, fechaActualIso, formatearFecha, formatearFechaHora } from '../utils/fechas.js'

let datosPortal
let usuarioActualId
let eventosAgenda = []
let mesAgenda = new Date()
mesAgenda = new Date(mesAgenda.getFullYear(), mesAgenda.getMonth(), 1)
let temporizadorSincronizacion
let paginaCorreos = 1
const paginaPortal = document.body.dataset.portalPage || 'inicio'
const tbodyVencimientos = document.querySelector('[data-vencimientos]')
const dialogoEvento = document.querySelector('[data-evento-dialog]')
const formularioEvento = document.querySelector('[data-evento-form]')
const dialogoEventoManual = document.querySelector('[data-evento-manual-dialog]')
const formularioEventoManual = document.querySelector('[data-evento-manual-form]')
const dialogoRegla = document.querySelector('[data-regla-dialog]')
const formularioRegla = document.querySelector('[data-regla-form]')
const dialogoRevisionCorreo = document.querySelector('[data-revision-correo-dialog]')
const formularioRevisionCorreo = document.querySelector('[data-revision-correo-form]')
const formularioAutomatizacion = document.querySelector('[data-auto-form]')
const sincronizacionAutomatica = document.querySelector('[data-auto-sync]')
const eventosAutomaticos = document.querySelector('[data-auto-events]')
const umbralAutomatico = document.querySelector('[data-auto-threshold]')
const botonMenu = document.querySelector('[data-menu]')
const barraLateral = document.querySelector('.barra-lateral')
const botonMenuLateral = document.querySelector('[data-menu-lateral-toggle]')
const CLAVE_MENU_LATERAL = 'agenkin_menu_lateral_colapsado'
const GRUPOS = [
  ['tarjetas', 'Tarjetas'],
  ['servicios', 'Servicios'],
  ['suscripciones', 'Suscripciones'],
  ['turnos', 'Turnos'],
  ['otros', 'Otros'],
]

function eventoAgendaDe(item) {
  return Array.isArray(item.eventos_calendar)
    ? item.eventos_calendar[0] || null
    : item.eventos_calendar || null
}

function estadoVisibleVencimiento(item) {
  if (item.estado !== 'evento_creado') return item.estado
  const evento = eventoAgendaDe(item)
  if (!evento || evento.estado_google === 'no_conectado') return 'Sólo en Agenda'
  if (evento.estado_google === 'sincronizado') return 'Sincronizado con Google'
  if (evento.estado_google === 'error') return 'Error de Google'
  return 'Google pendiente'
}

function renderVencimientos(vencimientos) {
  if (!tbodyVencimientos) return
  tbodyVencimientos.replaceChildren()
  const visibles = vencimientos.filter((item) => esFechaActualOFutura(item.fecha_vencimiento))
  if (!visibles.length) {
    const fila = document.createElement('tr')
    const celda = crearCelda('Todavía no hay vencimientos detectados.')
    celda.colSpan = 6
    fila.append(celda)
    tbodyVencimientos.append(fila)
    return
  }
  const hoy = fechaActualIso()
  const ordenados = [...visibles].sort((a, b) => {
    const aVencido = a.estado === 'vencido' || a.fecha_vencimiento < hoy
    const bVencido = b.estado === 'vencido' || b.fecha_vencimiento < hoy
    if (aVencido !== bVencido) return aVencido ? 1 : -1
    return aVencido
      ? b.fecha_vencimiento.localeCompare(a.fecha_vencimiento)
      : a.fecha_vencimiento.localeCompare(b.fecha_vencimiento)
  })
  ordenados.forEach((item) => {
    const vencido = item.estado === 'vencido' ||
      item.fecha_vencimiento < hoy
    const estadoVisible = vencido ? 'Vencido' : estadoVisibleVencimiento(item)
    const fila = document.createElement('tr')
    if (vencido) fila.classList.add('fila--vencida')
    fila.append(
      crearCelda(item.correos_procesados?.asunto || item.titulo),
      crearCelda(item.tipo),
      crearCelda(formatearFecha(item.fecha_vencimiento)),
      crearCelda(`${Math.round(item.confianza * 100)}%`),
      crearCelda(estadoVisible),
    )
    const acciones = document.createElement('td')
    if (vencido || item.estado === 'descartado') {
      acciones.textContent = vencido ? 'Sin acciones' : 'Finalizado'
      fila.append(acciones)
      tbodyVencimientos.append(fila)
      return
    }
    if (item.estado !== 'evento_creado') {
      const revisar = document.createElement('button')
      revisar.className = 'boton boton--mini'
      revisar.textContent = item.estado === 'confirmado' ? 'Crear evento' : 'Revisar'
      revisar.dataset.revisar = item.id
      acciones.append(revisar)
    }
    const descartar = document.createElement('button')
    descartar.className = 'boton boton--mini boton--texto'
    descartar.textContent = item.estado === 'evento_creado'
      ? 'Descartar y eliminar'
      : 'Descartar'
    descartar.dataset.descartar = item.id
    acciones.append(descartar)
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
      crearCelda(item.remitente || (item.detalle_compactado ? 'Dato eliminado' : '—')),
      crearCelda(item.asunto || (item.detalle_compactado ? 'Dato eliminado' : 'Sin asunto')),
      crearDetalleCorreo(item),
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
    selector.disabled = Boolean(item.detalle_compactado)
    if (item.detalle_compactado) {
      selector.setAttribute('aria-label', 'Detalle compactado; la categoría histórica ya no se puede editar')
    }
    grupo.append(selector)
    fila.append(grupo, crearCelda(etiquetaEstadoCorreo(item)))
    cuerpo.append(fila)
  })
}

function renderPaginacionCorreos(total = 0) {
  const paginas = Math.max(1, Math.ceil(Number(total) / 25))
  const estado = document.querySelector('[data-correos-pagina]')
  if (estado) estado.textContent = `${paginaCorreos} de ${paginas}`
  const anterior = document.querySelector('[data-correos-anterior]')
  const siguiente = document.querySelector('[data-correos-siguiente]')
  if (anterior) anterior.disabled = paginaCorreos <= 1
  if (siguiente) siguiente.disabled = paginaCorreos >= paginas
}

function primerVencimiento(correo) {
  const vencimientos = correo.vencimientos_detectados
  return Array.isArray(vencimientos) ? vencimientos[0] : vencimientos
}

function etiquetaCategoria(categoria) {
  const texto = String(categoria || 'otro').replaceAll('_', ' ')
  return `${texto.charAt(0).toUpperCase()}${texto.slice(1)}`
}

function errorCorreoTemporal(codigo) {
  return [
    'PROCESAMIENTO_EN_CURSO',
    'AI_LIMITE_TEMPORAL',
    'AI_PRESUPUESTO_DIARIO',
    'AI_TIMEOUT',
    'AI_PROVEEDOR_NO_DISPONIBLE',
    'GOOGLE_TEMPORAL',
  ].includes(codigo)
}

function etiquetaEstadoCorreo(correo) {
  if (correo.requiere_revision) return 'Requiere revisión'
  return correo.estado_procesamiento === 'error' && errorCorreoTemporal(correo.error_procesamiento)
    ? 'pendiente'
    : correo.estado_procesamiento
}

function crearDetalleCorreo(correo) {
  const celda = document.createElement('td')
  celda.className = 'detalle-ia'
  const titulo = document.createElement('strong')
  const resumen = document.createElement('small')
  const metadatos = document.createElement('span')
  const vencimiento = primerVencimiento(correo)

  if (correo.detalle_compactado) {
    titulo.textContent = 'Detalle compactado'
    resumen.textContent = 'Se conserva únicamente el registro antirrepetición y la métrica histórica.'
  } else if (correo.requiere_revision) {
    titulo.textContent = 'Requiere revisión'
    resumen.textContent = 'Comprobá los candidatos detectados antes de crear un evento.'
    const revisar = document.createElement('button')
    revisar.type = 'button'
    revisar.className = 'boton boton--mini boton--revision-correo'
    revisar.dataset.revisarCorreo = correo.id
    revisar.textContent = 'Revisar'
    celda.append(titulo, resumen, revisar)
    return celda
  } else if (correo.error_procesamiento === 'AI_LIMITE_TEMPORAL') {
    titulo.textContent = 'Análisis pendiente'
    resumen.textContent = 'El servicio de IA alcanzó su límite temporal. AgenKin hará un último intento al día siguiente.'
  } else if (correo.error_procesamiento === 'AI_PRESUPUESTO_DIARIO') {
    titulo.textContent = 'Análisis diferido'
    resumen.textContent = 'La IA alcanzó su capacidad disponible. AgenKin retomará este correo automáticamente.'
  } else if (correo.error_procesamiento === 'AI_REINTENTOS_AGOTADOS') {
    titulo.textContent = 'Análisis incompleto'
    resumen.textContent = 'No se pudo completar el análisis inteligente después de dos días.'
  } else if (correo.error_procesamiento === 'PROCESAMIENTO_EN_CURSO') {
    titulo.textContent = 'Procesando correo'
    resumen.textContent = 'AgenKin está analizando este mensaje.'
  } else if (correo.estado_procesamiento === 'error') {
    titulo.textContent = 'Análisis incompleto'
    resumen.textContent = errorCorreoTemporal(correo.error_procesamiento)
      ? 'AgenKin lo reintentará automáticamente.'
      : 'No se pudo completar el análisis.'
  } else if (correo.duplicado_funcional) {
    titulo.textContent = 'Compromiso duplicado'
    resumen.textContent = 'Ya estaba guardado en tu Agenda desde otra cuenta o correo.'
  } else if (vencimiento) {
    titulo.textContent = vencimiento.titulo || etiquetaCategoria(correo.categoria)
    resumen.textContent = vencimiento.descripcion || 'Se detectó una fecha accionable.'
    metadatos.textContent = [
      `Vence ${formatearFecha(vencimiento.fecha_vencimiento)}`,
      formatearMontoARS(vencimiento.monto, null),
    ].filter(Boolean).join(' · ')
  } else {
    titulo.textContent = etiquetaCategoria(correo.categoria)
    resumen.textContent = correo.relevante
      ? 'Requiere revisión: no se determinó una fecha.'
      : 'Sin fecha accionable.'
  }

  celda.append(titulo, resumen)
  if (metadatos.textContent) celda.append(metadatos)
  return celda
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
    dia.setAttribute('aria-pressed', 'false')
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

async function cargarMesAgenda(fechaPreferida) {
  if (!document.querySelector('[data-agenda-grid]')) return
  const inicioSemana = (mesAgenda.getDay() + 6) % 7
  const desde = new Date(mesAgenda)
  desde.setDate(1 - inicioSemana)
  const hasta = new Date(desde)
  hasta.setDate(hasta.getDate() + 42)
  eventosAgenda = await cargarEventosAgenda(desde.toISOString(), hasta.toISOString())
  renderAgenda()
  const hoy = new Date()
  const fechaInicial = fechaPreferida || (
    hoy.getFullYear() === mesAgenda.getFullYear() && hoy.getMonth() === mesAgenda.getMonth()
      ? claveFecha(hoy)
      : claveFecha(mesAgenda)
  )
  const diaInicial = document.querySelector(`[data-agenda-fecha="${fechaInicial}"]`)
  if (diaInicial) {
    diaInicial.dataset.seleccionado = 'true'
    diaInicial.setAttribute('aria-pressed', 'true')
  }
  renderDetalleAgenda(fechaInicial)
}

function definirTexto(selector, valor) {
  const elemento = document.querySelector(selector)
  if (elemento) elemento.textContent = valor
}

function crearBotonCuenta(texto, clase, datos = {}) {
  const boton = document.createElement('button')
  boton.type = 'button'
  boton.className = clase
  boton.textContent = texto
  Object.entries(datos).forEach(([nombre, valor]) => {
    boton.dataset[nombre] = valor
  })
  return boton
}

function renderCuentasGoogle(cuentas = [], calendar = {}) {
  const contenedor = document.querySelector('[data-gmail-cuentas]')
  if (!contenedor) return
  contenedor.replaceChildren()
  if (!cuentas.length) {
    contenedor.append(estadoVacio('Todavía no conectaste una cuenta Gmail.'))
    return
  }

  cuentas.forEach((cuenta) => {
    const tarjeta = document.createElement('article')
    tarjeta.className = 'cuenta-google'
    const identidad = document.createElement('div')
    identidad.className = 'cuenta-google__identidad'
    const icono = document.createElement('span')
    icono.className = 'servicio-icono'
    icono.textContent = 'G'
    icono.setAttribute('aria-hidden', 'true')
    const textos = document.createElement('div')
    const email = document.createElement('strong')
    email.textContent = cuenta.email || 'Cuenta Google'
    const detalle = document.createElement('small')
    const pendientes = Number(cuenta.tareas_pendientes || 0)
    const errores = Number(cuenta.tareas_error || 0)
    detalle.textContent = cuenta.error_ultima_sincronizacion
      ? `Error reciente: ${cuenta.error_ultima_sincronizacion} · ${pendientes} pendientes`
      : `Última lectura: ${formatearFechaHora(cuenta.ultima_lectura_en)} · ${pendientes} pendientes · ${errores} con error`
    textos.append(email, detalle)
    identidad.append(icono, textos)

    const estado = document.createElement('span')
    estado.className = 'cuenta-google__estado'
    estado.dataset.estado = cuenta.conectado ? 'conectado' : 'desconectado'
    estado.textContent = cuenta.estado === 'token_vencido'
      ? 'Token vencido'
      : cuenta.conectado ? 'Gmail conectado' : 'Desconectado'

    const acciones = document.createElement('div')
    acciones.className = 'cuenta-google__acciones'
    if (!cuenta.conectado) {
      acciones.append(crearBotonCuenta(
        'Reconectar Gmail',
        'boton boton--mini boton--secundario',
        { reconnectGmail: 'true' },
      ))
    } else if (calendar.conexion_id === cuenta.id) {
      acciones.append(
        crearBotonCuenta(
          'Volver a autorizar Calendar',
          'boton boton--mini boton--secundario',
          { useCalendar: cuenta.id },
        ),
        crearBotonCuenta(
          'Desactivar Calendar',
          'boton boton--mini boton--texto',
          { disconnectGoogle: 'calendar', conexionId: cuenta.id },
        ),
      )
    } else {
      acciones.append(
        crearBotonCuenta(
          'Usar para Calendar',
          'boton boton--mini boton--secundario',
          { useCalendar: cuenta.id },
        ),
      )
    }
    if (cuenta.conectado) {
      acciones.append(crearBotonCuenta(
        'Desactivar Gmail',
        'boton boton--mini boton--texto',
        { disconnectGoogle: 'gmail', conexionId: cuenta.id },
      ))
    }
    acciones.append(crearBotonCuenta(
      'Revocar acceso',
      'boton boton--mini boton--peligro',
      { revokeGoogle: cuenta.id },
    ))
    tarjeta.append(identidad, estado, acciones)
    contenedor.append(tarjeta)
  })
}

function seguirSincronizacion(cantidadPendiente) {
  window.clearTimeout(temporizadorSincronizacion)
  if (!cantidadPendiente || !['inicio', 'configuracion'].includes(paginaPortal)) return
  temporizadorSincronizacion = window.setTimeout(async () => {
    try {
      await refrescar()
    } catch {
      window.clearTimeout(temporizadorSincronizacion)
    }
  }, 5000)
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
  renderPaginacionCorreos(datos.correos_total)
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
  const gmail = conexion.gmail || { usadas: 0, limite: 1, cuentas: [] }
  const calendar = conexion.calendar || { conectado: false }
  const cuentas = Array.isArray(gmail.cuentas) ? gmail.cuentas : []
  const gmailConectado = Number(gmail.usadas || 0) > 0
  const espaciosDisponibles = Math.max(0, Number(gmail.limite || 1) - Number(gmail.usadas || 0))
  const estadoGmail = gmailConectado
    ? `${gmail.usadas} de ${gmail.limite} conectadas · ${espaciosDisponibles} disponible${espaciosDisponibles === 1 ? '' : 's'}`
    : 'Desconectado'
  const estadoCalendar = calendar.conectado ? 'Conectado' : 'Desconectado'
  const indicadores = [
    [document.querySelector('[data-header-gmail]'), estadoGmail, gmailConectado],
    [document.querySelector('[data-header-calendar]'), estadoCalendar, calendar.conectado],
    [document.querySelector('[data-servicio-gmail]'), estadoGmail, gmailConectado],
    [document.querySelector('[data-servicio-calendar]'), estadoCalendar, calendar.conectado],
  ].filter(([indicador]) => indicador)
  indicadores.forEach(([indicador, texto, conectado]) => {
    indicador.textContent = texto
    indicador.dataset.estado = conectado ? 'conectado' : 'desconectado'
  })
  definirTexto(
    '[data-servicio-gmail-detalle]',
    gmailConectado
      ? `${gmail.usadas} cuenta${gmail.usadas === 1 ? '' : 's'} · última lectura ${formatearFechaHora(conexion.gmail_ultima_lectura_en)}`
      : 'Sin cuentas asociadas',
  )
  definirTexto(
    '[data-servicio-calendar-detalle]',
    calendar.conectado
      ? `${calendar.email || 'Cuenta de Google'} · ${Number(calendar.eventos_pendientes || 0)} pendientes · ${Number(calendar.eventos_error || 0)} con error · última sincronización ${formatearFechaHora(calendar.ultima_sincronizacion_en)}`
      : 'Sin cuenta asociada',
  )
  definirTexto('[data-header-agenda]', formatearFechaHora(conexion.agenda_ultima_actualizacion_en))
  const botonAgregar = document.querySelector('[data-connect-gmail]')
  if (botonAgregar) {
    const completo = Number(gmail.usadas || 0) >= Number(gmail.limite || 1)
    botonAgregar.disabled = completo
    botonAgregar.textContent = completo ? 'Límite de cuentas Gmail alcanzado' : 'Agregar cuenta Gmail'
    botonAgregar.title = completo
      ? 'Para conectar otra cuenta, desconectá una existente o cambiá de plan.'
      : `${espaciosDisponibles} espacio${espaciosDisponibles === 1 ? '' : 's'} disponible${espaciosDisponibles === 1 ? '' : 's'}`
  }
  renderCuentasGoogle(cuentas, calendar)
  if (formularioAutomatizacion) {
    sincronizacionAutomatica.checked = Boolean(conexion.sincronizacion_automatica)
    eventosAutomaticos.checked = Boolean(conexion.creacion_automatica_eventos)
    umbralAutomatico.value = Number(conexion.umbral_confianza_automatica || 0.9).toFixed(2)
    formularioAutomatizacion.querySelectorAll('input, select, button').forEach((control) => {
      control.disabled = !gmailConectado
    })
    definirTexto('[data-auto-estado]', conexion.sincronizacion_automatica ? 'Activa' : 'Desactivada')
    const pendientes = Number(conexion.tareas_pendientes || 0)
    const conError = Number(conexion.tareas_error || 0)
    const ultima = formatearFecha(conexion.ultima_sincronizacion_exitosa)
    definirTexto(
      '[data-auto-detalle]',
      gmailConectado
        ? `${pendientes} en cola · ${conError} con error · última revisión completa: ${ultima}`
        : 'Conectá Gmail para activar esta función.',
    )
  }
  seguirSincronizacion(Number(conexion.tareas_pendientes || 0))

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
  const usados = Number(suscripcion.cuentas_gmail_usadas || 0)
  const limite = Number(suscripcion.limite_cuentas_gmail || 0)
  const uso = document.querySelector('[data-uso]')
  if (uso) uso.value = limite ? Math.min(100, (usados / limite) * 100) : 0
  const disponibles = Math.max(0, limite - usados)
  definirTexto(
    '[data-uso-texto]',
    `${usados} de ${limite || '—'} cuentas Gmail conectadas · ${disponibles} espacio${disponibles === 1 ? '' : 's'} disponible${disponibles === 1 ? '' : 's'}`,
  )
  const botonPlan = document.querySelector('[data-request-plan]')
  if (botonPlan) {
    botonPlan.classList.toggle('oculto', Boolean(suscripcion.es_interno))
    botonPlan.disabled = Boolean(suscripcion.solicitud_mejora_pendiente)
    botonPlan.textContent = suscripcion.solicitud_mejora_pendiente
      ? 'Solicitud enviada'
      : 'Solicitar mejora'
  }
  definirTexto(
    '[data-dashboard-fecha]',
    new Intl.DateTimeFormat('es-AR', { weekday: 'long', day: 'numeric', month: 'long' }).format(new Date()),
  )
}

async function refrescar() {
  datosPortal = await cargarPortal(paginaPortal, { paginaCorreos })
  renderPortal(datosPortal)
  if (paginaPortal === 'agenda') await cargarMesAgenda()
}

function tipoSugeridoRevision(correo) {
  const acciones = (correo.candidatos_revision?.acciones || []).join(' ').toLowerCase()
  if (/turno|cita/.test(acciones)) return 'turno'
  if (/reunion/.test(acciones)) return 'reunion'
  if (/renov/.test(acciones)) return 'renovacion'
  if (/entreg/.test(acciones)) return 'entrega'
  if (/document|presentar/.test(acciones)) return 'documentacion'
  if (/responder|completar/.test(acciones)) return 'respuesta'
  if (/pagar|abonar|factura|vence|vencimiento/.test(acciones)) return 'pago'
  return 'otro'
}

function renderCandidatosRevision(candidatos = {}) {
  const lista = document.querySelector('[data-revision-candidatos]')
  if (!lista) return
  lista.replaceChildren()
  const filas = [
    ['Fechas', (candidatos.fechas || []).map((item) => item.valor)],
    ['Horas', (candidatos.horas || []).map((item) => item.valor)],
    ['Importes', (candidatos.montos || []).map((item) => `${item.moneda || 'ARS'} ${item.valor}`)],
    ['Acciones', candidatos.acciones || []],
    ['Entidad', candidatos.entidad ? [candidatos.entidad] : []],
    ['Referencia', candidatos.referencia ? [candidatos.referencia] : []],
  ]
  filas.forEach(([etiqueta, valores]) => {
    const termino = document.createElement('dt')
    termino.textContent = etiqueta
    const detalle = document.createElement('dd')
    detalle.textContent = valores.length ? valores.join(' · ') : 'No detectado'
    lista.append(termino, detalle)
  })
}

function abrirRevisionCorreo(correo) {
  const candidatos = correo.candidatos_revision || {}
  formularioRevisionCorreo.reset()
  formularioRevisionCorreo.elements.p_correo_id.value = correo.id
  formularioRevisionCorreo.elements.p_tipo.value = tipoSugeridoRevision(correo)
  formularioRevisionCorreo.elements.p_titulo.value = correo.asunto || 'Compromiso pendiente'
  formularioRevisionCorreo.elements.p_fecha.min = fechaActualIso()
  formularioRevisionCorreo.elements.p_fecha.value = candidatos.fechas?.[0]?.valor || ''
  formularioRevisionCorreo.elements.p_hora.value = candidatos.horas?.[0]?.valor || ''
  formularioRevisionCorreo.elements.p_entidad.value = candidatos.entidad || ''
  formularioRevisionCorreo.elements.p_monto.value = candidatos.montos?.[0]?.valor ?? ''
  renderCandidatosRevision(candidatos)
  const motivo = document.querySelector('[data-revision-motivo]')
  motivo.textContent = correo.motivo_revision === 'exclusion_aprendida'
    ? 'Un descarte anterior evitó la autoagenda. Podés confirmar este caso manualmente.'
    : 'AgenKin no encontró una única interpretación segura. Comprobá los datos antes de guardar.'
  const gmail = document.querySelector('[data-revision-gmail]')
  const identificador = correo.gmail_thread_id || correo.gmail_message_id
  if (correo.google_email && /^[A-Za-z0-9_-]+$/.test(identificador || '')) {
    gmail.href = `https://mail.google.com/mail/u/?authuser=${encodeURIComponent(correo.google_email)}#all/${identificador}`
    gmail.hidden = false
  } else {
    gmail.removeAttribute('href')
    gmail.hidden = true
  }
  dialogoRevisionCorreo.showModal()
  formularioRevisionCorreo.elements.p_titulo.focus()
}

async function abrirDestinoNotificacion() {
  if (paginaPortal !== 'agenda') return
  const id = new URLSearchParams(window.location.search).get('notificacion')
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id || '')) return
  const { data: notificacion, error } = await supabase
    .from('notificaciones')
    .select('evento_id')
    .eq('id', id)
    .eq('estado', 'entregada')
    .maybeSingle()
  if (error || !notificacion?.evento_id) {
    mostrarAviso('La notificación ya no está disponible.', 'info')
    return
  }
  const { data: evento } = await supabase
    .from('eventos_calendar')
    .select('fecha_evento')
    .eq('id', notificacion.evento_id)
    .neq('estado_sincronizacion', 'eliminado')
    .maybeSingle()
  if (!evento?.fecha_evento) {
    mostrarAviso('El evento ya no está disponible.', 'info')
    return
  }
  const fecha = new Date(evento.fecha_evento)
  mesAgenda = new Date(fecha.getFullYear(), fecha.getMonth(), 1)
  await cargarMesAgenda(claveFecha(fecha))
  await supabase.rpc('marcar_notificacion_leida', { p_notificacion_id: id })
}

function obtenerIniciales(nombre, email) {
  const partes = (nombre || '').trim().split(/\s+/).filter(Boolean)
  if (partes.length) return partes.slice(0, 2).map((parte) => parte[0]).join('').toUpperCase()
  return (email || 'A').slice(0, 2).toUpperCase()
}

function obtenerUrlAvatar(contexto) {
  const metadatos = contexto.user?.user_metadata || {}
  const identidadGoogle = contexto.user?.identities?.find((identidad) => identidad.provider === 'google')
  const datosIdentidad = identidadGoogle?.identity_data || {}
  const candidatas = [
    metadatos.avatar_url,
    metadatos.picture,
    datosIdentidad.avatar_url,
    datosIdentidad.picture,
    contexto.perfil.avatar_url,
  ]

  for (const candidata of candidatas) {
    if (!candidata) continue
    try {
      const url = new URL(candidata)
      if (url.protocol === 'https:') return url.href
    } catch {
      // Se conserva la inicial si Google no entrega una URL válida.
    }
  }
  return null
}

function renderAvatar(contexto) {
  const imagen = document.querySelector('[data-avatar-imagen]')
  const iniciales = document.querySelector('[data-avatar-iniciales]')
  if (!imagen || !iniciales) return

  const nombre = contexto.perfil.nombre_completo || contexto.user?.user_metadata?.full_name || ''
  const email = contexto.perfil.email || contexto.user?.email || ''
  iniciales.textContent = obtenerIniciales(nombre, email)

  const avatarUrl = obtenerUrlAvatar(contexto)
  if (!avatarUrl) return

  const mostrarIniciales = () => {
    imagen.hidden = true
    iniciales.hidden = false
  }
  imagen.addEventListener('load', () => {
    imagen.hidden = false
    iniciales.hidden = true
  }, { once: true })
  imagen.addEventListener('error', mostrarIniciales, { once: true })
  imagen.alt = `Foto de ${nombre || 'tu perfil de Google'}`
  imagen.src = avatarUrl
}

async function iniciar() {
  try {
    const contexto = await protegerRuta('app')
    if (!contexto) return
    usuarioActualId = contexto.user.id
    definirTexto('[data-nombre]', contexto.perfil.nombre_completo?.split(' ')[0] || 'bienvenido')
    renderAvatar(contexto)
    await refrescar()
    await abrirDestinoNotificacion()
    await inicializarCentroNotificaciones()
    await inicializarPreferenciasNotificaciones()
    const parametros = new URLSearchParams(window.location.search)
    if (parametros.get('google') === 'conectado') {
      const servicio = parametros.get('servicio') === 'calendar' ? 'Google Calendar' : 'Gmail'
      mostrarAviso(`${servicio} quedó conectado.`, 'exito')
    } else if (parametros.get('motivo') === 'cupo_cuentas_gmail') {
      mostrarAviso('Tu plan ya tiene conectadas todas las cuentas Gmail disponibles.', 'error')
    } else if (parametros.get('motivo') === 'cuenta_calendar_distinta') {
      mostrarAviso('Calendar debe autorizarse con la misma cuenta Gmail que seleccionaste.', 'error')
    } else if (parametros.get('motivo') === 'cuenta_google_distinta') {
      mostrarAviso('La cuenta Google autorizada no coincide con la seleccionada.', 'error')
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

function cerrarMenuPortal() {
  document.body.classList.remove('menu-abierto')
  botonMenu?.setAttribute('aria-expanded', 'false')
  botonMenu?.setAttribute('aria-label', 'Abrir menú')
}

function esVistaMovil() {
  return window.matchMedia('(max-width: 760px)').matches
}

function actualizarMenuLateral() {
  if (!barraLateral || !botonMenuLateral) return
  const colapsado = barraLateral.classList.contains('barra-lateral--colapsada')
  botonMenuLateral.dataset.state = colapsado ? 'collapsed' : 'expanded'
  botonMenuLateral.setAttribute('aria-expanded', String(!colapsado))
  botonMenuLateral.setAttribute('aria-label', colapsado ? 'Expandir menú' : 'Contraer menú')
  botonMenuLateral.title = botonMenuLateral.getAttribute('aria-label')
  const icono = botonMenuLateral.querySelector('span')
  if (icono) icono.textContent = colapsado ? '>' : '<'
}

function restaurarMenuLateral() {
  if (!barraLateral || esVistaMovil()) {
    barraLateral?.classList.remove('barra-lateral--colapsada')
    actualizarMenuLateral()
    return
  }
  try {
    barraLateral.classList.toggle('barra-lateral--colapsada', localStorage.getItem(CLAVE_MENU_LATERAL) === 'true')
  } catch {
    barraLateral.classList.remove('barra-lateral--colapsada')
  }
  actualizarMenuLateral()
}

if (botonMenu && barraLateral) {
  barraLateral.id ||= 'menu-portal'
  botonMenu.setAttribute('aria-controls', barraLateral.id)
}

if (botonMenuLateral && barraLateral) {
  barraLateral.querySelectorAll('nav a, [data-logout]').forEach((control) => {
    control.title ||= control.textContent.trim()
  })
  restaurarMenuLateral()
  botonMenuLateral.addEventListener('click', () => {
    if (esVistaMovil()) return
    const colapsado = barraLateral.classList.toggle('barra-lateral--colapsada')
    try { localStorage.setItem(CLAVE_MENU_LATERAL, String(colapsado)) } catch {
      // El menú sigue funcionando aunque el navegador bloquee el almacenamiento local.
    }
    actualizarMenuLateral()
  })
  window.addEventListener('resize', restaurarMenuLateral)
}

botonMenu?.addEventListener('click', (evento) => {
  const abierto = document.body.classList.toggle('menu-abierto')
  evento.currentTarget.setAttribute('aria-expanded', String(abierto))
  evento.currentTarget.setAttribute('aria-label', abierto ? 'Cerrar menú' : 'Abrir menú')
})
barraLateral?.querySelectorAll('nav a').forEach((enlace) => {
  enlace.addEventListener('click', cerrarMenuPortal)
})
document.addEventListener('keydown', (evento) => {
  if (evento.key !== 'Escape' || !document.body.classList.contains('menu-abierto')) return
  cerrarMenuPortal()
  botonMenu?.focus()
})
document.addEventListener('click', (evento) => {
  if (
    document.body.classList.contains('menu-abierto')
    && !barraLateral?.contains(evento.target)
    && !botonMenu?.contains(evento.target)
  ) cerrarMenuPortal()
})
document.querySelector('[data-logout]')?.addEventListener('click', async (evento) => {
  setCargando(evento.currentTarget, true)
  await desactivarPushDispositivoActual().catch(() => null)
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
    const descubiertos = resultado.descubiertos || 0
    const encolados = resultado.encolados || 0
    const errores = resultado.errores || 0
    const noDisponibles = resultado.no_disponibles || 0
    const mensaje = `${descubiertos} mensajes nuevos encontrados y ${encolados} agregados a la cola. AgenKin actualizará la Agenda en segundo plano.`
    mostrarAviso(
      errores || noDisponibles
        ? `${mensaje} ${errores + noDisponibles} cuentas no estaban disponibles.`
        : mensaje,
      errores || noDisponibles ? 'advertencia' : 'exito',
    )
    await refrescar()
  } catch (error) {
    mostrarAviso(error.message, 'error')
  } finally { setCargando(boton, false) }
})
async function conectarServicio(servicio, boton, conexionId = null) {
  setCargando(boton, true, 'Preparando conexión…')
  try {
    const { url } = await invocarFuncion('google-oauth-start', {
      servicio,
      ...(conexionId ? { conexion_id: conexionId } : {}),
    })
    window.location.assign(url)
  } catch (error) {
    mostrarAviso(error.message, 'error')
    setCargando(boton, false)
  }
}

async function desconectarServicio(servicio, conexionId, boton) {
  const nombre = servicio === 'gmail' ? 'Gmail' : 'Google Calendar'
  if (!confirm(`¿Desactivar ${nombre} en AgenKin?`)) return

  setCargando(boton, true, 'Desactivando…')
  try {
    await invocarFuncion('google-disconnect', {
      servicio,
      conexion_id: conexionId,
    })
    mostrarAviso(`${nombre} fue desactivado.`, 'exito')
    await refrescar()
  } catch (error) {
    const usaCalendar = servicio === 'gmail' && error.message.includes('Calendar')
    if (usaCalendar && confirm('Esta cuenta también usa Calendar. ¿Desactivar ambos servicios sin revocar el permiso de Google?')) {
      try {
        await invocarFuncion('google-disconnect', {
          servicio: 'calendar',
          conexion_id: conexionId,
        })
        await invocarFuncion('google-disconnect', {
          servicio: 'gmail',
          conexion_id: conexionId,
        })
        mostrarAviso('Gmail y Calendar fueron desactivados.', 'exito')
        await refrescar()
      } catch (errorCombinado) {
        mostrarAviso(errorCombinado.message, 'error')
      }
    } else {
      mostrarAviso(error.message, 'error')
    }
  } finally {
    setCargando(boton, false)
  }
}

document.querySelector('[data-connect-gmail]')?.addEventListener('click', (evento) => {
  conectarServicio('gmail', evento.currentTarget)
})
document.querySelector('[data-gmail-cuentas]')?.addEventListener('click', async (evento) => {
  const reconectar = evento.target.closest('[data-reconnect-gmail]')
  if (reconectar) return conectarServicio('gmail', reconectar)
  const usarCalendar = evento.target.closest('[data-use-calendar]')
  if (usarCalendar) {
    return conectarServicio('calendar', usarCalendar, usarCalendar.dataset.useCalendar)
  }

  const desconectar = evento.target.closest('[data-disconnect-google]')
  if (desconectar) {
    const servicio = desconectar.dataset.disconnectGoogle
    const conexionId = desconectar.dataset.conexionId
    try {
      await desconectarServicio(servicio, conexionId, desconectar)
    } catch {
      // desconectarServicio muestra el estado al usuario.
    }
    return
  }

  const revocar = evento.target.closest('[data-revoke-google]')
  if (!revocar) return
  if (!confirm('Esto revocará el acceso de AgenKin a esta cuenta Google y desconectará Gmail y Calendar. ¿Continuar?')) return

  setCargando(revocar, true, 'Revocando…')
  try {
    await invocarFuncion('google-disconnect', {
      servicio: 'todo',
      conexion_id: revocar.dataset.revokeGoogle,
    })
    mostrarAviso('El acceso de esa cuenta Google fue revocado.', 'exito')
    await refrescar()
  } catch (error) {
    mostrarAviso(error.message, 'error')
  } finally {
    setCargando(revocar, false)
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
document.querySelector('[data-correos]')?.addEventListener('click', (evento) => {
  const boton = evento.target.closest('[data-revisar-correo]')
  if (!boton) return
  const correo = datosPortal.correos.find((item) => item.id === boton.dataset.revisarCorreo)
  if (correo) abrirRevisionCorreo(correo)
})
formularioRevisionCorreo?.addEventListener('submit', async (evento) => {
  if (evento.submitter?.value === 'cancel') return
  evento.preventDefault()
  const boton = evento.submitter
  setCargando(boton, true, 'Guardando…')
  try {
    const payload = Object.fromEntries(new FormData(formularioRevisionCorreo))
    payload.p_hora ||= null
    payload.p_entidad ||= null
    payload.p_monto = payload.p_monto === '' ? null : Number(payload.p_monto)
    const { error } = await supabase.rpc('confirmar_revision_correo', payload)
    if (error) throw error
    dialogoRevisionCorreo.close()
    mostrarAviso('Revisión confirmada y evento guardado en Agenda.', 'exito')
    await refrescar()
  } catch (error) {
    mostrarAviso(error.message || 'No se pudo confirmar la revisión.', 'error')
  } finally {
    setCargando(boton, false)
  }
})
document.querySelector('[data-descartar-revision]')?.addEventListener('click', async (evento) => {
  if (!confirm('¿Descartar esta revisión? Si el remitente está autenticado, AgenKin recordará de forma privada esta plantilla.')) return
  const boton = evento.currentTarget
  setCargando(boton, true, 'Descartando…')
  try {
    const { error } = await supabase.rpc('descartar_revision_correo', {
      p_correo_id: formularioRevisionCorreo.elements.p_correo_id.value,
    })
    if (error) throw error
    dialogoRevisionCorreo.close()
    mostrarAviso('Revisión descartada.', 'exito')
    await refrescar()
  } catch (error) {
    mostrarAviso(error.message || 'No se pudo descartar la revisión.', 'error')
  } finally {
    setCargando(boton, false)
  }
})
document.querySelector('[data-correos-anterior]')?.addEventListener('click', async () => {
  paginaCorreos = Math.max(1, paginaCorreos - 1)
  await refrescar()
})
document.querySelector('[data-correos-siguiente]')?.addEventListener('click', async () => {
  paginaCorreos += 1
  await refrescar()
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
    const seleccionado = elemento === dia
    elemento.dataset.seleccionado = String(seleccionado)
    elemento.setAttribute('aria-pressed', String(seleccionado))
  })
  renderDetalleAgenda(dia.dataset.agendaFecha)
})
document.querySelector('[data-nuevo-evento]')?.addEventListener('click', () => {
  formularioEventoManual.reset()
  const hoy = fechaActualIso()
  const seleccionada = document.querySelector('[data-agenda-fecha][data-seleccionado="true"]')
    ?.dataset.agendaFecha
  formularioEventoManual.elements.p_fecha.min = hoy
  formularioEventoManual.elements.p_fecha.value = seleccionada >= hoy ? seleccionada : hoy
  dialogoEventoManual.showModal()
  formularioEventoManual.elements.p_titulo.focus()
})
formularioEventoManual?.addEventListener('submit', async (evento) => {
  if (evento.submitter?.value === 'cancel') return
  evento.preventDefault()
  const boton = evento.submitter
  setCargando(boton, true, 'Creando…')
  try {
    const payload = Object.fromEntries(new FormData(formularioEventoManual))
    payload.p_hora ||= null
    payload.p_recordatorio_minutos = Number(payload.p_recordatorio_minutos)
    const { data, error } = await supabase.rpc('crear_evento_manual', payload)
    if (error) throw error
    dialogoEventoManual.close()
    const fecha = new Date(`${payload.p_fecha}T12:00:00`)
    mesAgenda = new Date(fecha.getFullYear(), fecha.getMonth(), 1)
    const detalleGoogle = data.google_estado === 'pendiente'
      ? ' y quedó pendiente de sincronización con Google Calendar'
      : ''
    mostrarAviso(`Evento guardado en Agenda${detalleGoogle}.`, 'exito')
    await cargarMesAgenda(payload.p_fecha)
  } catch (error) {
    mostrarAviso(error.message || 'No se pudo crear el evento.', 'error')
  } finally {
    setCargando(boton, false)
  }
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
      'AgenKin creará eventos futuros automáticamente para remitentes autenticados, cuando el análisis no requiera revisión, alcance la confianza elegida y no coincida con un descarte anterior. ¿Querés activarlo?',
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
    const mensaje = item?.estado === 'evento_creado'
      ? '¿Descartar este hallazgo y eliminar su evento de Agenda y Google Calendar? AgenKin recordará esta clase de correo para no volver a autoagendarla.'
      : '¿Descartar este vencimiento? AgenKin recordará esta clase de correo para no volver a autoagendarla.'
    if (!confirm(mensaje)) return
    const { data, error } = await supabase.rpc('descartar_vencimiento', {
      p_vencimiento_id: id,
    })
    if (error || data !== true) mostrarAviso('No se pudo descartar el vencimiento.', 'error')
    else {
      mostrarAviso('Vencimiento descartado. No volveremos a autoagendar correos similares.', 'exito')
      await refrescar()
    }
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
