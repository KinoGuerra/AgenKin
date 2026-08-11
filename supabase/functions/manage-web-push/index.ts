import { cifrarToken } from '../_shared/crypto.ts'
import { errorSeguro, json, manejarPreflight } from '../_shared/http.ts'
import { usuarioAutenticado } from '../_shared/supabase.ts'
import { hashEndpointPush, validarSuscripcionPush } from '../_shared/web-push.ts'

async function contextoHabilitado(request: Request) {
  const contexto = await usuarioAutenticado(request)
  const { data: perfil, error } = await contexto.cliente
    .from('perfiles')
    .select('estado_acceso,recibir_notificaciones,notificar_dia_previo,notificar_dia_vencimiento')
    .eq('id', contexto.usuario.id)
    .single()
  if (error || perfil?.estado_acceso !== 'activo') {
    throw new Error('CUENTA_NO_HABILITADA')
  }
  return { ...contexto, perfil }
}

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    if (request.method !== 'POST') {
      return json({ error: 'Método no permitido' }, 405)
    }
    const { usuario, cliente, perfil } = await contextoHabilitado(request)
    const body = await request.json().catch(() => ({}))
    const accion = String(body.accion || 'estado')

    if (accion === 'estado') {
      const { data, error } = await cliente.rpc(
        'cantidad_suscripciones_push_usuario',
        {
          p_usuario_id: usuario.id,
        },
      )
      if (error) throw error
      const clavePublica = Deno.env.get('VAPID_PUBLIC_KEY')?.trim() || null
      const disponible = Boolean(
        clavePublica &&
          Deno.env.get('VAPID_PRIVATE_KEY')?.trim() &&
          Deno.env.get('VAPID_SUBJECT')?.trim(),
      )
      return json({
        disponible,
        vapid_public_key: disponible ? clavePublica : null,
        suscripciones_activas: Number(data || 0),
      })
    }

    if (accion === 'desuscribir_todas') {
      const { error } = await cliente.rpc(
        'desactivar_suscripciones_push_usuario',
        {
          p_usuario_id: usuario.id,
          p_motivo: 'usuario',
        },
      )
      if (error) throw error
      return json({ ok: true })
    }

    const suscripcion = validarSuscripcionPush(body.suscripcion)
    const endpointHash = await hashEndpointPush(suscripcion.endpoint)
    if (accion === 'desuscribir') {
      const { error } = await cliente.rpc('desactivar_suscripcion_push_web', {
        p_usuario_id: usuario.id,
        p_endpoint_hash: endpointHash,
        p_motivo: 'usuario',
      })
      if (error) throw error
      return json({ ok: true })
    }
    if (accion !== 'suscribir') {
      return json({ error: 'Acción no permitida' }, 400)
    }
    if (
      !perfil.recibir_notificaciones ||
      (!perfil.notificar_dia_previo && !perfil.notificar_dia_vencimiento)
    ) {
      return json(
        { error: 'Primero activá las notificaciones y al menos un momento de aviso.' },
        409,
      )
    }

    const cifrado = await cifrarToken(JSON.stringify(suscripcion))
    const { error } = await cliente.rpc('registrar_suscripcion_push_web', {
      p_usuario_id: usuario.id,
      p_endpoint_hash: endpointHash,
      p_datos_cifrados: cifrado.token_cifrado,
      p_iv: cifrado.iv,
    })
    if (error) {
      if (String(error.message).includes('SUSCRIPCION_OTRO_USUARIO')) {
        return json({
          error: 'Este dispositivo conserva una suscripción de otra cuenta. Desactivala y volvé a intentarlo.',
          codigo: 'SUSCRIPCION_OTRO_USUARIO',
        }, 409)
      }
      throw error
    }
    return json({ ok: true })
  } catch (error) {
    return errorSeguro(error, 400, 'No se pudo configurar este dispositivo.')
  }
})
