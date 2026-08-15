import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const leer = (ruta) => readFileSync(new URL(`../${ruta}`, import.meta.url), 'utf8')
const migracion = leer('supabase/migrations/20260814224954_catalogo_precios_publicos_editable.sql')
const migracionArs = leer('supabase/migrations/20260815003932_forzar_precios_planes_en_ars.sql')
const funcionAdmin = leer('supabase/functions/admin-manage-user/index.ts')
const admin = leer('src/pages/admin.js')
const adminHtml = leer('admin.html')

describe('catálogo público de precios', () => {
  it('expone al visitante solamente planes activos, públicos y no internos', () => {
    expect(migracion).toContain('to anon')
    expect(migracion).toContain('activo and visible_publico and not es_interno')
    expect(migracion).toContain('grant select (')
    expect(migracion).not.toMatch(/grant select on public\.planes to anon/i)
  })

  it('reserva la actualización al service role y audita cada cambio', () => {
    expect(migracion).toContain("set search_path = ''")
    expect(migracion).toContain('public.es_superadministrador(p_administrador_id)')
    expect(migracion).toContain('from public, anon, authenticated')
    expect(migracion).toContain('to service_role')
    expect(migracion).toContain("'actualizar_precios_planes'")
    expect(migracion).toContain('p.es_interno')
  })

  it('mantiene AAL2 en la función administrativa y valida valores', () => {
    expect(funcionAdmin).toContain("body.accion === 'actualizar_precios'")
    expect(funcionAdmin).toContain('item.precio > 9999999999.99')
    expect(funcionAdmin).toContain("cliente.rpc('actualizar_catalogo_precios'")
    expect(funcionAdmin).toContain('superadministradorAutenticado(request)')
  })

  it('administra un único importe canónico en pesos argentinos', () => {
    expect(migracionArs).toContain('planes_moneda_ars_check')
    expect(migracionArs).toContain("moneda = 'ARS'")
    expect(migracionArs).toContain("set search_path = ''")
    expect(migracionArs).toContain('from public, anon, authenticated')
    expect(funcionAdmin).not.toContain('item?.moneda')
    expect(admin).toContain('ARS · Pesos argentinos')
    expect(admin).not.toContain('dataset.moneda')
  })

  it('ofrece edición real desde Administración sin mostrar el plan interno', () => {
    expect(adminHtml).toContain('data-precios-form')
    expect(adminHtml).toContain('data-precios-lista')
    expect(admin).toContain('plan.visible_publico && !plan.es_interno')
    expect(admin).toContain("accion: 'actualizar_precios'")
  })
})
