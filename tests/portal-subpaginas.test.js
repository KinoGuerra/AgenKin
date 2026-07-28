import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const leer = (ruta) => readFileSync(new URL(`../${ruta}`, import.meta.url), 'utf8')

describe('portal separado por subpáginas', () => {
  it('mantiene los cinco accesos rápidos como páginas compilables', () => {
    const portada = leer('app.html')
    ;['configuracion', 'correos', 'vencimientos', 'agenda', 'reglas'].forEach((pagina) => {
      expect(portada).toContain(`./${pagina}.html`)
      expect(leer(`${pagina}.html`)).toContain('data-portal-page=')
    })
  })

  it('calcula correos de hoy y protege las solicitudes de mejora por usuario', () => {
    const migracion = leer('supabase/migrations/20260728214956_agregar_correos_analizados_hoy.sql')
    expect(migracion).toContain("'correos_analizados_hoy'")
    expect(migracion).toContain('solicitudes_mejora_plan_pendiente_idx')
    expect(migracion).toContain('with check ((select auth.uid()) = usuario_id')
    expect(migracion).toContain('alter table public.solicitudes_mejora_plan enable row level security')
  })
})
