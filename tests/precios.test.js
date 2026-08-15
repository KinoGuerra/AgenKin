import { describe, expect, it } from 'vitest'
import { convertirUsdAArs } from '../src/utils/precios.js'

describe('conversión comercial de USD a ARS', () => {
  it('redondea siempre hacia arriba al siguiente múltiplo de 500', () => {
    expect(convertirUsdAArs(5, 1545)).toBe(8000)
    expect(convertirUsdAArs(7, 1545)).toBe(11000)
    expect(convertirUsdAArs(10, 1545)).toBe(15500)
    expect(convertirUsdAArs(1, 1500)).toBe(1500)
  })
})
