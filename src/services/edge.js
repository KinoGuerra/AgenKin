import { supabase } from './supabase.js'

export async function invocarFuncion(nombre, body) {
  const { data, error } = await supabase.functions.invoke(nombre, { body })
  if (error) throw new Error(error.message || 'La operación no pudo completarse.')
  if (data?.error) throw new Error(data.error)
  return data
}
