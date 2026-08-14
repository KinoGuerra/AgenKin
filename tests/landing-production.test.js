import { existsSync, readFileSync } from 'node:fs'
import { createHash } from 'node:crypto'
import { describe, expect, it } from 'vitest'

const leer = (ruta) => readFileSync(new URL(`../${ruta}`, import.meta.url), 'utf8')
const landing = leer('index.html')
const landingJs = leer('src/pages/landing.js')
const estilosLanding = leer('src/styles/landing.css')

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
    expect(landing).toContain('Calendar opcional')
    expect(landing).toContain('Tu información, siempre bajo tu control')
    expect(landing).toContain('No vende tus datos ni modifica tus mensajes')
    expect(landing).toContain('Solo lectura')
    expect(landing).toContain('./privacidad.html#eliminacion')
    expect(landing).not.toContain('A definir')
    expect(landing).not.toContain('El MVP')
    expect(landing).not.toContain('remitentes que hayas priorizado')
  })

  it('describe la Agenda interna, revisión y Calendar sin prometer automatización total', () => {
    expect(landing).toContain('Agenda interna es la fuente principal')
    expect(landing).toContain('Los casos ambiguos esperan tu revisión')
    expect(landing).toContain('una sola conexión Calendar opcional')
    expect(landing).toContain('Web Push se activa voluntariamente')
    expect(landing).toContain('<svg viewBox="0 0 1160 410"')
    expect(landing).toContain('Ya no olvidarás los acontecimientos que llegan a tu correo.</h2>')
  })

  it('anima las respuestas frecuentes al abrir y cerrar, respetando movimiento reducido', () => {
    expect(landingJs).toContain('function inicializarAcordeones()')
    expect(landingJs).toContain("'(prefers-reduced-motion: reduce)'")
    expect(landingJs).toContain("eventoFinal.propertyName !== 'max-height'")
    expect(landingJs).toContain('if (!abrir) acordeon.open = false')
    expect(landingJs).toContain("contenido.style.maxHeight = abrir ? '0px'")
    expect(estilosLanding).toContain('max-height .36s cubic-bezier(.22, 1, .36, 1)')
    expect(estilosLanding).toContain('.respuesta-frecuente')
  })

  it('consulta y construye de forma segura los planes públicos vigentes', () => {
    expect(landing).toContain('data-planes-publicos')
    expect(landingJs).toContain(".from('planes')")
    expect(landingJs).toContain(".eq('visible_publico', true)")
    expect(landingJs).toContain('function crearPlan(plan)')
    expect(landingJs).toContain('textContent = texto')
    expect(landing).not.toContain('<h3>AgenKin</h3>')
    expect(landing).not.toContain('durante la beta todos tienen precio cero')
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
    expect(csp).toContain("frame-src 'none'")
    expect(csp).not.toContain('frame-ancestors')
    expect(landing).toContain('./src/components/frame-guard.js')
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
