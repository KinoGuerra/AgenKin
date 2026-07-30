import { describe, expect, it } from 'vitest'
import { Buffer } from 'node:buffer'
import {
  extraerTextoCorreo,
  htmlATexto,
  MAXIMO_TEXTO_CORREO,
} from '../supabase/functions/_shared/gmail.ts'
import {
  analizarLocalmente,
  aplicarPatron,
  clasificacionesCoinciden,
  extraerFechas,
  extraerMontos,
  remitenteAutenticado,
} from '../supabase/functions/_shared/patterns.ts'

function base64Url(texto) {
  return Buffer.from(texto, 'utf8').toString('base64url')
}

describe('extracción local y patrones de Gmail', () => {
  it('usa text/plain antes que HTML', () => {
    const texto = extraerTextoCorreo({
      mimeType: 'multipart/alternative',
      parts: [
        { mimeType: 'text/html', body: { data: base64Url('<p>HTML</p>') } },
        { mimeType: 'text/plain', body: { data: base64Url('Texto plano') } },
      ],
    })
    expect(texto).toBe('Texto plano')
  })

  it('convierte correos solo HTML en texto legible', () => {
    expect(htmlATexto(
      '<style>.x{display:none}</style><p>Vence&nbsp;mañana</p><div>$100.000</div>',
    )).toBe('Vence mañana\n$100.000')
  })

  it('limita el texto antes de procesar un MIME grande', () => {
    const texto = 'x'.repeat(MAXIMO_TEXTO_CORREO + 20_000)
    const extraido = extraerTextoCorreo({
      mimeType: 'text/plain',
      body: { data: base64Url(texto) },
    })
    expect(extraido).toHaveLength(MAXIMO_TEXTO_CORREO)
  })

  it('extrae la fecha y el monto del ejemplo de servicio sin IA', async () => {
    const texto = 'Tenes hasta el dia 30/07/2026 para pagarme los $100000 del servicio.'
    expect(extraerFechas(texto)[0].valor).toBe('2026-07-30')
    expect(extraerMontos(texto)[0].valor).toBe(100000)

    const analisis = await analizarLocalmente(texto, 'EPEC <facturas@epec.com.ar>')
    expect(analisis.acciones).toContain('pagar')
    expect(analisis.textoRelevante.length).toBeLessThanOrEqual(3000)
    expect(analisis.huellaPlantilla).toMatch(/^[a-f0-9]{64}$/)
  })

  it('aplica únicamente selectores declarativos verificados', async () => {
    const analisis = await analizarLocalmente(
      'El servicio vence el 30/07/2026. Total $100000.',
      'EPEC <facturas@epec.com.ar>',
    )
    const resultado = aplicarPatron({
      id: 'patron',
      alcance: 'personal',
      selector_fecha: 0,
      selector_monto: 0,
      clasificacion: {
        categoria: 'factura',
        grupo_resumen: 'servicios',
        tipo: 'pago',
        entidad: 'EPEC',
      },
    }, analisis)
    expect(resultado).toMatchObject({
      fecha: '2026-07-30',
      monto: 100000,
      grupo_resumen: 'servicios',
      requiere_revision: false,
    })
  })

  it('solo aprende de remitentes autenticados', () => {
    expect(remitenteAutenticado('mx; dkim=pass; spf=pass; dmarc=pass')).toBe(true)
    expect(remitenteAutenticado('mx; dkim=fail; spf=fail; dmarc=pass')).toBe(false)
  })

  it('considera discrepancia cuando sólo una clasificación tiene monto', () => {
    const base = {
      relevante: true,
      categoria: 'factura',
      grupo_resumen: 'servicios',
      tipo: 'pago',
      titulo: 'Servicio',
      descripcion: '',
      entidad: 'EPEC',
      fecha: '2026-07-30',
      hora: null,
      zona_horaria: 'America/Argentina/Cordoba',
      confianza: 0.96,
      requiere_revision: false,
      explicacion: '',
    }
    expect(clasificacionesCoinciden(
      { ...base, monto: null },
      { ...base, monto: 100000 },
    )).toBe(false)
    expect(clasificacionesCoinciden(
      { ...base, monto: 100000 },
      { ...base, monto: null },
    )).toBe(false)
  })
})
