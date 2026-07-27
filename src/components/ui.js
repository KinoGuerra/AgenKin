export function mostrarAviso(mensaje, tipo = 'info', contenedor = document.querySelector('[data-alertas]')) {
  if (!contenedor) return
  const aviso = document.createElement('div')
  aviso.className = `aviso aviso--${tipo}`
  aviso.setAttribute('role', tipo === 'error' ? 'alert' : 'status')
  aviso.textContent = mensaje
  contenedor.replaceChildren(aviso)
}

export function setCargando(boton, cargando, texto = 'Procesando…') {
  if (!(boton instanceof HTMLButtonElement)) return
  if (cargando) {
    boton.dataset.textoOriginal = boton.textContent
    boton.textContent = texto
  } else {
    boton.textContent = boton.dataset.textoOriginal || boton.textContent
  }
  boton.disabled = cargando
  boton.setAttribute('aria-busy', String(cargando))
}

export function crearCelda(texto) {
  const celda = document.createElement('td')
  celda.textContent = texto ?? '—'
  return celda
}

export function estadoVacio(texto) {
  const elemento = document.createElement('p')
  elemento.className = 'estado-vacio'
  elemento.textContent = texto
  return elemento
}
