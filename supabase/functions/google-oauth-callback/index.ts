import { cifrarToken, hashEstado } from '../_shared/crypto.ts'
import { appUrlSegura, envRequerida } from '../_shared/http.ts'
import { clienteServicio } from '../_shared/supabase.ts'

function redirigir(estado: 'conectado' | 'error') {
  const app = appUrlSegura()
  app.pathname += 'app.html'
  app.searchParams.set('google', estado)
  return Response.redirect(app.href, 302)
}

Deno.serve(async (request) => {
  try {
    const { GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, GOOGLE_REDIRECT_URI } = envRequerida(
      'GOOGLE_CLIENT_ID', 'GOOGLE_CLIENT_SECRET', 'GOOGLE_REDIRECT_URI', 'TOKEN_ENCRYPTION_KEY', 'APP_PUBLIC_URL',
    )
    const url = new URL(request.url)
    const codigo = url.searchParams.get('code')
    const estado = url.searchParams.get('state')
    if (!codigo || !estado || url.searchParams.has('error')) return redirigir('error')

    const cliente = clienteServicio()
    const hash = await hashEstado(estado)
    const ahora = new Date().toISOString()
    const { data: registro } = await cliente
      .from('oauth_states')
      .update({ usado_en: ahora })
      .eq('hash_estado', hash)
      .is('usado_en', null)
      .gt('vence_en', ahora)
      .select('usuario_id')
      .maybeSingle()
    if (!registro) return redirigir('error')

    const respuestaToken = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code: codigo,
        client_id: GOOGLE_CLIENT_ID,
        client_secret: GOOGLE_CLIENT_SECRET,
        redirect_uri: GOOGLE_REDIRECT_URI,
        grant_type: 'authorization_code',
      }),
    })
    const tokens = await respuestaToken.json()
    if (!respuestaToken.ok || !tokens.access_token) return redirigir('error')
    const perfilGoogle = await fetch('https://openidconnect.googleapis.com/v1/userinfo', {
      headers: { Authorization: `Bearer ${tokens.access_token}` },
    }).then((respuesta) => respuesta.json())

    const { data: existente } = await cliente
      .from('conexiones_google')
      .select('refresh_token_cifrado,token_iv')
      .eq('usuario_id', registro.usuario_id)
      .maybeSingle()
    const tokenSeguro = tokens.refresh_token ? await cifrarToken(tokens.refresh_token) : null
    if (!tokenSeguro && !existente?.refresh_token_cifrado) return redirigir('error')
    const { error } = await cliente.from('conexiones_google').upsert({
      usuario_id: registro.usuario_id,
      google_email: perfilGoogle.email || null,
      gmail_conectado: true,
      calendar_conectado: true,
      refresh_token_cifrado: tokenSeguro?.token_cifrado || existente?.refresh_token_cifrado,
      token_iv: tokenSeguro?.iv || existente?.token_iv,
      estado_conexion: 'activa',
    }, { onConflict: 'usuario_id' })
    if (error) return redirigir('error')
    return redirigir('conectado')
  } catch {
    return redirigir('error')
  }
})
