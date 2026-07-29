import { resolve } from 'node:path'
import { defineConfig } from 'vite'

const paginas = [
  'index.html',
  'app.html',
  'correos.html',
  'vencimientos.html',
  'agenda.html',
  'reglas.html',
  'configuracion.html',
  'admin.html',
  'access.html',
  'mfa.html',
  'auth-callback.html',
  'privacidad.html',
  'terminos.html',
  'cuenta-bloqueada.html',
]

export default defineConfig({
  base: '/AgenKin/',
  build: {
    rollupOptions: {
      input: Object.fromEntries(
        paginas.map((pagina) => [pagina.replace('.html', ''), resolve(import.meta.dirname, pagina)]),
      ),
    },
  },
  test: {
    environment: 'node',
    coverage: { reporter: ['text', 'json', 'html'] },
  },
})
