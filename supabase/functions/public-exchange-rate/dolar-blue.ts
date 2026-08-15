const PATRON_VENTA = /<p[^>]*>\s*([\d.]+(?:,\d+)?)\s*<span[^>]*>\s*Venta\s*<\/span>\s*<\/p>/i

export function extraerVentaDolarBlue(html: string) {
  const coincidencia = html.match(PATRON_VENTA)
  if (!coincidencia) throw new Error('Cotización de venta ausente')

  const venta = Number(coincidencia[1].replace(/\./g, '').replace(',', '.'))
  if (!Number.isFinite(venta) || venta < 100 || venta > 100000) {
    throw new Error('Cotización de venta inválida')
  }
  return venta
}
