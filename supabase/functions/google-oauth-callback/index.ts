import { cifrarToken, hashEstado } from '../_shared/crypto.ts'
import { asegurarCalendarioVisible } from '../_shared/calendar.ts'
import { fetchGoogle } from '../_shared/google.ts'
import { appUrlSegura, envRequerida } from '../_shared/http.ts'
import { clienteServicio } from '../_shared/supabase.ts'

type Motivo =
  | 'cupo_cuentas_gmail'
  | 'cuenta_calendar_distinta'
  | 'cuenta_google_distinta'

function redirigir(
  estado: 'conectado' | 'error',
  motivo?: Motivo,
  servicio?: 'gmail' | 'calendar',
) {
  const app = appUrlSegura()
  app.pathname += 'app.html'
  app.searchParams.set('google', estado)
  if (motivo) app.searchParams.set('motivo', motivo)
  if (servicio) app.searchParams.set('servicio', servicio)
  return new Response(null, {
    status: 302,
    headers: {
      Location: app.href,
      'Cache-Control': 'no-store',
      Pragma: 'no-cache',
    },
  })
}

Deno.serve(async (request) => {
  try {
    const {
      GOOGLE_CLIENT_ID,
      GOOGLE_CLIENT_SECRET,
      GOOGLE_REDIRECT_URI,
    } = envRequerida(
      'GOOGLE_CLIENT_ID',
      'GOOGLE_CLIENT_SECRET',
      'GOOGLE_REDIRECT_URI',
      'TOKEN_ENCRYPTION_KEY',
      'APP_PUBLIC_URL',
    )
    const url = new URL(request.url)
    const codigo = url.searchParams.get('code')
    const estado = url.searchParams.get('state')
    if (!codigo || !estado || url.searchParams.has('error')) {
      return redirigir('error')
    }

    const cliente = clienteServicio()
    const hash = await hashEstado(estado)
    const ahora = new Date().toISOString()
    const { data: registro } = await cliente
      .from('oauth_states')
      .update({ usado_en: ahora })
      .eq('hash_estado', hash)
      .is('usado_en', null)
      .gt('vence_en', ahora)
      .select('usuario_id,servicio,conexion_google_id')
      .maybeSingle()
    if (!registro) return redirigir('error')
    const { data: habilitado } = await cliente.rpc('usuario_habilitado', {
      usuario: registro.usuario_id,
    })
    if (!habilitado) return redirigir('error')

    const respuestaToken = await fetchGoogle('https://oauth2.googleapis.com/token', {
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
    const respuestaPerfil = await fetchGoogle(
      'https://openidconnect.googleapis.com/v1/userinfo',
      { headers: { Authorization: `Bearer ${tokens.access_token}` } },
    )
    const perfilGoogle = await respuestaPerfil.json()
    if (
      !respuestaPerfil.ok
      || !perfilGoogle.sub
      || !perfilGoogle.email
      || perfilGoogle.email_verified !== true
    ) {
      return redirigir('error')
    }

    const { data: existentePorSubject } = await cliente
      .from('conexiones_google')
      .select('id,refresh_token_cifrado,token_iv')
      .eq('usuario_id', registro.usuario_id)
      .eq('google_subject_id', perfilGoogle.sub)
      .maybeSingle()
    let existente = existentePorSubject
    if (!existente) {
      const { data: heredada } = await cliente
        .from('conexiones_google')
        .select('id,refresh_token_cifrado,token_iv')
        .eq('usuario_id', registro.usuario_id)
        .like('google_subject_id', 'legacy:%')
        .eq('google_email', String(perfilGoogle.email).toLowerCase())
        .maybeSingle()
      existente = heredada
    }
    const tokenSeguro = tokens.refresh_token
      ? await cifrarToken(tokens.refresh_token)
      : null
    if (!tokenSeguro && !existente?.refresh_token_cifrado) {
      return redirigir('error')
    }

    const permisos = new Set(String(tokens.scope || '').split(/\s+/))
    const permisosSolicitados = registro.servicio === 'gmail'
      ? ['https://www.googleapis.com/auth/gmail.readonly']
      : [
          'https://www.googleapis.com/auth/calendar.app.created',
          'https://www.googleapis.com/auth/calendar.calendarlist',
        ]
    if (permisosSolicitados.some((permiso) => !permisos.has(permiso))) {
      return redirigir('error')
    }

    const { error } = await cliente.rpc('registrar_conexion_google_oauth', {
      p_usuario_id: registro.usuario_id,
      p_servicio: registro.servicio,
      p_google_subject_id: perfilGoogle.sub,
      p_google_email: perfilGoogle.email,
      p_conexion_id: registro.conexion_google_id,
      p_refresh_token_cifrado: tokenSeguro?.token_cifrado || null,
      p_token_iv: tokenSeguro?.iv || null,
    })
    if (error) {
      if (error.message?.includes('CUPO_CUENTAS_GMAIL')) {
        return redirigir('error', 'cupo_cuentas_gmail', registro.servicio)
      }
      if (error.message?.includes('CUENTA_CALENDAR_DISTINTA')) {
        return redirigir('error', 'cuenta_calendar_distinta', registro.servicio)
      }
      return redirigir('error')
    }

    if (registro.servicio === 'calendar') {
      const { data: conexionCalendar, error: errorConexionCalendar } = await cliente
        .from('conexiones_google')
        .select('calendar_id')
        .eq('usuario_id', registro.usuario_id)
        .eq('es_calendar_principal', true)
        .eq('calendar_conectado', true)
        .eq('estado_conexion', 'activa')
        .maybeSingle()
      if (errorConexionCalendar) return redirigir('error')
      if (conexionCalendar?.calendar_id) {
        await asegurarCalendarioVisible(tokens.access_token, conexionCalendar.calendar_id)
      }
      await cliente.rpc('encolar_eventos_calendar_usuario', {
        p_usuario_id: registro.usuario_id,
      })
    }
    return redirigir('conectado', undefined, registro.servicio)
  } catch {
    return redirigir('error')
  }
})
