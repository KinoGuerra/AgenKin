(function prepararTema(global) {
  const TEMAS = new Set(['light', 'dark'])

  function resolverTema(preferenciaGuardada, prefiereOscuro) {
    return TEMAS.has(preferenciaGuardada) ? preferenciaGuardada : prefiereOscuro ? 'dark' : 'light'
  }

  function preferenciaGuardada() {
    try {
      return global.localStorage.getItem('agenkin-tema')
    } catch {
      return null
    }
  }

  function actualizarControles(tema) {
    const oscuro = tema === 'dark'
    global.document.querySelectorAll('[data-theme-toggle]').forEach((boton) => {
      const esInterruptor = boton.matches('input[role="switch"]')
      const contenedor = esInterruptor ? boton.closest('.tema-switch') : boton
      if (esInterruptor) {
        boton.checked = oscuro
        boton.setAttribute('aria-checked', String(oscuro))
        boton.setAttribute('aria-label', 'Modo oscuro')
        boton.title = oscuro ? 'Modo oscuro activado' : 'Modo oscuro desactivado'
      } else {
        boton.setAttribute('aria-pressed', String(oscuro))
        boton.setAttribute('aria-label', oscuro ? 'Activar modo claro' : 'Activar modo oscuro')
        boton.title = oscuro ? 'Activar modo claro' : 'Activar modo oscuro'
      }
      const icono = contenedor?.querySelector('[data-theme-icon]')
      if (icono) icono.textContent = esInterruptor ? (oscuro ? '☾' : '☀') : (oscuro ? '☀' : '☾')
      const etiqueta = contenedor?.querySelector('[data-theme-label]')
      if (etiqueta) etiqueta.textContent = esInterruptor ? 'Modo oscuro' : (oscuro ? 'Claro' : 'Oscuro')
    })
  }

  function aplicarTema(tema, guardar = false) {
    global.document.documentElement.dataset.theme = tema
    global.document.documentElement.style.colorScheme = tema
    actualizarControles(tema)
    if (guardar) {
      try {
        global.localStorage.setItem('agenkin-tema', tema)
      } catch {
        // El tema sigue funcionando aunque el navegador bloquee el almacenamiento.
      }
    }
  }

  function cambiarTemaDesde(boton) {
    const tema = global.document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark'
    const reducirMovimiento = global.matchMedia('(prefers-reduced-motion: reduce)').matches
    const transicionDisponible = typeof global.document.startViewTransition === 'function'
    const raiz = global.document.documentElement

    if (reducirMovimiento) {
      aplicarTema(tema, true)
      return
    }

    const control = boton.closest?.('.tema-switch') || boton
    const rectangulo = control.getBoundingClientRect()
    if (raiz.classList.contains('tema-en-transicion')) {
      actualizarControles(raiz.dataset.theme)
      return
    }

    if (!transicionDisponible) {
      const x = rectangulo.left + rectangulo.width / 2
      const y = rectangulo.top + rectangulo.height / 2
      const radio = Math.hypot(Math.max(x, global.innerWidth - x), Math.max(y, global.innerHeight - y))
      const cortina = global.document.createElement('span')
      cortina.className = 'tema-cortina'
      cortina.dataset.tema = tema
      global.document.body.append(cortina)

      if (typeof cortina.animate !== 'function') {
        aplicarTema(tema, true)
        cortina.remove()
        return
      }

      raiz.classList.add('tema-en-transicion')
      const revelar = cortina.animate(
        [
          { clipPath: `circle(0 at ${x}px ${y}px)` },
          { clipPath: `circle(${radio}px at ${x}px ${y}px)` },
        ],
        { duration: 700, easing: 'cubic-bezier(.4, 0, .2, 1)', fill: 'forwards' },
      )
      revelar.finished.catch(() => null).then(() => {
        aplicarTema(tema, true)
        return cortina.animate([{ opacity: 1 }, { opacity: 0 }], {
          duration: 250,
          easing: 'ease-out',
          fill: 'forwards',
        }).finished.catch(() => null)
      }).catch(() => null).then(() => {
        cortina.remove()
        raiz.classList.remove('tema-en-transicion')
      })
      return
    }

    raiz.style.setProperty('--tema-x', `${rectangulo.left + rectangulo.width / 2}px`)
    raiz.style.setProperty('--tema-y', `${rectangulo.top + rectangulo.height / 2}px`)
    raiz.classList.add('tema-en-transicion')

    const transicion = global.document.startViewTransition(() => aplicarTema(tema, true))
    transicion.finished.catch(() => null).then(() => {
      raiz.classList.remove('tema-en-transicion')
      raiz.style.removeProperty('--tema-x')
      raiz.style.removeProperty('--tema-y')
    })
  }

  function inicializarTema() {
    const media = global.matchMedia('(prefers-color-scheme: dark)')
    aplicarTema(resolverTema(preferenciaGuardada(), media.matches))

    global.document.querySelectorAll('[data-theme-toggle]').forEach((boton) => {
      const evento = boton.matches('input[role="switch"]') ? 'change' : 'click'
      boton.addEventListener(evento, () => cambiarTemaDesde(boton))
    })

    const seguirSistema = (evento) => {
      if (!preferenciaGuardada()) aplicarTema(evento.matches ? 'dark' : 'light')
    }
    if (media.addEventListener) media.addEventListener('change', seguirSistema)
    else media.addListener(seguirSistema)
  }

  global.AgenKinTheme = Object.freeze({ resolverTema, inicializarTema })
  if (global.document) inicializarTema()
})(globalThis)
