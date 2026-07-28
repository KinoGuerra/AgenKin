import { FunctionsHttpError } from '@supabase/supabase-js'
import { supabase } from './supabase.js'

export async function invocarFuncion(nombre, body) {
  const { data, error } = await supabase.functions.invoke(nombre, { body })
  if (error) {
    if (error instanceof FunctionsHttpError) {
      let detalle
      try {
        detalle = await error.context.json()
      } catch {
        detalle = null
      }
      if (typeof detalle?.error === 'string') throw new Error(detalle.error.slice(0, 300))
    }
    throw new Error('No pudimos comunicarnos con el servicio. Intentá nuevamente.')
  }
  if (data?.error) throw new Error(data.error)
  return data
}
