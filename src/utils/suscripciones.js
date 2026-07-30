export const ESTADOS_HABILITADOS = new Set(['prueba', 'activa'])

export function evaluarSuscripcion(suscripcion, ahora = new Date()) {
  if (!suscripcion) return { habilitada: false, motivo: 'sin_suscripcion' }
  if (!ESTADOS_HABILITADOS.has(suscripcion.estado)) {
    return { habilitada: false, motivo: suscripcion.estado }
  }
  if (suscripcion.fecha_vencimiento && new Date(suscripcion.fecha_vencimiento) < ahora) {
    return { habilitada: false, motivo: 'vencida' }
  }
  return { habilitada: true, motivo: null }
}
