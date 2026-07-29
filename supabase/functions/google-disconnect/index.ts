import { descifrarToken } from '../_shared/crypto.ts'
import { errorSeguro, json, manejarPreflight } from '../_shared/http.ts'
import { usuarioAutenticado } from '../_shared/supabase.ts'

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    const body = await request.json().catch(() => ({}))
    const servicio = ['gmail', 'calendar', 'todo'].includes(body.servicio)
      ? body.servicio as 'gmail' | 'calendar' | 'todo'
      : null
    if (!servicio) return json({ error: 'Servicio inválido' }, 400)

    const { usuario, cliente } = await usuarioAutenticado(request)
    const { data: conexion } = await cliente
      .from('conexiones_google')
      .select('refresh_token_cifrado,token_iv,gmail_conectado,calendar_conectado')
      .eq('usuario_id', usuario.id)
      .maybeSingle()
    if (!conexion) return json({ ok: true })

    const gmailConectado = servicio === 'gmail' || servicio === 'todo'
      ? false
      : conexion.gmail_conectado
    const calendarConectado = servicio === 'calendar' || servicio === 'todo'
      ? false
      : conexion.calendar_conectado
    const revocarTodo = servicio === 'todo'

    if (revocarTodo && conexion.refresh_token_cifrado && conexion.token_iv) {
      const token = await descifrarToken(conexion.refresh_token_cifrado, conexion.token_iv)
      await fetch('https://oauth2.googleapis.com/revoke', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ token }),
      }).catch(() => null)
    }

    const cambios: Record<string, unknown> = {
      gmail_conectado: gmailConectado,
      calendar_conectado: calendarConectado,
      estado_conexion: gmailConectado || calendarConectado ? 'activa' : 'desconectada',
    }
    if (!gmailConectado) {
      Object.assign(cambios, {
        sincronizacion_automatica: false,
        creacion_automatica_eventos: false,
        gmail_history_id: null,
        gmail_history_objetivo: null,
        gmail_page_token: null,
        sincronizacion_inicial_completa: false,
        proxima_sincronizacion: null,
        error_ultima_sincronizacion: null,
      })
    }
    if (revocarTodo) {
      Object.assign(cambios, {
        google_email: null,
        refresh_token_cifrado: null,
        token_iv: null,
      })
    }

    const { error } = await cliente
      .from('conexiones_google')
      .update(cambios)
      .eq('usuario_id', usuario.id)
    if (error) throw new Error('No se pudo actualizar la conexión')
    if (!calendarConectado) {
      await cliente
        .from('eventos_calendar')
        .update({ estado_google: 'no_conectado', error_google: null })
        .eq('usuario_id', usuario.id)
        .is('google_event_id', null)
    }
    return json({ ok: true, gmail_conectado: gmailConectado, calendar_conectado: calendarConectado })
  } catch (error) {
    return errorSeguro(error, 400, 'No se pudo actualizar la conexión con Google.')
  }
})
