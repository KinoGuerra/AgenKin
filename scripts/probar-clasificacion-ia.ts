import { clasificarCorreo } from '../supabase/functions/_shared/ai.ts'

const correoFicticio = {
  asunto: 'Vencimiento factura de internet',
  remitente: 'facturacion@proveedor.example',
  fecha: 'Mon, 27 Jul 2026 10:00:00 -0300',
  texto: 'La factura correspondiente al mes de julio vence el 5 de agosto de 2026. El importe total es de $85.000.',
}

try {
  const resultado = await clasificarCorreo(correoFicticio)
  console.log(JSON.stringify(resultado, null, 2))
} catch (error) {
  const codigo = error && typeof error === 'object' && 'codigo' in error ? error.codigo : 'ERROR_DESCONOCIDO'
  console.error(`La prueba no pudo completarse (${codigo}).`)
  Deno.exit(1)
}
