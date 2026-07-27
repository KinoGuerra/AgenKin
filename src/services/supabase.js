import { createClient } from '@supabase/supabase-js'
import { env, validarConfiguracionPublica } from '../config/env.js'

const errores = validarConfiguracionPublica()
if (errores.length) throw new Error(errores.join(' '))

export const supabase = createClient(env.supabaseUrl, env.supabaseKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
})
