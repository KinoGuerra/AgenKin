import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const leer = (ruta) => readFileSync(new URL(`../${ruta}`, import.meta.url), 'utf8')
const adminHtml = leer('admin.html')
const accessHtml = leer('access.html')
const admin = leer('src/pages/admin.js')
const access = leer('src/pages/access.js')
const estilos = leer('src/styles/global.css')

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
})
