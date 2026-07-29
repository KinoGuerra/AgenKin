if (window.top !== window.self) {
  document.documentElement.hidden = true
  try {
    window.top.location = window.self.location.href
  } catch {
    // El documento permanece oculto si el navegador impide salir del marco.
  }
}
