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
    const cabecera = portada.slice(portada.indexOf('<header class="cabecera-portal'), portada.indexOf('</header>'))
    const dashboard = portada.slice(portada.indexOf('<section id="inicio"'))
    const migracion = leer('supabase/migrations/20260728225511_agregar_avisos_del_dia.sql')
    expect(portada).toContain('data-avisos-dia')
    expect(portada).toContain('Avisos del día')
    expect(portada).toContain('>Dashboard<')
    expect(cabecera).not.toContain('data-avisos-dia')
    expect(dashboard).toContain('data-avisos-dia')
    expect(migracion).toContain("'avisos_del_dia'")
    expect(migracion).toContain('where v.usuario_id = (select auth.uid())')
    expect(migracion).toContain('vencimientos_usuario_fecha_activos_idx')
  })

  it('muestra la interpretación de cada correo sin almacenar su cuerpo', () => {
    const servicio = leer('src/services/portal.js')
    const pagina = leer('src/pages/app.js')
    expect(servicio).toContain('vencimientos_detectados(titulo,descripcion,fecha_vencimiento,monto)')
    expect(pagina).toContain('crearDetalleCorreo(item)')
    expect(pagina).toContain('Se reintentará en el próximo análisis.')
    expect(servicio).not.toContain('cuerpo')
  })

  it('descarta vencimientos mediante una transición controlada', () => {
    const pagina = leer('src/pages/app.js')
    expect(pagina).toContain("supabase.rpc('descartar_vencimiento'")
    expect(pagina).toContain('p_vencimiento_id: id')
    expect(pagina).not.toContain(".update({ estado: 'descartado' })")
  })

  it('mantiene accesibles el menú móvil y la selección de Agenda', () => {
    const pagina = leer('src/pages/app.js')
    expect(pagina).toContain("evento.key !== 'Escape'")
    expect(pagina).toContain("'aria-controls'")
    expect(pagina).toContain("'aria-label', abierto ? 'Cerrar menú' : 'Abrir menú'")
    expect(pagina).toContain("'aria-pressed', String(seleccionado)")
  })
})
