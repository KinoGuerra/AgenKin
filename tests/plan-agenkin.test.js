import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const leer = (ruta) => readFileSync(new URL(`../${ruta}`, import.meta.url), 'utf8')
const migracion = leer('supabase/migrations/20260814221113_plan_agenkin_gratuito_sin_vencimiento.sql')
const portal = leer('src/pages/app.js')
const admin = leer('src/pages/admin.js')
const funcionAdmin = leer('supabase/functions/admin-manage-user/index.ts')

describe('plan interno AgenKin', () => {
  it('es gratuito, privado y no vence', () => {
    expect(migracion).toContain("precio = 0")
    expect(migracion).toContain('es_interno = true')
    expect(migracion).toContain('visible_publico = false')
    expect(migracion).toContain("fecha_vencimiento = 'infinity'::timestamptz")
    expect(migracion).toContain('renovacion_automatica = false')
  })

  it('aplica la vigencia ilimitada al asignarlo y no la filtra a otro plan', () => {
    expect(migracion).toContain("when v_plan_destino_interno then 'infinity'::timestamptz")
    expect(migracion).toContain('Definí un vencimiento futuro al salir del plan AgenKin')
    expect(migracion).toContain('El plan AgenKin no tiene vencimiento')
  })

  it('mantiene la acción administrativa cerrada al service role', () => {
    expect(migracion).toContain("set search_path = ''")
    expect(migracion).toContain('from public, anon, authenticated')
    expect(migracion).toContain('to service_role')
  })

  it('muestra la vigencia correcta en ambos portales', () => {
    expect(portal).toContain("suscripcion.es_interno")
    expect(portal).toContain("? 'Sin vencimiento'")
    expect(admin).toContain("usuario.es_interno ? 'Sin vencimiento'")
    expect(funcionAdmin).toContain('planes(nombre,limite_cuentas_gmail,es_interno)')
    expect(funcionAdmin).toContain("select('id,nombre,es_interno')")
  })
})
