import { describe, expect, it } from 'vitest'
import { evaluarSuscripcion } from '../src/utils/suscripciones.js'

describe('evaluarSuscripcion', () => {
  const ahora = new Date('2026-07-27T12:00:00Z')

  it('habilita pruebas vigentes', () => {
    expect(evaluarSuscripcion({ estado: 'prueba', fecha_vencimiento: '2026-08-01T00:00:00Z' }, ahora).habilitada).toBe(true)
  })

  it('bloquea estados y fechas vencidas', () => {
    expect(evaluarSuscripcion({ estado: 'suspendida', fecha_vencimiento: '2026-08-01T00:00:00Z' }, ahora).habilitada).toBe(false)
    expect(evaluarSuscripcion({ estado: 'activa', fecha_vencimiento: '2026-07-26T00:00:00Z' }, ahora).motivo).toBe('vencida')
  })
})
