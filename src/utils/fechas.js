const FECHA_ISO = /^\d{4}-\d{2}-\d{2}$/

export function normalizarFecha(valor) {
  if (!valor) return null
  const texto = String(valor).trim()
  if (FECHA_ISO.test(texto)) {
    const fecha = new Date(`${texto}T12:00:00Z`)
    return Number.isNaN(fecha.getTime()) ? null : texto
  }

  const coincidencia = texto.match(/^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$/)
  if (!coincidencia) return null
  const [, dia, mes, anio] = coincidencia
  const iso = `${anio}-${mes.padStart(2, '0')}-${dia.padStart(2, '0')}`
  const fecha = new Date(`${iso}T12:00:00Z`)
  return fecha.getUTCFullYear() === Number(anio) &&
    fecha.getUTCMonth() + 1 === Number(mes) &&
    fecha.getUTCDate() === Number(dia)
    ? iso
    : null
}

export function calcularFinPrueba(inicio, dias = 15) {
  const fecha = new Date(inicio)
  if (Number.isNaN(fecha.getTime()) || !Number.isInteger(dias) || dias < 1) return null
  fecha.setUTCDate(fecha.getUTCDate() + dias)
  return fecha.toISOString()
}

export function formatearFecha(valor, locale = 'es-AR') {
  if (!valor) return 'Sin fecha'
  const texto = String(valor).trim()
  const esFechaSinHora = FECHA_ISO.test(texto)
  const fecha = new Date(esFechaSinHora ? `${texto}T12:00:00Z` : texto)
  if (Number.isNaN(fecha.getTime())) return 'Fecha inválida'
  return new Intl.DateTimeFormat(locale, {
    dateStyle: 'medium',
    timeZone: esFechaSinHora ? 'UTC' : 'America/Argentina/Cordoba',
  }).format(fecha)
}

export function formatearFechaHora(valor, locale = 'es-AR') {
  if (!valor) return 'Sin actualizaciones'
  const fecha = new Date(valor)
  if (Number.isNaN(fecha.getTime())) return 'Fecha inválida'
  const partes = new Intl.DateTimeFormat(locale, {
    timeZone: 'America/Argentina/Cordoba',
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(fecha)
  const valorDe = (tipo) => partes.find((parte) => parte.type === tipo)?.value || ''
  return `${valorDe('day')}/${valorDe('month')}/${valorDe('year')} ${valorDe('hour')}:${valorDe('minute')}`
}

export function fechaActualIso(
  zonaHoraria = 'America/Argentina/Cordoba',
  ahora = new Date(),
) {
  const partes = new Intl.DateTimeFormat('en-US', {
    timeZone: zonaHoraria,
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).formatToParts(ahora)
  const valorDe = (tipo) => partes.find((parte) => parte.type === tipo)?.value || ''
  return `${valorDe('year')}-${valorDe('month')}-${valorDe('day')}`
}
