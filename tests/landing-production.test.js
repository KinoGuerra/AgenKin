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

  it('muestra los límites reales de los planes activos', () => {
    expect(landing).toContain('<strong>50</strong> correos / mes')
    expect(landing).toContain('<strong>300</strong> correos / mes')
    expect(landing).toContain('<strong>1.500</strong> correos / mes')
    expect(landing).toContain('Los precios comerciales todavía no están publicados.')
  })

  it('mantiene una política CSP sin ejecución insegura', () => {
    const csp = landing.match(/http-equiv="Content-Security-Policy" content="([^"]+)"/)?.[1]
    const cargadorLocal = landing.match(/<script>(if\(location\.protocol==='file:'\).*?)<\/script>/)?.[1]
    expect(csp).toBeTruthy()
    expect(cargadorLocal).toBeTruthy()
    expect(csp).not.toContain("'unsafe-inline'")
    expect(csp).not.toContain("'unsafe-eval'")
    expect(csp).toContain("object-src 'none'")
    expect(csp).toContain("base-uri 'self'")
    expect(csp).toContain(`'sha256-${createHash('sha256').update(cargadorLocal).digest('base64')}'`)
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
})
