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
  asuntoEsPublicidad,
  clasificacionesCoinciden,
  debeValidarEnSombra,
  evaluarPreviamente,
  extraerFechas,
  extraerHoras,
  extraerMontos,
  huellaFuncional,
  momentoVigente,
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
    expect(analisis.textoRelevante.length).toBeLessThanOrEqual(1200)
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

  it('resuelve fechas relativas y sin año usando la fecha real del correo', () => {
    const referencia = '2026-12-31T23:30:00-03:00'
    const valores = extraerFechas(
      'Hoy 31/12. Mañana 01/01. Pasado mañana 2 de enero. Dentro de 5 días. Próximo jueves.',
      referencia,
    ).map((fecha) => fecha.valor)
    expect(valores).toContain('2026-12-31')
    expect(valores).toContain('2027-01-01')
    expect(valores).toContain('2027-01-02')
    expect(valores).toContain('2027-01-05')
    expect(valores).toContain('2027-01-07')
  })

  it('resuelve próximo lunes y este viernes de forma futura y determinística', () => {
    expect(extraerFechas('Próximo lunes', '2026-08-03T10:00:00-03:00')[0].valor)
      .toBe('2026-08-10')
    expect(extraerFechas('Este viernes', '2026-08-08T10:00:00-03:00')[0].valor)
      .toBe('2026-08-14')
  })

  it('conserva el 29 de febrero y extrae hora', () => {
    expect(extraerFechas('Turno el 29/02', '2028-01-10T10:00:00-03:00')[0].valor)
      .toBe('2028-02-29')
    expect(extraerHoras('Turno a las 15:30 hs')[0].valor).toBe('15:30')
  })

  it('clasifica localmente sólo un compromiso claro de remitente autenticado', async () => {
    const analisis = await analizarLocalmente(
      'Tu factura vence el 10/08/2026. Total $25.780,50.',
      'EPEC <facturas@epec.com.ar>',
      '2026-08-03T10:00:00-03:00',
    )
    const evaluacion = evaluarPreviamente(analisis, 'Tu factura', true, false, new Date('2026-08-03T13:00:00Z'))
    expect(evaluacion).toMatchObject({ requiereIa: false, motivo: 'compromiso_local_seguro' })
    expect(evaluacion.clasificacionLocal).toMatchObject({ tipo: 'pago', fecha: '2026-08-10', monto: 25780.5 })
    expect(evaluarPreviamente(analisis, 'Tu factura', false).requiereIa).toBe(true)
  })

  it('sólo descarta promociones inequívocas con List-Unsubscribe', async () => {
    const promocion = await analizarLocalmente('Conocé nuestros productos.', 'Novedades <news@example.test>')
    expect(evaluarPreviamente(promocion, 'Ofertas exclusivas de esta semana', true, true))
      .toMatchObject({ requiereIa: false, motivo: 'promocion_inequivoca' })
    expect(evaluarPreviamente(promocion, 'Recordatorio de tu cita', true, true).requiereIa).toBe(true)
  })

  it('prioriza la marca explícita (Publicidad) aunque haya fechas y acciones', async () => {
    const promocion = await analizarLocalmente(
      'Reservá tu turno antes del 10/08/2026 y obtené un descuento.',
      'Novedades <news@example.test>',
    )
    expect(asuntoEsPublicidad('(Publicidad) Turnos disponibles')).toBe(true)
    expect(asuntoEsPublicidad('( publicidad ) Pagá en cuotas')).toBe(true)
    expect(asuntoEsPublicidad('Información sobre publicidad')).toBe(false)
    expect(evaluarPreviamente(
      promocion,
      '(PUBLICIDAD) Turnos disponibles',
      true,
      false,
    )).toMatchObject({
      requiereIa: false,
      motivo: 'publicidad_declarada',
      clasificacionLocal: {
        relevante: false,
        categoria: 'promocion',
        grupo_resumen: 'otros',
        fecha: null,
      },
    })
  })

  it('distingue una hora ya pasada en el día de hoy', () => {
    expect(momentoVigente('2026-08-03', '10:00', new Date('2026-08-03T21:00:00Z'))).toBe(false)
    expect(momentoVigente('2026-08-03', null, new Date('2026-08-03T21:00:00Z'))).toBe(true)
  })

  it('resuelve localmente un histórico claro sin gastar IA', async () => {
    const analisis = await analizarLocalmente(
      'La factura venció el 01/07/2026. Total $100.',
      'Epec <avisos@epec.com.ar>',
      '2026-07-01T10:00:00-03:00',
    )
    expect(evaluarPreviamente(analisis, 'Factura vencida', true, false, new Date('2026-08-03T12:00:00Z')))
      .toMatchObject({ requiereIa: false, motivo: 'compromiso_historico_claro' })
  })

  it('usa validación de sombra adaptativa y huellas que no fusionan referencias distintas', async () => {
    expect(await debeValidarEnSombra('mensaje-fijo', {
      coincidencias: 20,
      discrepancias: 1,
      ultima_discrepancia_en: new Date().toISOString(),
    })).toBe(true)
    const analisis = await analizarLocalmente('Factura A-100 vence 10/08/2026.', 'Epec <x@epec.com.ar>')
    const base = aplicarPatron({
      id: 'p', alcance: 'personal', selector_fecha: 0, selector_monto: null,
      clasificacion: { categoria: 'factura', grupo_resumen: 'servicios', tipo: 'pago', entidad: 'Epec' },
    }, analisis)
    const analisisB = await analizarLocalmente('Factura B-200 vence 10/08/2026.', 'Epec <x@epec.com.ar>')
    const a = await huellaFuncional(base, analisis, 'Factura mensual')
    const b = await huellaFuncional(base, analisisB, 'Factura mensual')
    expect(a).not.toBe(b)
    expect(await huellaFuncional(base, analisis, 'Factura mensual')).toBe(a)
  })
})
