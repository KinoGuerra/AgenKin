import { describe, expect, it } from 'vitest'
import { claveMensaje, rutaPermitida, validarAccionAdministrativa } from '../src/utils/validaciones.js'

const uuid = '2f0d9bb6-0cf2-4d80-b919-fd14a219d738'

describe('protección de rutas', () => {
  it('reserva administración para superadministradores activos', () => {
    expect(rutaPermitida({ rol: 'usuario', estado_acceso: 'activo' }, 'admin')).toBe(false)
    expect(rutaPermitida({ rol: 'superadministrador', estado_acceso: 'activo' }, 'admin')).toBe(true)
    expect(rutaPermitida({ rol: 'superadministrador', estado_acceso: 'bloqueado' }, 'admin')).toBe(false)
  })
})

describe('prevención de duplicados', () => {
  it('crea una clave estable por usuario y mensaje', () => {
    expect(claveMensaje(uuid, 'gmail-123')).toBe(`${uuid}:gmail-123`)
  })
})

describe('formularios administrativos', () => {
  it('valida acción, usuario, plan y fecha', () => {
    expect(validarAccionAdministrativa({ accion: 'bloquear', usuario_id: uuid })).toEqual({})
    expect(validarAccionAdministrativa({ accion: 'cambiar_plan', usuario_id: uuid }).plan_id).toBeTruthy()
    expect(validarAccionAdministrativa({ accion: 'otra', usuario_id: 'x' }).accion).toBeTruthy()
  })
})
