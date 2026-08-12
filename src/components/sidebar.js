export function inicializarColapsoLateral({ clave, claseCuerpo = '' } = {}) {
  const barraLateral = document.querySelector('.barra-lateral')
  const boton = document.querySelector('[data-menu-lateral-toggle]')
  if (!barraLateral || !boton || !clave) return null

  const esVistaMovil = () => window.matchMedia('(max-width: 760px)').matches
  const actualizar = () => {
    const colapsado = barraLateral.classList.contains('barra-lateral--colapsada')
    boton.dataset.state = colapsado ? 'collapsed' : 'expanded'
    boton.setAttribute('aria-expanded', String(!colapsado))
    boton.setAttribute('aria-label', colapsado ? 'Expandir menú lateral' : 'Contraer menú lateral')
    boton.title = boton.getAttribute('aria-label')
    const icono = boton.querySelector('span') || boton
    icono.textContent = colapsado ? 'chevron_right' : 'chevron_left'
    if (claseCuerpo) document.body.classList.toggle(claseCuerpo, colapsado)
  }

  const restaurar = () => {
    if (esVistaMovil()) {
      barraLateral.classList.remove('barra-lateral--colapsada')
      actualizar()
      return
    }
    try {
      barraLateral.classList.toggle('barra-lateral--colapsada', localStorage.getItem(clave) === 'true')
    } catch {
      barraLateral.classList.remove('barra-lateral--colapsada')
    }
    actualizar()
  }

  restaurar()
  boton.addEventListener('click', () => {
    if (esVistaMovil()) return
    const colapsado = barraLateral.classList.toggle('barra-lateral--colapsada')
    try {
      localStorage.setItem(clave, String(colapsado))
    } catch {
      // El menú sigue funcionando aunque el navegador bloquee el almacenamiento local.
    }
    actualizar()
  })
  window.addEventListener('resize', restaurar)
  return { barraLateral, restaurar }
}
