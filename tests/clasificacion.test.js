import { describe, expect, it } from 'vitest'
import {
  formatearAvisoDia,
  formatearMontoARS,
} from '../src/utils/clasificacion.js'

describe('formatearAvisoDia', () => {
  it('combina grupo, entidad y monto en formato argentino', () => {
    expect(formatearAvisoDia({ grupo_resumen: 'tarjetas', entidad: 'Visa', monto: 120000 }))
      .toBe('Tarjeta - Visa - $ 120.000')
    expect(formatearAvisoDia({ grupo_resumen: 'servicios', entidad: 'Epec', monto: 101000 }))
      .toBe('Servicio - Epec - $ 101.000')
  })

  it('formatea importes para mostrar la interpretación del correo', () => {
    expect(formatearMontoARS(100000)).toContain('100.000')
    expect(formatearMontoARS(null, null)).toBeNull()
  })

  it('explicita los datos que no pudieron detectarse', () => {
    expect(formatearAvisoDia({ grupo_resumen: 'tarjetas', entidad: null, monto: null }))
      .toBe('Tarjeta - Desconocido - Monto no informado')
  })
})
