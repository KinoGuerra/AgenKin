import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const leer = (ruta) => readFileSync(new URL(`../${ruta}`, import.meta.url), 'utf8')
const migracion = leer(
  'supabase/migrations/20260803182509_recuperar_gmail_controlar_ia_calendar.sql',
).replace(/\s+/g, ' ').trim().toLowerCase()
const gmail = leer('supabase/functions/_shared/gmail-sync.ts')
const proceso = leer('supabase/functions/_shared/process-email.ts')
const ia = leer('supabase/functions/_shared/ai.ts')

describe('recuperación Gmail y presupuesto diario de IA', () => {
  it('no reactiva errores terminales ni cuenta duplicados como capacidad nueva', () => {
    const registro = migracion.slice(
      migracion.indexOf('create function public.registrar_tareas_correos_gmail('),
      migracion.indexOf('revoke execute on function public.registrar_tareas_correos_gmail('),
    )
    expect(registro).toContain('where not exists')
    expect(registro).toContain('if coalesce(cardinality(v_nuevas), 0) = 0 then return 0')
    expect(registro).toContain('on conflict (conexion_google_id, gmail_message_id) do nothing')
    expect(registro).not.toContain("where public.tareas_correos_gmail.estado = 'error'")
  })

  it('prioriza incremental y reconciliación sobre el atraso', () => {
    expect(migracion).toContain("case when t.origen_sincronizacion = 'historica' then 1 else 0 end")
    expect(migracion).toContain('for update of t skip locked')
    expect(migracion).toContain('tareas_gmail_disponibles_idx')
  })

  it('aplica los topes elegidos de forma atómica y privada', () => {
    expect(migracion).toContain('create table if not exists private.consumo_ia_diario')
    expect(migracion).toContain("pg_catalog.hashtext('agenkin_presupuesto_ia')")
    expect(migracion).toContain('p_max_solicitudes integer default 300')
    expect(migracion).toContain('p_max_tokens bigint default 80000')
    expect(migracion).toContain('p_max_historicas integer default 20')
    expect(migracion).toContain('grant execute on function public.reservar_presupuesto_ia')
    expect(migracion).toContain('to service_role')
    expect(proceso).toContain("enteroEntorno('AI_MAX_SOLICITUDES_DIA', 300)")
    expect(ia).toContain('const MAXIMO_INTENTOS = 1')
  })

  it('pagina una reparación diaria de siete días sin alterar History', () => {
    expect(gmail).toContain('RESULTADOS_RECONCILIACION = 100')
    expect(gmail).toContain('DIAS_RECONCILIACION = 7')
    expect(gmail).toContain('gmail_reconciliacion_page_token')
    expect(gmail).toContain("registrarTareas(cliente, conexion, ids, 'reconciliacion')")
    expect(gmail).toContain("registrarTareas(cliente, conexion, ids, 'incremental')")
    expect(gmail).toContain("registrarTareas(cliente, conexion, ids, 'historica')")
  })

  it('cierra respuestas inválidas y sólo rescata límites recientes', () => {
    expect(migracion).toContain("t.ultimo_error = 'ai_limite_temporal'")
    expect(migracion).toContain("cp.fecha_correo >= now() - interval '7 days'")
    expect(migracion).toContain("ultimo_error = 'ai_respuesta_invalida'")
    expect(migracion).toContain('intentos_ia = 2')
  })
})
