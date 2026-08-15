import { errorSeguro, json, manejarPreflight } from '../_shared/http.ts'
import { superadministradorAutenticado } from '../_shared/supabase.ts'

const TAMANO_PAGINA = 20
const ACCIONES = new Set([
  'activar', 'suspender', 'bloquear', 'desbloquear', 'cambiar_plan',
  'extender_prueba', 'cambiar_vencimiento', 'registrar_observacion', 'cancelar_suscripcion',
])

Deno.serve(async (request) => {
  const preflight = manejarPreflight(request)
  if (preflight) return preflight
  try {
    if (request.method !== 'POST') return json({ error: 'Método no permitido' }, 405)
    const { usuario, cliente } = await superadministradorAutenticado(request)
    const body = await request.json()

    if (body.accion === 'listar') {
      const pagina = Math.max(1, Number(body.pagina) || 1)
      const desde = (pagina - 1) * TAMANO_PAGINA
      const termino = String(body.buscar || '').replace(/[,%()]/g, '').trim().slice(0, 80)
      let consulta = cliente
        .from('perfiles')
        .select('id,nombre_completo,email,estado_acceso,ultimo_acceso,suscripciones(plan_id,estado,fecha_vencimiento,planes(nombre,limite_cuentas_gmail,es_interno)),consumos_mensuales(correos_procesados,periodo),conexiones_google(id,gmail_conectado,estado_conexion)', { count: 'exact' })
        .order('fecha_registro', { ascending: false })
        .range(desde, desde + TAMANO_PAGINA - 1)
      if (body.estado) consulta = consulta.eq('estado_acceso', body.estado)
      if (termino) consulta = consulta.or(`email.ilike.%${termino}%,nombre_completo.ilike.%${termino}%`)
      const [usuariosResultado, planesResultado, auditoriaResultado] = await Promise.all([
        consulta,
        cliente.from('planes').select('id,nombre,precio,moneda,limite_cuentas_gmail,es_interno,visible_publico').eq('activo', true).order('nombre'),
        cliente.from('auditoria_administrativa').select('accion,detalle,creado_en,administrador_id').order('creado_en', { ascending: false }).limit(20),
      ])
      if (usuariosResultado.error || planesResultado.error || auditoriaResultado.error) throw new Error('No se pudo consultar la administración')

      const periodo = new Date().toISOString().slice(0, 7)
      const usuarios = (usuariosResultado.data || []).map((perfil) => {
        const suscripcion = Array.isArray(perfil.suscripciones) ? perfil.suscripciones[0] : perfil.suscripciones
        const plan = Array.isArray(suscripcion?.planes) ? suscripcion.planes[0] : suscripcion?.planes
        const consumo = (perfil.consumos_mensuales || []).find((item) => String(item.periodo).startsWith(periodo))
        return {
          id: perfil.id,
          nombre_completo: perfil.nombre_completo,
          email: perfil.email,
          estado_acceso: perfil.estado_acceso,
          ultimo_acceso: perfil.ultimo_acceso,
          plan: plan?.nombre,
          es_interno: Boolean(plan?.es_interno),
          limite_cuentas_gmail: plan?.limite_cuentas_gmail,
          estado_suscripcion: suscripcion?.estado,
          fecha_vencimiento: suscripcion?.fecha_vencimiento,
          correos_procesados: consumo?.correos_procesados || 0,
          cuentas_gmail: (perfil.conexiones_google || []).filter((conexion) =>
            conexion.gmail_conectado && conexion.estado_conexion === 'activa'
          ).length,
        }
      })

      const [metricasResultado, notificacionesResultado] = await Promise.all([
        cliente.rpc('metricas_administrativas'),
        cliente.rpc('metricas_notificaciones_push'),
      ])
      if (metricasResultado.error) {
        throw new Error('No se pudieron cargar las métricas')
      }
      return json({
        usuarios,
        planes: planesResultado.data,
        auditoria: auditoriaResultado.data,
        metricas: {
          ...(metricasResultado.data || {}),
          // Las alertas son contexto operativo: no deben impedir administrar usuarios.
          ...(notificacionesResultado.error ? {} : notificacionesResultado.data || {}),
        },
        paginas: Math.max(1, Math.ceil((usuariosResultado.count || 0) / TAMANO_PAGINA)),
      })
    }

    if (body.accion === 'actualizar_precios') {
      if (!Array.isArray(body.precios) || body.precios.length < 1 || body.precios.length > 10) {
        return json({ error: 'Catálogo de precios inválido' }, 400)
      }
      const precios: Array<{ id: string; precio: number }> = body.precios.map((item: Record<string, unknown>) => ({
        id: String(item?.id || ''),
        precio: Number(item?.precio),
      }))
      const invalido = precios.some((item) =>
        !/^[0-9a-f-]{36}$/i.test(item.id)
        || !Number.isFinite(item.precio)
        || item.precio < 0
        || item.precio > 9999999999.99
      )
      if (invalido || new Set(precios.map(({ id }) => id)).size !== precios.length) {
        return json({ error: 'Precio o plan inválido' }, 400)
      }
      const { error } = await cliente.rpc('actualizar_catalogo_precios', {
        p_administrador_id: usuario.id,
        p_precios: precios,
      })
      if (error) throw new Error('No se pudo actualizar el catálogo de precios')
      return json({ ok: true })
    }

    if (!ACCIONES.has(body.accion)) return json({ error: 'Acción no permitida' }, 400)
    if (!/^[0-9a-f-]{36}$/i.test(body.usuario_id || '')) return json({ error: 'Usuario inválido' }, 400)
    const habilitaAcceso = body.accion === 'activar' || body.accion === 'desbloquear'
    const restringeAcceso = body.accion === 'suspender' || body.accion === 'bloquear'

    if (habilitaAcceso) {
      const { error: errorAuth } = await cliente.auth.admin.updateUserById(body.usuario_id, {
        ban_duration: 'none',
      })
      if (errorAuth) throw new Error('No se pudo habilitar el acceso de autenticación')
    }

    const { error } = await cliente.rpc('aplicar_accion_administrativa', {
      p_administrador_id: usuario.id,
      p_usuario_id: body.usuario_id,
      p_accion: body.accion,
      p_plan_id: body.plan_id || null,
      p_fecha_vencimiento: body.fecha_vencimiento || null,
      p_observacion: String(body.observacion || '').slice(0, 1000) || null,
    })
    if (error) throw new Error('No se pudo aplicar la acción administrativa')

    let advertencia: string | null = null
    if (restringeAcceso) {
      const { error: errorAuth } = await cliente.auth.admin.updateUserById(body.usuario_id, {
        ban_duration: '876000h',
      })
      if (errorAuth) {
        advertencia = 'El acceso a los datos quedó bloqueado, pero no se pudieron revocar las sesiones de Auth.'
      }
    }
    return json({ ok: true, advertencia })
  } catch (error) {
    const accesoDenegado = error instanceof Error
      && (error.message.includes('denegado') || error.message.includes('reforzada'))
    return errorSeguro(
      error,
      accesoDenegado ? 403 : 400,
      accesoDenegado
        ? 'Acceso administrativo denegado. Verificá el segundo factor.'
        : 'No se pudo completar la acción administrativa.',
    )
  }
})
