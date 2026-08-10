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
    expect(servicio).toContain(
      'vencimientos_detectados!vencimientos_correo_usuario_fkey(titulo,descripcion,fecha_vencimiento,monto)',
    )
    expect(servicio).toContain(
      'correos_procesados!vencimientos_correo_usuario_fkey(asunto)',
    )
    expect(servicio).toContain(".gte('fecha_vencimiento', fechaActualIso())")
    expect(servicio).toContain(".in('estado', ['pendiente', 'confirmado', 'evento_creado', 'error'])")
    expect(servicio).toContain('eventos_calendar!eventos_vencimiento_usuario_fkey')
    expect(pagina).toContain("item.estado === 'vencido'")
    expect(pagina).toContain('const hoy = fechaActualIso()')
    expect(pagina).toContain("item.fecha_vencimiento < hoy")
    expect(pagina).toContain("vencido ? 'Sin acciones' : 'Finalizado'")
    expect(pagina).toContain('crearDetalleCorreo(item)')
    expect(pagina).toContain("correo.error_procesamiento === 'AI_LIMITE_TEMPORAL'")
    expect(pagina).toContain("correo.error_procesamiento === 'AI_PRESUPUESTO_DIARIO'")
    expect(pagina).toContain("correo.error_procesamiento === 'AI_REINTENTOS_AGOTADOS'")
    expect(pagina).toContain("return correo.estado_procesamiento === 'error' && errorCorreoTemporal")
    expect(servicio).toContain("nullsFirst: false")
    expect(servicio).not.toContain('cuerpo')
  })

  it('descarta vencimientos mediante una transición controlada', () => {
    const pagina = leer('src/pages/app.js')
    expect(pagina).toContain("supabase.rpc('descartar_vencimiento'")
    expect(pagina).toContain('p_vencimiento_id: id')
    expect(pagina).toContain('Descartar y eliminar')
    expect(pagina).toContain('no volver a autoagendar')
    expect(pagina).not.toContain(".update({ estado: 'descartado' })")
  })

  it('mantiene accesibles el menú móvil y la selección de Agenda', () => {
    const pagina = leer('src/pages/app.js')
    expect(pagina).toContain("evento.key !== 'Escape'")
    expect(pagina).toContain("'aria-controls'")
    expect(pagina).toContain("'aria-label', abierto ? 'Cerrar menú' : 'Abrir menú'")
    expect(pagina).toContain("'aria-pressed', String(seleccionado)")
  })

  it('permite crear compromisos manuales sin mezclarlos con hallazgos de correo', () => {
    const agenda = leer('agenda.html')
    const pagina = leer('src/pages/app.js')
    const servicio = leer('src/services/portal.js')
    const migracion = leer('supabase/migrations/20260810163618_agregar_eventos_manuales_agenda.sql')
      .replace(/\s+/g, ' ').toLowerCase()
    expect(agenda).toContain('data-nuevo-evento')
    expect(agenda).toContain('data-evento-manual-form')
    expect(pagina).toContain("supabase.rpc('crear_evento_manual'")
    expect(servicio).toContain(".not('correo_id', 'is', null)")
    expect(migracion).toContain('alter column correo_id drop not null')
    expect(migracion).toContain('create or replace function private.crear_evento_manual(')
    expect(migracion).toContain('create or replace function public.crear_evento_manual(')
    expect(migracion).toContain('security invoker')
    expect(migracion).toContain('v_usuario_id uuid := (select auth.uid())')
    expect(migracion).toContain('if not (select private.usuario_habilitado())')
    expect(migracion).toContain('v_evento_id := public.registrar_evento_agenda(')
    expect(migracion).toContain('from public, anon, authenticated')
    expect(migracion).toContain('to authenticated')
  })

  it('muestra la foto de Google con iniciales como respaldo seguro', () => {
    const pagina = leer('src/pages/app.js')
    const estilos = leer('src/styles/portal.css')
    ;[
      'app.html',
      'configuracion.html',
      'correos.html',
      'vencimientos.html',
      'agenda.html',
      'reglas.html',
    ].forEach((archivo) => {
      const html = leer(archivo)
      expect(html).toContain('data-avatar-imagen')
      expect(html).toContain('data-avatar-iniciales')
      expect(html).toContain('referrerpolicy="no-referrer"')
    })
    expect(pagina).toContain('metadatos.avatar_url')
    expect(pagina).toContain('metadatos.picture')
    expect(pagina).toContain("identidad.provider === 'google'")
    expect(pagina).toContain("url.protocol === 'https:'")
    expect(pagina).toContain("imagen.addEventListener('load'")
    expect(pagina).toContain("imagen.addEventListener('error'")
    expect(estilos).toContain('.avatar--imagen')
    expect(estilos).toContain('object-fit: cover')
  })
})
