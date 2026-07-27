import { createClient } from 'npm:@supabase/supabase-js@2'
import { envRequerida } from './http.ts'

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
  return { usuario: data.user, cliente }
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
  return { ...contexto, perfil }
}
