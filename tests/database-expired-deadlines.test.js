import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const migracionEnum = readFileSync(
  new URL(
    '../supabase/migrations/20260730215410_impedir_vencimientos_pasados.sql',
    import.meta.url,
  ),
  'utf8',
).replace(/\s+/g, ' ').trim().toLowerCase()
const migracion = readFileSync(
  new URL(
    '../supabase/migrations/20260730215712_marcar_vencimientos_vencidos.sql',
    import.meta.url,
  ),
  'utf8',
).replace(/\s+/g, ' ').trim().toLowerCase()

describe('integridad temporal de vencimientos', () => {
  it('agrega un estado explícito para fechas ya vencidas', () => {
    expect(migracionEnum).toContain(
      "alter type public.estado_vencimiento add value if not exists 'vencido'",
    )
  })

  it('marca nuevos pendientes pasados según la fecha argentina', () => {
    expect(migracion).toContain(
      "new.fecha_vencimiento < (now() at time zone 'america/argentina/cordoba')::date",
    )
    expect(migracion).toContain("new.estado := 'vencido'")
    expect(migracion).toContain(
      'before insert or update of fecha_vencimiento, estado on public.vencimientos_detectados',
    )
  })

  it('marca pendientes históricos sin borrar su correo ni métricas', () => {
    expect(migracion).toContain(
      "update public.vencimientos_detectados set estado = 'vencido'",
    )
    expect(migracion).not.toContain('delete from public.correos_procesados')
    expect(migracion).not.toContain('delete from public.vencimientos_detectados')
  })

  it('mantiene la función fuera de la API pública', () => {
    expect(migracion).toContain("set search_path = ''")
    expect(migracion).toContain(
      'revoke execute on function private.marcar_vencimiento_vencido() from public, anon, authenticated',
    )
  })
})
