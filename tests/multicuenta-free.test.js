import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const leer = (ruta) => readFileSync(new URL(`../${ruta}`, import.meta.url), 'utf8')
const migracion = leer('supabase/migrations/20260730003317_sincronizacion_multicuenta_free.sql')
const worker = leer('supabase/functions/process-gmail-queue/index.ts')
const descubridor = leer('supabase/functions/sync-gmail-scheduled/index.ts')
const sincronizador = leer('supabase/functions/_shared/gmail-sync.ts')
const procesador = leer('supabase/functions/_shared/process-email.ts')
const manual = leer('supabase/functions/scan-gmail/index.ts')
const eventosProgramados = leer('supabase/functions/create-calendar-scheduled/index.ts')
const oauthCallback = leer('supabase/functions/google-oauth-callback/index.ts')

describe('sincronización multicuenta para Supabase Free', () => {
  it('limita cuentas y no mensajes', () => {
    expect(migracion).toContain('limite_cuentas_gmail')
    expect(migracion).toContain('CUPO_CUENTAS_GMAIL')
    expect(migracion).toContain('for update of s')
    expect(migracion).toContain('correos_conexion_mensaje_uidx')
    expect(worker).not.toContain('reservar_cupo_correo')
    expect(worker).not.toContain('/functions/v1/scan-gmail')
  })

  it('mantiene una sola cuenta Calendar activa', () => {
    expect(migracion).toContain('conexiones_google_calendar_principal_uidx')
    expect(migracion).toContain('where es_calendar_principal and calendar_conectado')
    expect(migracion).toContain('CUENTA_CALENDAR_DISTINTA')
  })

  it('usa workers globales acotados y reparto circular', () => {
    expect(descubridor).toContain('CUENTAS_POR_EJECUCION = 40')
    expect(descubridor).toContain('CONCURRENCIA = 4')
    expect(worker).toContain('TAREAS_POR_EJECUCION = 20')
    expect(worker).toContain('MINIMO_PARA_OTRO_GRUPO_MS = 65_000')
    expect(worker).toContain('iaTemporalmenteNoDisponible')
    expect(migracion).toContain('partition by t.conexion_google_id')
    expect(sincronizador).toContain('RESULTADOS_POR_PAGINA = 50')
    expect(migracion).toContain('COLA_GMAIL_SATURADA')
  })

  it('protege patrones, OAuth y la finalización atómica', () => {
    expect(procesador).toContain('ignorar || !autenticado')
    expect(procesador).toContain('if (!ignorar && !autenticado)')
    expect(procesador).toContain('requiere_revision: true')
    expect(procesador).toContain("'finalizar_correo_analizado'")
    const finalizacion = procesador.indexOf("'finalizar_correo_analizado'")
    expect(procesador.indexOf("'registrar_validacion_patron'")).toBeGreaterThan(finalizacion)
    expect(procesador.indexOf('const patronAprendidoId = await aprenderPatron'))
      .toBeGreaterThan(finalizacion)
    expect(procesador).toContain('const { error: errorMetadatos }')
    expect(procesador).toContain('fecha_correo: fechaIsoSegura(fecha)')
    expect(procesador).not.toContain("remitente: ''")
    expect(procesador).not.toContain("asunto: ''")
    expect(oauthCallback).toContain('perfilGoogle.email_verified !== true')
    expect(manual).toContain("'reclamar_sincronizaciones_manuales'")
    expect(manual).toContain('descubrirCambiosGmail')
  })

  it('simula 50.000 mensajes distribuidos sin límite comercial', () => {
    const cuentas = Array.from({ length: 125 }, (_, indice) => ({
      id: indice,
      pendientes: 400,
    }))
    let procesados = 0
    while (cuentas.some((cuenta) => cuenta.pendientes)) {
      for (const cuenta of cuentas) {
        if (!cuenta.pendientes) continue
        cuenta.pendientes -= 1
        procesados += 1
      }
    }
    expect(procesados).toBe(50_000)
    expect(cuentas.every((cuenta) => cuenta.pendientes === 0)).toBe(true)
  })

  it('proyecta los cron fijos por debajo de 200.000 invocaciones al mes', () => {
    const dias = 30
    const descubridorCadaCinco = dias * 24 * 12
    const workerGmailCadaMinuto = dias * 24 * 60
    const workerCalendarCadaMinuto = dias * 24 * 60
    const eventosCadaDosMinutos = dias * 24 * 30
    const total = descubridorCadaCinco
      + workerGmailCadaMinuto
      + workerCalendarCadaMinuto
      + eventosCadaDosMinutos
    expect(total).toBe(116_640)
    expect(total).toBeLessThan(200_000)
    expect(eventosProgramados).not.toContain('/functions/v1/')
    expect(eventosProgramados).toContain("'crear_eventos_automaticos_pendientes'")
    expect(eventosProgramados).not.toContain("'obtener_eventos_automaticos_pendientes'")
  })

  it('compacta datos y conserva métricas antes de borrar tombstones', () => {
    expect(migracion).toContain("v.fecha_vencimiento < current_date - 15")
    expect(migracion).toContain("cp.fecha_procesamiento < now() - interval '30 days'")
    expect(migracion).toContain("cp.fecha_procesamiento < now() - interval '120 days'")
    expect(migracion).toContain("t.actualizado_en < now() - interval '48 hours'")
    expect(migracion).toContain('limit 1000')
    expect(migracion).toContain('alerta_almacenamiento')
    expect(migracion).toContain('detener_carga_historica')
  })

  it('mantiene tablas internas fuera de roles de usuario', () => {
    expect(migracion).toContain('alter table public.patrones_correo enable row level security')
    expect(migracion).toContain('revoke all on public.patrones_correo from public, anon, authenticated')
    expect(migracion).toContain('grant all on public.patrones_correo to service_role')
  })
})
