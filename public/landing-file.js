(function prepararVistaComoArchivo(global) {
  if (global.location.protocol !== 'file:') return
  if (global.top !== global.self) {
    global.document.documentElement.hidden = true
    return
  }

  const documento = global.document
  const raiz = documento.documentElement
  const cabecera = documento.querySelector('[data-public-header]')
  const menu = documento.querySelector('[data-public-menu]')
  const botonMenu = documento.querySelector('[data-menu-toggle]')
  const estado = documento.querySelector('[data-auth-status]')
  const alertas = documento.querySelector('[data-alertas]')

  function aplicarTema(tema) {
    const oscuro = tema === 'dark'
    raiz.dataset.theme = tema
    raiz.style.colorScheme = tema
    documento.querySelectorAll('[data-theme-toggle]').forEach((boton) => {
      boton.setAttribute('aria-pressed', String(oscuro))
      boton.setAttribute('aria-label', oscuro ? 'Activar modo claro' : 'Activar modo oscuro')
      boton.querySelector('[data-theme-icon]').textContent = oscuro ? 'light_mode' : 'dark_mode'
      boton.querySelector('[data-theme-label]').textContent = oscuro ? 'Claro' : 'Oscuro'
    })
  }

  let tema
  try {
    tema = global.localStorage.getItem('agenkin-tema')
  } catch {
    tema = null
  }
  aplicarTema(tema === 'dark' || tema === 'light'
    ? tema
    : global.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')

  documento.querySelectorAll('[data-theme-toggle]').forEach((boton) => {
    boton.addEventListener('click', () => {
      const siguiente = raiz.dataset.theme === 'dark' ? 'light' : 'dark'
      aplicarTema(siguiente)
      try {
        global.localStorage.setItem('agenkin-tema', siguiente)
      } catch {
        // La preferencia solo se conserva durante esta vista.
      }
    })
  })

  estado.textContent = 'Vista local informativa · usá la versión web para ingresar'
  estado.dataset.estado = 'error'
  documento.querySelector('[data-current-year]').textContent = String(new Date().getFullYear())

  function cerrarMenu() {
    cabecera.removeAttribute('data-menu-open')
    botonMenu.setAttribute('aria-expanded', 'false')
    botonMenu.setAttribute('aria-label', 'Abrir navegación')
  }

  botonMenu.addEventListener('click', () => {
    const abierto = cabecera.hasAttribute('data-menu-open')
    if (abierto) {
      cerrarMenu()
      return
    }
    cabecera.setAttribute('data-menu-open', '')
    botonMenu.setAttribute('aria-expanded', 'true')
    botonMenu.setAttribute('aria-label', 'Cerrar navegación')
  })

  menu.querySelectorAll('a').forEach((enlace) => enlace.addEventListener('click', cerrarMenu))
  documento.querySelectorAll('[data-login]').forEach((boton) => {
    boton.addEventListener('click', () => {
      const aviso = documento.createElement('div')
      aviso.className = 'aviso aviso--advertencia'
      aviso.setAttribute('role', 'status')
      aviso.textContent = 'Para ingresar, abrí https://kinoguerra.github.io/AgenKin/ o ejecutá npm run dev.'
      alertas.replaceChildren(aviso)
    })
  })
})(globalThis)
