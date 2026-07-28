import { normalizarFecha } from './fechas.js'

const CATEGORIAS = new Set([
  'factura',
  'pago',
  'entrega',
  'renovacion',
  'turno',
  'reunion',
  'respuesta',
  'documentacion',
  'promocion',
  'irrelevante',
  'otro',
])
const GRUPOS = new Set(['tarjetas', 'servicios', 'suscripciones', 'turnos', 'otros'])
const GRUPOS_AVISOS = {
  tarjetas: 'Tarjeta',
  servicios: 'Servicio',
  suscripciones: 'Suscripción',
  turnos: 'Turno',
  otros: 'Otro',
}

export function confianzaValida(valor) {
  return typeof valor === 'number' && Number.isFinite(valor) && valor >= 0 && valor <= 1
}

export function formatearAvisoDia(aviso = {}) {
  const grupo = GRUPOS_AVISOS[aviso.grupo_resumen] || GRUPOS_AVISOS.otros
  const entidad = String(aviso.entidad || '').trim() || 'Desconocido'
  const monto = Number(aviso.monto)
  const importe = aviso.monto === null
    || aviso.monto === undefined
    || aviso.monto === ''
    || !Number.isFinite(monto)
    ? 'Monto no informado'
    : new Intl.NumberFormat('es-AR', {
        style: 'currency',
        currency: 'ARS',
        minimumFractionDigits: Number.isInteger(monto) ? 0 : 2,
        maximumFractionDigits: 2,
      }).format(monto).replace(/\s/g, ' ')
  return `${grupo} - ${entidad} - ${importe}`
}

export function normalizarClasificacion(respuesta) {
  if (!respuesta || typeof respuesta !== 'object') throw new Error('Respuesta de IA inválida')
  const fecha = normalizarFecha(respuesta.fecha)
  const confianza = Number(respuesta.confianza)
  const relevante = respuesta.relevante === true

  if (relevante && !fecha) throw new Error('La respuesta relevante no contiene una fecha válida')
  if (!confianzaValida(confianza)) throw new Error('La confianza debe estar entre 0 y 1')

  return {
    relevante,
    categoria: CATEGORIAS.has(respuesta.categoria) ? respuesta.categoria : 'otro',
    grupo_resumen: GRUPOS.has(respuesta.grupo_resumen) ? respuesta.grupo_resumen : 'otros',
    tipo: String(respuesta.tipo || 'otro').slice(0, 50),
    titulo: String(respuesta.titulo || '').trim().slice(0, 160),
    descripcion: String(respuesta.descripcion || '').trim().slice(0, 1000),
    entidad: respuesta.entidad ? String(respuesta.entidad).trim().slice(0, 120) : null,
    monto: typeof respuesta.monto === 'number' && Number.isFinite(respuesta.monto) && respuesta.monto >= 0
      ? respuesta.monto
      : null,
    fecha,
    hora: /^\d{2}:\d{2}$/.test(respuesta.hora || '') ? respuesta.hora : null,
    zona_horaria: String(respuesta.zona_horaria || 'America/Argentina/Cordoba'),
    confianza,
    requiere_revision: respuesta.requiere_revision === true || confianza < 0.75,
    explicacion: String(respuesta.explicacion || '').trim().slice(0, 500),
  }
}
