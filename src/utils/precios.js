export function convertirUsdAArs(precioUsd, dolarBlueVenta) {
  return Math.ceil((precioUsd * dolarBlueVenta) / 500) * 500
}
