import { describe, expect, it } from 'vitest'
import {
  calcularFinPrueba,
  esFechaActualOFutura,
  fechaActualIso,
  formatearFecha,
  formatearFechaHora,
  normalizarFecha,
} from '../src/utils/fechas.js'

describe('normalizarFecha', () => {
  it('normaliza fechas locales e ISO', () => {
    expect(normalizarFecha('5/8/2026')).toBe('2026-08-05')
    expect(normalizarFecha('2026-08-05')).toBe('2026-08-05')
  })

  it('rechaza fechas inexistentes', () => {
    expect(normalizarFecha('31/02/2026')).toBeNull()
    expect(normalizarFecha('mañana')).toBeNull()
  })
})

describe('calcularFinPrueba', () => {
  it('calcula exactamente 15 días desde el alta', () => {
    expect(calcularFinPrueba('2026-07-27T12:00:00Z')).toBe('2026-08-11T12:00:00.000Z')
  })
})

describe('formatearFechaHora', () => {
  it('usa el formato argentino requerido sin depender del huso del navegador', () => {
    expect(formatearFechaHora('2026-07-28T17:05:00Z')).toBe('28/07/2026 14:05')
    expect(formatearFechaHora(null)).toBe('Sin actualizaciones')
  })
})

describe('formatearFecha', () => {
  it('no retrocede un día al mostrar una fecha sin hora en Argentina', () => {
    expect(formatearFecha('2026-08-10', 'en-CA')).toBe('Aug 10, 2026')
  })
})

describe('fechaActualIso', () => {
  it('calcula el día de Argentina aunque UTC ya esté en el día siguiente', () => {
    expect(fechaActualIso(
      'America/Argentina/Cordoba',
      new Date('2026-07-31T01:30:00Z'),
    )).toBe('2026-07-30')
  })
})

describe('esFechaActualOFutura', () => {
  it('excluye fechas vencidas y conserva hoy o fechas posteriores', () => {
    const ahora = new Date('2026-08-03T15:00:00Z')
    expect(esFechaActualOFutura('2026-06-14', undefined, ahora)).toBe(false)
    expect(esFechaActualOFutura('2026-08-03', undefined, ahora)).toBe(true)
    expect(esFechaActualOFutura('2026-08-10', undefined, ahora)).toBe(true)
  })
})
