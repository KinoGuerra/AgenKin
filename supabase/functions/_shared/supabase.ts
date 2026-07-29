import { createClient } from 'npm:@supabase/supabase-js@2.110.9'
import { envRequerida } from './http.ts'

function nivelAutenticacion(token: string) {
  try {
    const segmento = token.split('.')[1]
    const base64 = segmento.replace(/-/g, '+').replace(/_/g, '/')
      .padEnd(Math.ceil(segmento.length / 4) * 4, '=')
    const claims = JSON.parse(atob(base64))
    return claims?.aal === 'aal2' ? 'aal2' : 'aal1'
  } catch {
    return 'aal1'
  }
}

export function clienteServicio() {
  const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = envRequerida('SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY')
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
}

export async function usuarioAutenticado(request: Request) {
  const autorizacion = request.headers.get('Authorization')
  if (!autorizacion?.startsWith('Bearer ')) throw new Error('Sesión requerida')
  const token = autorizacion.slice(7)
  const cliente = clienteServicio()
  const { data, error } = await cliente.auth.getUser(token)
  if (error || !data.user) throw new Error('Sesión inválida o vencida')
  return { usuario: data.user, cliente, token, nivelAutenticacion: nivelAutenticacion(token) }
}

export async function superadministradorAutenticado(request: Request) {
  const contexto = await usuarioAutenticado(request)
  const { data: perfil, error } = await contexto.cliente
    .from('perfiles')
    .select('id,rol,estado_acceso,email')
    .eq('id', contexto.usuario.id)
    .single()
  if (error || perfil?.rol !== 'superadministrador' || perfil.estado_acceso !== 'activo') {
    throw new Error('Acceso administrativo denegado')
  }
  if (contexto.nivelAutenticacion !== 'aal2') {
    throw new Error('Autenticación reforzada requerida')
  }
  return { ...contexto, perfil }
}
