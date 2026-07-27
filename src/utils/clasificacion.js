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

export function confianzaValida(valor) {
  return typeof valor === 'number' && Number.isFinite(valor) && valor >= 0 && valor <= 1
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
    tipo: String(respuesta.tipo || 'otro').slice(0, 50),
    titulo: String(respuesta.titulo || '').trim().slice(0, 160),
    descripcion: String(respuesta.descripcion || '').trim().slice(0, 1000),
    fecha,
    hora: /^\d{2}:\d{2}$/.test(respuesta.hora || '') ? respuesta.hora : null,
    zona_horaria: String(respuesta.zona_horaria || 'America/Argentina/Cordoba'),
    confianza,
    requiere_revision: respuesta.requiere_revision === true || confianza < 0.75,
    explicacion: String(respuesta.explicacion || '').trim().slice(0, 500),
  }
}
