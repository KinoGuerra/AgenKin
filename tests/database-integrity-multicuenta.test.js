import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'

const migracion = readFileSync(
  new URL(
    '../supabase/migrations/20260730003317_sincronizacion_multicuenta_free.sql',
    import.meta.url,
  ),
  'utf8',
)

const sql = migracion.replace(/\s+/g, ' ').trim().toLowerCase()
const reanudacion = readFileSync(
  new URL(
    '../supabase/migrations/20260730012100_reanudar_workers_multicuenta.sql',
    import.meta.url,
  ),
  'utf8',
).replace(/\s+/g, ' ').trim().toLowerCase()
const verificacion = readFileSync(
  new URL(
    '../supabase/migrations/20260730013500_verificar_seguridad_multicuenta.sql',
    import.meta.url,
  ),
  'utf8',
).replace(/\s+/g, ' ').trim().toLowerCase()

function extraerBloque(inicio, fin) {
  const posicionInicio = sql.indexOf(inicio)
  const posicionFin = sql.indexOf(fin, posicionInicio)

  if (posicionInicio < 0 || posicionFin <= posicionInicio) {
    throw new Error(`No se encontró el bloque SQL entre "${inicio}" y "${fin}".`)
  }

  return sql.slice(posicionInicio, posicionFin)
}

describe('integridad y seguridad de la migración multicuenta', () => {
  it('revoca privilegios públicos implícitos y TRUNCATE presente y futuro', () => {
    const revocaTruncateActual =
      sql.includes(
        'revoke truncate on all tables in schema public from public, anon, authenticated',
      )
      || sql.includes(
        'revoke all on all tables in schema public from public, anon, authenticated',
      )
    const revocaTruncateFuturo =
      /alter default privileges(?: for role \w+)? in schema public revoke (?:truncate|all) on tables from public, anon, authenticated/
        .test(sql)

    expect(revocaTruncateActual).toBe(true)
    expect(revocaTruncateFuturo).toBe(true)
    expect(sql).toContain(
      'revoke execute on all functions in schema public from public, anon, authenticated',
    )
    expect(sql).toMatch(
      /alter default privileges(?: for role \w+)? in schema public revoke execute on functions from public, anon, authenticated/,
    )
  })

  it('cobra cupo al agregar o reactivar Gmail, pero no al refrescar una cuenta activa', () => {
    const registrar = extraerBloque(
      'create or replace function public.registrar_conexion_google_oauth(',
      'revoke execute on function public.registrar_conexion_google_oauth(',
    )

    expect(registrar).toContain('for update of s')
    expect(registrar).toContain(
      "and (conexion.id is null or id <> conexion.id)",
    )
    expect(registrar).toMatch(
      /if \( conexion\.id is null or not \( conexion\.gmail_conectado and conexion\.estado_conexion = 'activa' \) \) and usadas >= limite then/,
    )
    expect(registrar).toContain("raise exception 'cupo_cuentas_gmail'")

    const excedeCupo = ({ existe, activa, usadas, limite }) =>
      (!existe || !activa) && usadas >= limite

    expect(excedeCupo({
      existe: false,
      activa: false,
      usadas: 1,
      limite: 1,
    })).toBe(true)
    expect(excedeCupo({
      existe: true,
      activa: false,
      usadas: 1,
      limite: 1,
    })).toBe(true)
    expect(excedeCupo({
      existe: true,
      activa: true,
      usadas: 1,
      limite: 1,
    })).toBe(false)
  })

  it('impide asociar recursos de un usuario con la conexión de otro', () => {
    expect(sql).toContain(
      'create unique index if not exists conexiones_google_id_usuario_uidx on public.conexiones_google (id, usuario_id)',
    )

    const relaciones = [
      ['correos_conexion_usuario_fkey', 'correos_procesados', true],
      ['tareas_gmail_conexion_usuario_fkey', 'tareas_correos_gmail', true],
      ['eventos_conexion_usuario_fkey', 'eventos_calendar', false],
      ['oauth_states_conexion_usuario_fkey', 'oauth_states', true],
    ]

    for (const [restriccion, tabla, cascada] of relaciones) {
      const patron = [
        `alter table public.${tabla}`,
        `add constraint ${restriccion}`,
        'foreign key (conexion_google_id, usuario_id)',
        'references public.conexiones_google(id, usuario_id)',
      ].join(' ')

      expect(sql).toContain(patron)
      if (cascada) {
        expect(sql.slice(sql.indexOf(patron), sql.indexOf(patron) + 320))
          .toContain('on delete cascade')
      }
    }

    expect(sql).toContain(
      "raise exception 'migracion_abortada_asociacion_de_otro_usuario'",
    )
    expect(sql).toContain('add constraint vencimientos_correo_usuario_fkey')
    expect(sql).toContain('add constraint eventos_vencimiento_usuario_fkey')
    expect(sql).toContain('add constraint tareas_calendar_evento_usuario_fkey')
  })

  it('expone un descarte autenticado, propio y sólo desde estado pendiente', () => {
    const descartar = extraerBloque(
      'create or replace function public.descartar_vencimiento(',
      'revoke execute on function public.descartar_vencimiento(',
    )
    const permisos = sql.slice(
      sql.indexOf('revoke execute on function public.descartar_vencimiento('),
      sql.indexOf('revoke execute on function public.descartar_vencimiento(')
        + 500,
    )

    expect(descartar).toContain('p_vencimiento_id uuid')
    expect(descartar).toContain('returns boolean')
    expect(descartar).toContain('security definer')
    expect(descartar).toContain("set search_path = ''")
    expect(descartar).toContain('private.usuario_habilitado()')
    expect(descartar).toMatch(
      /usuario_id\s*=\s*\(select auth\.uid\(\)\)/,
    )
    expect(descartar).toContain("if v_estado <> 'pendiente' then")
    expect(descartar).toContain("set estado = 'descartado'")
    expect(permisos).toContain('from public, anon')
    expect(permisos).toContain('to authenticated')
  })

  it('finaliza correo, vencimiento, métricas y tarea en una única RPC idempotente', () => {
    const finalizar = extraerBloque(
      'create or replace function public.finalizar_correo_analizado(',
      'revoke execute on function public.finalizar_correo_analizado(',
    )
    const permisos = sql.slice(
      sql.indexOf('revoke execute on function public.finalizar_correo_analizado('),
      sql.indexOf('revoke execute on function public.finalizar_correo_analizado(')
        + 520,
    )

    expect(finalizar).toContain('returns boolean')
    expect(finalizar).toContain('security definer')
    expect(finalizar).toContain('for share')
    expect(finalizar.match(/for update/g)?.length ?? 0).toBeGreaterThanOrEqual(2)
    expect(finalizar).toContain("v_tarea.estado <> 'procesando'")
    expect(finalizar).toContain(
      'cp.gmail_message_id = v_tarea.gmail_message_id',
    )
    expect(finalizar).toContain('update public.correos_procesados')
    expect(finalizar).toContain(
      'estado_procesamiento = v_estado::public.estado_procesamiento',
    )
    expect(finalizar).toContain('insert into public.vencimientos_detectados')
    expect(finalizar).toContain('on conflict (correo_id) do update')
    expect(finalizar).toContain(
      'if v_correo.metricas_registradas_en is null then',
    )
    expect(finalizar).toContain('perform public.registrar_consumo_correo(')
    expect(finalizar).toContain('set metricas_registradas_en = now()')
    expect(finalizar).toContain('update public.tareas_correos_gmail')
    expect(finalizar).toContain("estado = 'completada'")
    expect(finalizar).toContain('return true')
    expect(permisos).toContain('from public, anon, authenticated')
    expect(permisos).toContain('to service_role')
  })

  it('pausa workers Edge durante el cambio de esquema y no los reprograma aún', () => {
    const workers = [
      'agenkin-crear-eventos',
      'agenkin-descubrir-gmail',
      'agenkin-limpiar-oauth-states',
      'agenkin-procesar-calendar',
      'agenkin-procesar-gmail',
    ]

    expect(sql).toContain('perform cron.unschedule(trabajo.jobid)')
    for (const worker of workers) {
      expect(sql).toContain(`'${worker}'`)
    }

    const trabajosProgramados = [
      ...sql.matchAll(/perform cron\.schedule\( '([^']+)'/g),
    ].map((coincidencia) => coincidencia[1])

    expect(trabajosProgramados).toEqual(['agenkin-mantenimiento-diario'])
    expect(sql).not.toContain('net.http_post(')
  })

  it('reanuda solamente cuatro workers globales con secretos de Vault', () => {
    const workers = [
      'agenkin-descubrir-gmail',
      'agenkin-procesar-gmail',
      'agenkin-crear-eventos',
      'agenkin-procesar-calendar',
    ]

    expect(reanudacion).toContain("where name = 'agenkin_project_url'")
    expect(reanudacion).toContain("where name = 'agenkin_cron_secret'")
    expect(reanudacion).toContain('timeout_milliseconds := 125000')
    expect(reanudacion.match(/perform cron\.schedule\(/g)).toHaveLength(4)
    for (const worker of workers) {
      expect(reanudacion).toContain(`'${worker}'`)
    }
    expect(reanudacion).not.toContain("'agenkin-limpiar-oauth-states'")
  })

  it('incluye una puerta remota para RLS, privilegios, tenant y cron', () => {
    expect(verificacion).toContain('c.relrowsecurity')
    expect(verificacion).toContain(
      "has_table_privilege('anon', relacion, privilegio)",
    )
    expect(verificacion).toContain(
      "has_table_privilege('authenticated', relacion, 'update')",
    )
    expect(verificacion).toContain(
      "has_function_privilege('anon', funcion.oid, 'execute')",
    )
    expect(verificacion).toContain(
      'cuentas.total > plan.limite_cuentas_gmail',
    )
    expect(verificacion).toContain(
      "raise exception 'se detectaron asociaciones cruzadas entre usuarios'",
    )
    expect(verificacion).toContain('from cron.job trabajo')
  })
})
