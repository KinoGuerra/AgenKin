import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const leer = (ruta) => readFileSync(new URL(`../${ruta}`, import.meta.url), 'utf8')
const adminHtml = leer('admin.html')
const accessHtml = leer('access.html')
const admin = leer('src/pages/admin.js')
const access = leer('src/pages/access.js')
const estilos = leer('src/styles/global.css')
const estilosPortal = leer('src/styles/portal.css')
const funcionAdministrativa = leer('supabase/functions/admin-manage-user/index.ts')

describe('barrera visual del portal administrador', () => {
  it('mantiene oculto admin.html hasta completar sesión, rol y AAL2', () => {
    expect(adminHtml).toContain('class="ruta-protegida-pendiente"')
    expect(adminHtml).toContain('Validando acceso administrativo…')
    expect(estilos).toContain('html.ruta-protegida-pendiente body > :not(.estado-ruta-protegida)')
    expect(admin.indexOf("await protegerRuta('admin')"))
      .toBeLessThan(admin.indexOf("classList.remove('ruta-protegida-pendiente')"))
  })

  it('valida AAL2 desde el selector antes de navegar a admin.html', () => {
    expect(accessHtml).toContain('data-admin-access')
    expect(access).toContain('evento.preventDefault()')
    expect(access).toContain("await protegerRuta('admin')")
    expect(access.indexOf("await protegerRuta('admin')"))
      .toBeLessThan(access.indexOf('window.location.assign(enlaceAdmin.href)'))
  })

  it('usa un encabezado operativo y un estado de menú independiente', () => {
    expect(adminHtml).toContain('encabezado-global--admin')
    expect(adminHtml).toContain('data-menu-lateral-toggle')
    expect(adminHtml).toContain('data-alertas-operativas')
    expect(admin).toContain("inicializarColapsoLateral({ clave: 'agenkin_menu_admin_colapsado'")
    expect(leer('src/pages/app.js')).toContain("inicializarColapsoLateral({ clave: 'agenkin_menu_lateral_colapsado' })")
    expect(admin).toContain('detener_carga_historica')
    expect(admin).toContain('alerta_mas_antigua_minutos')
    expect(admin).not.toContain("from('notificaciones')")
    expect(estilosPortal).toContain('body.portal--admin.menu-admin-colapsado .menu-lateral-toggle')
    expect(funcionAdministrativa).toContain('if (metricasResultado.error)')
    expect(funcionAdministrativa).not.toContain('metricasResultado.error || notificacionesResultado.error')
  })
})
