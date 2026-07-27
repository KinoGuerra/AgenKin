import { describe, expect, it } from 'vitest'
import { evaluarSuscripcion, puedeProcesar } from '../src/utils/suscripciones.js'

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

describe('puedeProcesar', () => {
  it('impide superar el límite mensual', () => {
    expect(puedeProcesar(50, 49, 1)).toBe(true)
    expect(puedeProcesar(50, 49, 2)).toBe(false)
  })
})
