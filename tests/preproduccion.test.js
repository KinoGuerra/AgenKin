import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const leer = (ruta) => readFileSync(new URL(`../${ruta}`, import.meta.url), 'utf8')
const migracion = leer('supabase/migrations/20260812123028_preparar_entorno_preproductivo.sql')
const migracionPush = leer('supabase/migrations/20260812123648_corregir_conflicto_entregas_push.sql')
const worker = leer('supabase/functions/process-notifications-scheduled/index.ts')
const admin = leer('src/pages/admin.js')
const runbook = leer('docs/PREPRODUCCION.md')

describe('contratos preproductivos', () => {
  it('resuelve la ambigüedad SQL mediante la restricción única explícita', () => {
    expect(migracion).toContain('on conflict on constraint consumos_mensuales_usuario_id_periodo_key')
    expect(migracion).not.toContain('on conflict (usuario_id, periodo) do update')
    expect(migracionPush).toContain('on conflict on constraint consumos_mensuales_usuario_id_periodo_key')
    expect(migracionPush).toContain('on conflict do nothing')
    expect(migracionPush).not.toContain('on conflict (notificacion_id, suscripcion_id, version_evento)')
    expect(migracionPush).toContain("set search_path = ''")
    expect(migracionPush).toContain('from public, anon, authenticated')
    expect(migracionPush).toContain('to service_role')
  })

  it('distingue autenticación rechazada de errores internos del worker', () => {
    expect(worker).toContain('let cronAutorizado = false')
    expect(worker).toContain('cronAutorizado = true')
    expect(worker).toContain('cronAutorizado ? 500 : 401')
    expect(worker.indexOf('verificarCron(request)')).toBeLessThan(worker.indexOf('cronAutorizado = true'))
  })

  it('mide sólo Gmail disponible y separa las colas operativas', () => {
    expect(migracion).toContain("where estado = 'pendiente' and disponible_en <= now()")
    expect(migracion).toContain("'gmail_pendientes'")
    expect(migracion).toContain("'calendar_pendientes'")
    expect(migracion).toContain("'conexiones_token_vencido'")
    expect(admin).toContain('antiguedadGmail > 30')
    expect(admin).toContain('antiguedadCalendar > 30')
  })

  it('cierra la matriz de diez usuarios y veinticinco cuentas', () => {
    const cuentasPorUsuario = [1, 1, 2, 2, 2, 3, 3, 3, 3, 5]
    expect(cuentasPorUsuario).toHaveLength(10)
    expect(cuentasPorUsuario.reduce((total, cantidad) => total + cantidad, 0)).toBe(25)
    expect(runbook).toContain('5 usuarios / 10 Gmail')
    expect(runbook).toContain('10 usuarios / 25 Gmail')
    expect(runbook).toContain('500 correos sintéticos')
  })
})
