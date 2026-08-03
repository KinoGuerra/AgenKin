import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const proceso = readFileSync(
  new URL('../supabase/functions/_shared/process-email.ts', import.meta.url),
  'utf8',
)
const worker = readFileSync(
  new URL('../supabase/functions/process-gmail-queue/index.ts', import.meta.url),
  'utf8',
)
const recuperacion = readFileSync(
  new URL(
    '../supabase/migrations/20260730033151_reprocesar_correos_sin_metadatos.sql',
    import.meta.url,
  ),
  'utf8',
).replace(/\s+/g, ' ').trim().toLowerCase()

function bloque(inicio, fin) {
  const desde = proceso.indexOf(inicio)
  const hasta = proceso.indexOf(fin, desde)
  if (desde < 0 || hasta <= desde) throw new Error(`No se encontró el bloque ${inicio}`)
  return proceso.slice(desde, hasta)
}

describe('resiliencia del análisis de correos', () => {
  it('persiste metadatos de Gmail antes de invocar la IA', () => {
    const metadatos = proceso.indexOf('const { error: errorMetadatos }')
    const clasificacion = proceso.indexOf('await clasificarCorreo(')

    expect(metadatos).toBeGreaterThan(0)
    expect(metadatos).toBeLessThan(clasificacion)
    expect(proceso.slice(metadatos, clasificacion)).toContain('gmail_thread_id: threadId')
    expect(proceso.slice(metadatos, clasificacion)).toContain('fecha_correo: fechaIsoSegura(fecha)')
  })

  it('no borra remitente, asunto ni fecha al reclamar o diferir un correo', () => {
    const reclamo = bloque(
      "const { data, error } = await cliente\n    .from('correos_procesados')\n    .update({",
      'function coincideRegla(',
    )
    const captura = bloque('  } catch (error) {', "    if (codigo !== 'AI_REINTENTOS_AGOTADOS'")

    for (const fragmento of ["remitente: ''", "asunto: ''", 'fecha_correo: null']) {
      expect(reclamo).not.toContain(fragmento)
      expect(captura).not.toContain(fragmento)
    }
  })

  it('reencola sólo fallos definitivos que continúan sin metadatos', () => {
    expect(recuperacion).toContain("tarea.estado = 'error'")
    expect(recuperacion).toContain(
      "tarea.ultimo_error in ('ai_respuesta_invalida', 'procesamiento_en_curso')",
    )
    expect(recuperacion).toContain("correo.estado_procesamiento = 'error'")
    expect(recuperacion).toContain('correo.fecha_correo is null')
    expect(recuperacion).toContain("btrim(coalesce(correo.remitente, '')) = ''")
    expect(recuperacion).not.toContain("tarea.ultimo_error = 'ai_limite_temporal'")
  })

  it('reserva presupuesto antes de IA y limita los errores temporales a dos días', () => {
    const reserva = proceso.indexOf("'reservar_presupuesto_ia'")
    const llamada = proceso.indexOf('await clasificarCorreo(')
    expect(reserva).toBeGreaterThan(0)
    expect(reserva).toBeLessThan(llamada)
    expect(proceso).toContain("'confirmar_consumo_ia'")
    expect(proceso).toContain("'bloquear_proveedor_ia'")
    expect(worker).toContain('tarea.intentos_ia + 1 < 2')
    expect(worker).toContain("resultado.codigoError === 'AI_PRESUPUESTO_DIARIO'")
  })
})
