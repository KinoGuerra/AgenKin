import { describe, expect, it } from 'vitest'
import { confianzaValida, normalizarClasificacion } from '../src/utils/clasificacion.js'

describe('confianzaValida', () => {
  it('acepta solamente valores entre cero y uno', () => {
    expect(confianzaValida(0.95)).toBe(true)
    expect(confianzaValida(1.1)).toBe(false)
    expect(confianzaValida('0.9')).toBe(false)
  })
})

describe('normalizarClasificacion', () => {
  it('normaliza y fuerza revisión con confianza baja', () => {
    const resultado = normalizarClasificacion({
      relevante: true,
      categoria: 'factura',
      grupo_resumen: 'servicios',
      tipo: 'pago',
      titulo: ' Vencimiento ',
      descripcion: 'Detalle',
      fecha: '05/08/2026',
      confianza: 0.7,
      explicacion: 'Fecha explícita',
    })
    expect(resultado.fecha).toBe('2026-08-05')
    expect(resultado.titulo).toBe('Vencimiento')
    expect(resultado.grupo_resumen).toBe('servicios')
    expect(resultado.requiere_revision).toBe(true)
  })

  it('rechaza respuestas relevantes sin fecha', () => {
    expect(() => normalizarClasificacion({ relevante: true, confianza: 0.9 })).toThrow()
  })

  it('usa Otros cuando el grupo recibido no es válido', () => {
    const resultado = normalizarClasificacion({
      relevante: true,
      grupo_resumen: 'desconocido',
      fecha: '2026-08-05',
      confianza: 0.9,
    })
    expect(resultado.grupo_resumen).toBe('otros')
  })
})
