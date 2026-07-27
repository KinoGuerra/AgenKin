import { resolve } from 'node:path'
import { defineConfig } from 'vite'

const paginas = [
  'index.html',
  'app.html',
  'admin.html',
  'access.html',
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
