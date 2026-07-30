import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const migracion = readFileSync(
  new URL(
    '../supabase/migrations/20260730020000_corregir_reactivacion_usuarios.sql',
    import.meta.url,
  ),
  'utf8',
).replace(/\s+/g, ' ').trim().toLowerCase()

describe('reactivación administrativa de usuarios', () => {
  it('resuelve el usuario según la tabla del trigger sin leer columnas inexistentes', () => {
    expect(migracion).toContain(
      "if tg_relid = 'public.perfiles'::regclass then usuario_afectado := new.id;",
    )
    expect(migracion).toContain(
      "elsif tg_relid = 'public.suscripciones'::regclass then usuario_afectado := new.usuario_id;",
    )
    expect(migracion).not.toContain(
      "usuario_afectado := case when tg_table_name = 'perfiles'",
    )
  })

  it('mantiene el trigger privado y con search_path seguro', () => {
    expect(migracion).toContain('security definer')
    expect(migracion).toContain("set search_path = ''")
    expect(migracion).toContain(
      'revoke execute on function private.ajustar_automatizacion_usuario() from public, anon, authenticated',
    )
  })
})
