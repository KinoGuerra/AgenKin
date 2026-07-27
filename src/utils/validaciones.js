const ACCIONES_ADMIN = new Set([
  'activar',
  'suspender',
  'bloquear',
  'desbloquear',
  'cambiar_plan',
  'extender_prueba',
  'cambiar_vencimiento',
  'cancelar_suscripcion',
  'registrar_observacion',
])

export function claveMensaje(usuarioId, gmailMessageId) {
  if (!usuarioId || !gmailMessageId) throw new Error('Identificadores requeridos')
  return `${usuarioId}:${gmailMessageId}`
}

export function validarAccionAdministrativa(datos) {
  const errores = {}
  if (!ACCIONES_ADMIN.has(datos?.accion)) errores.accion = 'Acción no permitida'
  if (!/^[0-9a-f-]{36}$/i.test(datos?.usuario_id || '')) errores.usuario_id = 'Usuario inválido'
  if (datos?.accion === 'cambiar_plan' && !/^[0-9a-f-]{36}$/i.test(datos?.plan_id || '')) {
    errores.plan_id = 'Plan inválido'
  }
  if (
    ['cambiar_vencimiento', 'extender_prueba'].includes(datos?.accion) &&
    Number.isNaN(new Date(datos?.fecha_vencimiento).getTime())
  ) {
    errores.fecha_vencimiento = 'Fecha inválida'
  }
  if (datos?.observacion && String(datos.observacion).length > 1000) {
    errores.observacion = 'La observación supera los 1000 caracteres'
  }
  return errores
}

export function rutaPermitida(perfil, pagina) {
  if (!perfil) return false
  if (['bloqueado', 'suspendido', 'cancelado'].includes(perfil.estado_acceso)) return false
  if (pagina === 'admin' || pagina === 'access') return perfil.rol === 'superadministrador'
  return pagina === 'app'
}
