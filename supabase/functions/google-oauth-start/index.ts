import { hashEstado } from '../_shared/crypto.ts'
import { envRequerida, errorSeguro, json, manejarPreflight } from '../_shared/http.ts'
import { usuarioAutenticado } from '../_shared/supabase.ts'

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    const body = await request.json().catch(() => ({}))
    const servicio = body.servicio === 'gmail' || body.servicio === 'calendar'
      ? body.servicio
      : null
    if (!servicio) return json({ error: 'Elegí Gmail o Calendar' }, 400)
    const { GOOGLE_CLIENT_ID, GOOGLE_REDIRECT_URI } = envRequerida('GOOGLE_CLIENT_ID', 'GOOGLE_REDIRECT_URI')
    const redirect = new URL(GOOGLE_REDIRECT_URI)
    if (redirect.protocol !== 'https:' && redirect.hostname !== 'localhost') throw new Error('GOOGLE_REDIRECT_URI no es segura')
    const { usuario, cliente } = await usuarioAutenticado(request)
    const { data: conexion } = await cliente
      .from('conexiones_google')
      .select('google_email')
      .eq('usuario_id', usuario.id)
      .maybeSingle()
    const estado = crypto.randomUUID() + crypto.randomUUID()
    const { error } = await cliente.from('oauth_states').insert({
      hash_estado: await hashEstado(estado),
      usuario_id: usuario.id,
      servicio,
      vence_en: new Date(Date.now() + 10 * 60 * 1000).toISOString(),
    })
    if (error) throw new Error('No se pudo iniciar la autorización')
    const url = new URL('https://accounts.google.com/o/oauth2/v2/auth')
    url.search = new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      redirect_uri: GOOGLE_REDIRECT_URI,
      response_type: 'code',
      access_type: 'offline',
      prompt: 'consent select_account',
      include_granted_scopes: 'true',
      state: estado,
      scope: [
        'openid',
        'email',
        servicio === 'gmail'
          ? 'https://www.googleapis.com/auth/gmail.readonly'
          : 'https://www.googleapis.com/auth/calendar.app.created',
      ].join(' '),
    }).toString()
    if (conexion?.google_email) url.searchParams.set('login_hint', conexion.google_email)
    return json({ url: url.href })
  } catch (error) {
    return errorSeguro(error, 400)
  }
})
