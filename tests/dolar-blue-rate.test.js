import { describe, expect, it } from 'vitest'
import { extraerVentaDolarBlue } from '../supabase/functions/public-exchange-rate/dolar-blue.ts'

describe('cotización Dólar Blue Venta', () => {
  it('elige Venta y no confunde Compra ni otros valores', () => {
    const html = '<div class="data__valores"><p>1525,00<span>Compra</span></p><p>1545,00<span>Venta</span></p><p>134000,00<span>Valor</span></p></div>'
    expect(extraerVentaDolarBlue(html)).toBe(1545)
  })

  it('admite separador de miles y decimales argentinos', () => {
    expect(extraerVentaDolarBlue('<p>1.545,50 <span>Venta</span></p>')).toBe(1545.5)
  })

  it('rechaza una respuesta sin una venta plausible', () => {
    expect(() => extraerVentaDolarBlue('<p>1545,00<span>Compra</span></p>')).toThrow()
    expect(() => extraerVentaDolarBlue('<p>10,00<span>Venta</span></p>')).toThrow()
  })
})
