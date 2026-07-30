import { existsSync, readFileSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { describe, expect, it } from 'vitest'

const leer = (ruta) => readFileSync(new URL(`../${ruta}`, import.meta.url), 'utf8')
const landing = leer('index.html')

describe('landing preparada para producción', () => {
  it('publica metadatos SEO y sociales consistentes', () => {
    expect(landing).toContain('<html lang="es-AR">')
    expect(landing).toContain('rel="canonical" href="https://kinoguerra.github.io/AgenKin/"')
    expect(landing).toContain('property="og:image"')
    expect(landing).toContain('name="twitter:card" content="summary_large_image"')
    expect(landing).toContain('rel="manifest" href="./site.webmanifest"')
    expect(landing.match(/<h1\b/g)).toHaveLength(1)
  })

  it('explica permisos y tratamiento de datos antes del ingreso', () => {
    expect(landing).toContain('Gmail en modo lectura')
    expect(landing).toContain('Calendar se autoriza por separado')
    expect(landing).toContain('Sin guardar el cuerpo completo')
    expect(landing).toContain('./privacidad.html#eliminacion')
    expect(landing).not.toContain('A definir')
    expect(landing).not.toContain('El MVP')
  })

  it('muestra los límites multicuenta de los planes públicos', () => {
    expect(landing).toContain('<h3>Prueba</h3>')
    expect(landing).toContain('<h3>Dúo</h3>')
    expect(landing).toContain('<h3>Pro</h3>')
    expect(landing).toContain('<h3>Ultra</h3>')
    expect(landing).toContain('<strong>5</strong> cuentas Gmail')
    expect(landing).toContain('No aplicamos un cupo comercial por mensajes')
    expect(landing).not.toContain('<h3>AgenKin</h3>')
    expect(landing).toContain('Los precios comerciales todavía no están publicados.')
    expect(landing).not.toContain('Ingresar y solicitar')
  })

  it('mantiene una política CSP sin ejecución insegura', () => {
    const csp = landing.match(/http-equiv="Content-Security-Policy" content="([^"]+)"/)?.[1]
    const cargadorLocal = landing.match(/<script>(if\(location\.protocol==='file:'\).*?)<\/script>/)?.[1]
    expect(csp).toBeTruthy()
    expect(cargadorLocal).toBeTruthy()
    expect(csp).not.toContain("'unsafe-inline'")
    expect(csp).not.toContain("'unsafe-eval'")
    expect(csp).not.toContain('*.supabase.co')
    expect(csp).not.toContain('wss:')
    expect(csp).toContain('https://kpqzwbhprqlapwhadejt.supabase.co')
    expect(csp).toContain("object-src 'none'")
    expect(csp).toContain("base-uri 'self'")
    expect(csp).toContain(`'sha256-${createHash('sha256').update(cargadorLocal).digest('base64')}'`)
  })

  it('restringe las conexiones del frontend al proyecto Supabase de AgenKin', () => {
    ;[
      'index.html',
      'app.html',
      'configuracion.html',
      'correos.html',
      'vencimientos.html',
      'agenda.html',
      'reglas.html',
      'admin.html',
      'access.html',
      'mfa.html',
      'auth-callback.html',
      'cuenta-bloqueada.html',
    ].forEach((pagina) => {
      const csp = leer(pagina).match(/http-equiv="Content-Security-Policy" content="([^"]+)"/)?.[1]
      expect(csp).toContain('https://kpqzwbhprqlapwhadejt.supabase.co')
      expect(csp).not.toContain('*.supabase.co')
      expect(csp).not.toContain('wss:')
    })
  })

  it('incluye recursos de indexación e instalación válidos', () => {
    const manifest = JSON.parse(leer('public/site.webmanifest'))
    expect(manifest.start_url).toBe('/AgenKin/')
    expect(manifest.icons).toHaveLength(2)
    expect(leer('public/robots.txt')).toContain('Sitemap: https://kinoguerra.github.io/AgenKin/sitemap.xml')
    expect(leer('public/sitemap.xml')).toContain('<loc>https://kinoguerra.github.io/AgenKin/</loc>')
    ;[
      'public/agenkin-icon-32.png',
      'public/agenkin-icon-180.png',
      'public/agenkin-icon-192.png',
      'public/agenkin-icon-512.png',
      'public/agenkin-social.png',
    ].forEach((ruta) => {
      expect(existsSync(new URL(`../${ruta}`, import.meta.url))).toBe(true)
    })
  })

  it('concede permisos de publicación solamente al job de deploy', () => {
    const workflow = leer('.github/workflows/deploy-pages.yml')
    const permisosGlobales = workflow.slice(
      workflow.indexOf('permissions:'),
      workflow.indexOf('concurrency:'),
    )
    const deploy = workflow.slice(workflow.indexOf('  deploy:'))
    expect(permisosGlobales).toContain('contents: read')
    expect(permisosGlobales).not.toContain('pages: write')
    expect(permisosGlobales).not.toContain('id-token: write')
    expect(deploy).toContain('pages: write')
    expect(deploy).toContain('id-token: write')
  })
})
