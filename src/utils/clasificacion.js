const GRUPOS_AVISOS = {
  tarjetas: 'Tarjeta',
  servicios: 'Servicio',
  suscripciones: 'Suscripción',
  turnos: 'Turno',
  otros: 'Otro',
}

export function formatearMontoARS(valor, textoVacio = 'Monto no informado') {
  const monto = Number(valor)
  if (valor === null || valor === undefined || valor === '' || !Number.isFinite(monto)) return textoVacio
  return new Intl.NumberFormat('es-AR', {
    style: 'currency',
    currency: 'ARS',
    minimumFractionDigits: Number.isInteger(monto) ? 0 : 2,
    maximumFractionDigits: 2,
  }).format(monto).replace(/\s/g, ' ')
}

export function formatearAvisoDia(aviso = {}) {
  const grupo = GRUPOS_AVISOS[aviso.grupo_resumen] || GRUPOS_AVISOS.otros
  const entidad = String(aviso.entidad || '').trim() || 'Desconocido'
  const importe = formatearMontoARS(aviso.monto)
  return `${grupo} - ${entidad} - ${importe}`
}
