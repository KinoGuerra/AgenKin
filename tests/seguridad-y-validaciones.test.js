import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import {
  requiereMfaAdministrativa,
  rutaPermitida,
  validarAccionAdministrativa,
} from '../src/utils/validaciones.js'

const uuid = '2f0d9bb6-0cf2-4d80-b919-fd14a219d738'

describe('protección de rutas', () => {
  it('reserva administración para superadministradores activos', () => {
    expect(rutaPermitida({ rol: 'usuario', estado_acceso: 'activo' }, 'admin')).toBe(false)
    expect(rutaPermitida({ rol: 'superadministrador', estado_acceso: 'activo' }, 'admin')).toBe(true)
    expect(rutaPermitida({ rol: 'superadministrador', estado_acceso: 'bloqueado' }, 'admin')).toBe(false)
  })

  it('exige AAL2 para el panel administrativo', () => {
    expect(requiereMfaAdministrativa('admin', 'aal1')).toBe(true)
    expect(requiereMfaAdministrativa('admin', 'aal2')).toBe(false)
    expect(requiereMfaAdministrativa('app', 'aal1')).toBe(false)
  })
})

describe('formularios administrativos', () => {
  it('valida acción, usuario, plan y fecha', () => {
    expect(validarAccionAdministrativa({ accion: 'bloquear', usuario_id: uuid })).toEqual({})
    expect(validarAccionAdministrativa({ accion: 'cambiar_plan', usuario_id: uuid }).plan_id).toBeTruthy()
    expect(validarAccionAdministrativa({ accion: 'otra', usuario_id: 'x' }).accion).toBeTruthy()
  })
})

describe('autorización en base de datos', () => {
  const migracion = readFileSync(
    new URL('../supabase/migrations/20260729030945_endurecer_seguridad_integral.sql', import.meta.url),
    'utf8',
  )

  it('aplica estado de cuenta y propiedad en las políticas RLS', () => {
    expect(migracion).toContain('private.usuario_con_acceso()')
    expect(migracion).toContain('usuario_id = (select auth.uid())')
  })

  it('valida plan y remitente priorizado para automatizar', () => {
    expect(migracion).toContain('pl.permite_automatizacion')
    expect(migracion).toContain("r.accion = 'priorizar'")
    expect(migracion).toContain('private.configurar_automatizacion_google')
    expect(migracion).toContain('security invoker')
  })
})
