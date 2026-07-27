import { descifrarToken } from '../_shared/crypto.ts'
import { errorSeguro, json, manejarPreflight } from '../_shared/http.ts'
import { usuarioAutenticado } from '../_shared/supabase.ts'

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    const { usuario, cliente } = await usuarioAutenticado(request)
    const { data: conexion } = await cliente
      .from('conexiones_google')
      .select('refresh_token_cifrado,token_iv')
      .eq('usuario_id', usuario.id)
      .maybeSingle()
    if (conexion?.refresh_token_cifrado && conexion.token_iv) {
      const token = await descifrarToken(conexion.refresh_token_cifrado, conexion.token_iv)
      await fetch(`https://oauth2.googleapis.com/revoke?token=${encodeURIComponent(token)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      }).catch(() => null)
    }
    const { error } = await cliente.from('conexiones_google').upsert({
      usuario_id: usuario.id,
      google_email: null,
      gmail_conectado: false,
      calendar_conectado: false,
      calendar_id: null,
      refresh_token_cifrado: null,
      token_iv: null,
      estado_conexion: 'desconectada',
    }, { onConflict: 'usuario_id' })
    if (error) throw new Error('No se pudo desconectar la cuenta')
    return json({ ok: true })
  } catch (error) {
    return errorSeguro(error)
  }
})
