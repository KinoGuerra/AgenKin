import { envRequerida } from './http.ts'

const SISTEMA = `Sos un clasificador de correos. Devolvé exclusivamente JSON válido, sin markdown.
Categorías: factura, pago, entrega, renovacion, turno, reunion, respuesta, documentacion, promocion, irrelevante u otro.
Interpretá fechas relativas usando la fecha del correo y America/Argentina/Cordoba.
Formato exacto: {"relevante":boolean,"categoria":string,"tipo":string,"titulo":string,"descripcion":string,"fecha":"YYYY-MM-DD"|null,"hora":"HH:MM"|null,"zona_horaria":"America/Argentina/Cordoba","confianza":number,"requiere_revision":boolean,"explicacion":string}.
Si la fecha es ambigua, marcá requiere_revision=true. No inventes una fecha.`

export async function clasificarCorreo(datos: { asunto: string; remitente: string; fecha: string; texto: string }) {
  const { AI_API_KEY, AI_MODEL } = envRequerida('AI_API_KEY', 'AI_MODEL')
  const AI_API_URL = Deno.env.get('AI_API_URL') || 'https://api.openai.com/v1/chat/completions'
  const respuesta = await fetch(AI_API_URL, {
    method: 'POST',
    headers: { Authorization: `Bearer ${AI_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: AI_MODEL,
      temperature: 0,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: SISTEMA },
        {
          role: 'user',
          content: JSON.stringify({
            asunto: datos.asunto.slice(0, 500),
            remitente: datos.remitente.slice(0, 300),
            fecha_correo: datos.fecha,
            texto: datos.texto.slice(0, 12000),
          }),
        },
      ],
    }),
  })
  const contenido = await respuesta.json()
  if (!respuesta.ok) throw new Error('El proveedor de IA rechazó la clasificación')
  const texto = contenido.choices?.[0]?.message?.content
  if (!texto) throw new Error('El proveedor de IA devolvió una respuesta vacía')
  const resultado = JSON.parse(texto)
  const confianza = Number(resultado.confianza)
  if (!Number.isFinite(confianza) || confianza < 0 || confianza > 1) throw new Error('Confianza de IA inválida')
  if (resultado.relevante && !/^\d{4}-\d{2}-\d{2}$/.test(resultado.fecha || '')) {
    throw new Error('Fecha de IA inválida')
  }
  return {
    relevante: resultado.relevante === true,
    categoria: String(resultado.categoria || 'otro').slice(0, 50),
    tipo: String(resultado.tipo || 'otro').slice(0, 50),
    titulo: String(resultado.titulo || '').slice(0, 160),
    descripcion: String(resultado.descripcion || '').slice(0, 1000),
    fecha: resultado.fecha || null,
    hora: /^\d{2}:\d{2}$/.test(resultado.hora || '') ? resultado.hora : null,
    zona_horaria: 'America/Argentina/Cordoba',
    confianza,
    requiere_revision: resultado.requiere_revision === true || confianza < 0.75,
    explicacion: String(resultado.explicacion || '').slice(0, 500),
  }
}
