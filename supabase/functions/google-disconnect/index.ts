import { descifrarToken } from '../_shared/crypto.ts'
import { fetchGoogle } from '../_shared/google.ts'
import { errorSeguro, json, manejarPreflight } from '../_shared/http.ts'
import { usuarioAutenticado } from '../_shared/supabase.ts'

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    const body = await request.json().catch(() => ({}))
    const servicio = ['gmail', 'calendar', 'todo'].includes(body.servicio)
      ? body.servicio as 'gmail' | 'calendar' | 'todo'
      : null
    const conexionId = UUID.test(String(body.conexion_id || ''))
      ? String(body.conexion_id)
      : null
    if (!servicio || !conexionId) {
      return json({ error: 'Servicio o cuenta inválida' }, 400)
    }

    const { usuario, cliente } = await usuarioAutenticado(request)
    const { data: conexion, error: errorConexion } = await cliente
      .from('conexiones_google')
      .select('id,refresh_token_cifrado,token_iv,gmail_conectado,calendar_conectado,es_calendar_principal')
      .eq('id', conexionId)
      .eq('usuario_id', usuario.id)
      .maybeSingle()
    if (errorConexion) throw errorConexion
    if (!conexion) return json({ ok: true })

    if (
      servicio === 'gmail'
      && conexion.calendar_conectado
      && conexion.es_calendar_principal
    ) {
      return json({
        error: 'Esta cuenta se usa para Calendar. Elegí otra o confirmá la desconexión de ambos servicios.',
        codigo: 'GMAIL_USADA_POR_CALENDAR',
      }, 409)
    }

    let revocacionConfirmada: boolean | null = null
    if (
      servicio === 'todo'
      && conexion.refresh_token_cifrado
      && conexion.token_iv
    ) {
      const token = await descifrarToken(
        conexion.refresh_token_cifrado,
        conexion.token_iv,
      )
      try {
        const respuesta = await fetchGoogle('https://oauth2.googleapis.com/revoke', {
          method: 'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body: new URLSearchParams({ token }),
        })
        revocacionConfirmada = respuesta.ok || respuesta.status === 400
      } catch {
        revocacionConfirmada = false
      }
    }

    const desactivaGmail = servicio === 'gmail' || servicio === 'todo'
    const desactivaCalendar = servicio === 'calendar' || servicio === 'todo'
    const gmailConectado = desactivaGmail ? false : conexion.gmail_conectado
    const calendarConectado = desactivaCalendar
      ? false
      : conexion.calendar_conectado
    const cambios: Record<string, unknown> = {
      gmail_conectado: gmailConectado,
      calendar_conectado: calendarConectado,
      es_calendar_principal: calendarConectado
        ? conexion.es_calendar_principal
        : false,
      estado_conexion: gmailConectado || calendarConectado
        ? 'activa'
        : 'desconectada',
    }
    if (desactivaGmail) {
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
    if (desactivaCalendar) cambios.calendar_id = null
    if (!gmailConectado && !calendarConectado) {
      Object.assign(cambios, {
        refresh_token_cifrado: null,
        token_iv: null,
      })
    }

    const { error } = await cliente
      .from('conexiones_google')
      .update(cambios)
      .eq('id', conexion.id)
      .eq('usuario_id', usuario.id)
    if (error) throw new Error('No se pudo actualizar la conexión')

    if (desactivaGmail) {
      await cliente
        .from('tareas_correos_gmail')
        .update({
          estado: 'error',
          ultimo_error: 'CONEXION_DESCONECTADA',
          reclamada_en: null,
        })
        .eq('conexion_google_id', conexion.id)
        .in('estado', ['pendiente', 'procesando'])
    }
    if (desactivaCalendar) {
      await cliente
        .from('eventos_calendar')
        .update({
          conexion_google_id: null,
          estado_google: 'no_conectado',
          error_google: null,
        })
        .eq('usuario_id', usuario.id)
        .eq('conexion_google_id', conexion.id)
        .is('google_event_id', null)
    }

    return json({
      ok: true,
      conexion_id: conexion.id,
      gmail_conectado: gmailConectado,
      calendar_conectado: calendarConectado,
      revocacion_google: revocacionConfirmada === null
        ? null
        : revocacionConfirmada
          ? 'confirmada'
          : 'no_confirmada',
    })
  } catch (error) {
    return errorSeguro(error, 400, 'No se pudo actualizar la conexión con Google.')
  }
})
