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

  it('muestra avisos del día desde un RPC restringido al usuario', () => {
    const portada = leer('app.html')
    const migracion = leer('supabase/migrations/20260728225511_agregar_avisos_del_dia.sql')
    expect(portada).toContain('data-avisos-dia')
    expect(portada).toContain('Avisos del día')
    expect(portada).toContain('>Dashboard<')
    expect(migracion).toContain("'avisos_del_dia'")
    expect(migracion).toContain('where v.usuario_id = (select auth.uid())')
    expect(migracion).toContain('vencimientos_usuario_fecha_activos_idx')
  })
})
