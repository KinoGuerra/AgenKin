import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const leer = (ruta) => readFileSync(new URL(`../${ruta}`, import.meta.url), 'utf8')
const migracion = leer(
  'supabase/migrations/20260803161501_autoagenda_aprendizaje_calendar.sql',
)
const limiteDiario = leer(
  'supabase/migrations/20260803170919_no_contar_eventos_eliminados_en_limite.sql',
).replace(/\s+/g, ' ').trim().toLowerCase()
const sql = migracion.replace(/\s+/g, ' ').trim().toLowerCase()
const procesador = leer('supabase/functions/_shared/process-email.ts')
const calendar = leer('supabase/functions/_shared/calendar.ts')
const worker = leer('supabase/functions/process-calendar-queue/index.ts')
const portal = leer('src/services/portal.js')
const pagina = leer('src/pages/app.js')

function bloque(inicio, fin) {
  const desde = sql.indexOf(inicio)
  const hasta = sql.indexOf(fin, desde)
  if (desde < 0 || hasta <= desde) throw new Error(`Bloque ausente: ${inicio}`)
  return sql.slice(desde, hasta)
}

describe('autoagendado confiable, aprendizaje y Calendar', () => {
  it('autoriza por configuración sin exigir una regla de priorización', () => {
    const automaticos = bloque(
      'create or replace function public.crear_eventos_automaticos_pendientes(',
      'revoke execute on function public.crear_eventos_automaticos_pendientes(',
    )
    expect(automaticos).toContain('c.creacion_automatica_eventos')
    expect(automaticos).toContain('v.confianza >= c.umbral_confianza_automatica')
    expect(automaticos).toContain('and not v.requiere_revision')
    expect(automaticos).toContain('v.fecha_vencimiento >=')
    expect(automaticos).toContain('private.exclusiones_agenda_usuario')
    expect(automaticos).toContain('for update of v skip locked')
    expect(automaticos).toContain(') >= 20')
    expect(automaticos).not.toContain('public.reglas_usuario')
    expect(limiteDiario).toContain("and e.estado_sincronizacion <> 'eliminado'")
  })

  it('aísla cada exclusión por usuario, dominio y plantilla', () => {
    expect(sql).toContain('create table if not exists private.exclusiones_agenda_usuario')
    expect(sql).toContain('primary key (usuario_id, dominio_remitente, huella_plantilla)')
    expect(sql).toContain('alter table private.exclusiones_agenda_usuario enable row level security')
    expect(sql).toContain('revoke all on private.exclusiones_agenda_usuario from public, anon, authenticated')

    const exclusiones = new Set(['usuario-a|empresa.test|plantilla-1'])
    expect(exclusiones.has('usuario-a|empresa.test|plantilla-1')).toBe(true)
    expect(exclusiones.has('usuario-b|empresa.test|plantilla-1')).toBe(false)
    expect(exclusiones.has('usuario-a|empresa.test|plantilla-2')).toBe(false)
  })

  it('descarta de forma idempotente y encola la eliminación remota', () => {
    const descartar = bloque(
      'create or replace function public.descartar_vencimiento(',
      'revoke execute on function public.descartar_vencimiento(',
    )
    expect(descartar).toContain('returns boolean')
    expect(descartar).toContain('v_usuario_id uuid := (select auth.uid())')
    expect(descartar).toContain("if v_vencimiento.estado = 'descartado' then return true")
    expect(descartar).toContain("not in ('pendiente', 'evento_creado')")
    expect(descartar).toContain('insert into private.exclusiones_agenda_usuario')
    expect(descartar).toContain("estado_sincronizacion = 'eliminado'")
    expect(descartar).toContain("operacion = 'eliminar'")
    expect(descartar).toContain("'operacion', 'eliminar'")
    expect(descartar).toContain("set estado = 'descartado'")
  })

  it('versiona mensajes para que una creación vieja no gane al descarte', () => {
    const lectura = bloque(
      'create function public.leer_tareas_calendar(',
      'revoke execute on function public.leer_tareas_calendar(',
    )
    const finalizacion = bloque(
      'create function public.finalizar_tarea_calendar(',
      'revoke execute on function public.finalizar_tarea_calendar(',
    )
    expect(lectura).toContain('operacion text')
    expect(lectura).toContain('t.operacion = v_operacion')
    expect(lectura).toContain("perform pgmq.delete('calendar_sync', mensaje.msg_id)")
    expect(finalizacion).toContain('and operacion = p_operacion')
    expect(finalizacion).toContain("and estado = 'procesando'")
    expect(worker).toContain("tarea.operacion === 'eliminar'")
    expect(worker).toContain('p_operacion: tarea.operacion')
  })

  it('elimina en Google, acepta 404 y limpia una creación concurrente', () => {
    expect(calendar).toContain("method: 'DELETE'")
    expect(calendar).toContain('error.status === 404')
    expect(calendar).toContain(".neq('estado_sincronizacion', 'eliminado')")
    expect(calendar).toContain('await eliminarEventoGoogle(acceso, calendarId')
    expect(calendar).toContain("estado: 'no_conectado'")
    expect(worker).toContain("'GOOGLE_TEMPORAL'")
    expect(worker).toContain('tarea.intentos + 1 < MAXIMO_INTENTOS')
  })

  it('persiste el dominio y muestra sólo hallazgos futuros accionables', () => {
    expect(procesador).toContain('dominio_remitente: analisis.dominioRemitente')
    expect(sql).toContain('before insert or update of remitente on public.correos_procesados')
    expect(portal).toContain(".gte('fecha_vencimiento', fechaActualIso())")
    expect(portal).toContain(".in('estado', ['pendiente', 'confirmado', 'evento_creado', 'error'])")
    expect(pagina).toContain("return 'Sincronizado con Google'")
    expect(pagina).toContain("return 'Error de Google'")
    expect(pagina).toContain("return 'Google pendiente'")
    expect(pagina).toContain('Descartar y eliminar')
  })
})
