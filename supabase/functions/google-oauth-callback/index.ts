import { cifrarToken, hashEstado } from '../_shared/crypto.ts'
import { appUrlSegura, envRequerida } from '../_shared/http.ts'
import { clienteServicio } from '../_shared/supabase.ts'

function redirigir(
  estado: 'conectado' | 'error',
  motivo?: 'cuenta_google_distinta',
  servicio?: 'gmail' | 'calendar',
) {
  const app = appUrlSegura()
  app.pathname += 'app.html'
  app.searchParams.set('google', estado)
  if (motivo) app.searchParams.set('motivo', motivo)
  if (servicio) app.searchParams.set('servicio', servicio)
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
      .select('usuario_id,servicio')
      .maybeSingle()
    if (!registro) return redirigir('error')
    const { data: habilitado } = await cliente.rpc('usuario_habilitado', {
      usuario: registro.usuario_id,
    })
    if (!habilitado) return redirigir('error')

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
      .select('google_email,refresh_token_cifrado,token_iv,gmail_conectado,calendar_conectado')
      .eq('usuario_id', registro.usuario_id)
      .maybeSingle()
    if (existente?.google_email
      && perfilGoogle.email?.toLowerCase() !== existente.google_email.toLowerCase()) {
      return redirigir('error', 'cuenta_google_distinta')
    }
    const tokenSeguro = tokens.refresh_token ? await cifrarToken(tokens.refresh_token) : null
    if (!tokenSeguro && !existente?.refresh_token_cifrado) return redirigir('error')
    const permisos = new Set(String(tokens.scope || '').split(/\s+/))
    const permisoSolicitado = registro.servicio === 'gmail'
      ? 'https://www.googleapis.com/auth/gmail.readonly'
      : 'https://www.googleapis.com/auth/calendar.app.created'
    if (!permisos.has(permisoSolicitado)) return redirigir('error')
    const gmailConectado = Boolean(
      existente?.gmail_conectado
      || permisos.has('https://www.googleapis.com/auth/gmail.readonly'),
    )
    const calendarConectado = Boolean(
      existente?.calendar_conectado
      || permisos.has('https://www.googleapis.com/auth/calendar.app.created'),
    )
    const { error } = await cliente.from('conexiones_google').upsert({
      usuario_id: registro.usuario_id,
      google_email: perfilGoogle.email || null,
      gmail_conectado: gmailConectado,
      calendar_conectado: calendarConectado,
      refresh_token_cifrado: tokenSeguro?.token_cifrado || existente?.refresh_token_cifrado,
      token_iv: tokenSeguro?.iv || existente?.token_iv,
      estado_conexion: 'activa',
    }, { onConflict: 'usuario_id' })
    if (error) return redirigir('error')
    if (registro.servicio === 'calendar') {
      await cliente.rpc('encolar_eventos_calendar_usuario', {
        p_usuario_id: registro.usuario_id,
      })
    }
    return redirigir('conectado', undefined, registro.servicio)
  } catch {
    return redirigir('error')
  }
})
