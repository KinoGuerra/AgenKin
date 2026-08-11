import { readFileSync } from 'node:fs'
import { describe, expect, it } from 'vitest'
import { validarSuscripcionPush } from '../supabase/functions/_shared/web-push.ts'

const migracionAlertas = readFileSync(
  new URL('../supabase/migrations/20260811185541_notificaciones_internas.sql', import.meta.url),
  'utf8',
)
const migracionPush = readFileSync(
  new URL('../supabase/migrations/20260811185544_web_push_seguro.sql', import.meta.url),
  'utf8',
)
const worker = readFileSync(
  new URL('../supabase/functions/process-notifications-scheduled/index.ts', import.meta.url),
  'utf8',
)
const serviceWorker = readFileSync(new URL('../public/sw.js', import.meta.url), 'utf8')
const interfaz = readFileSync(new URL('../src/services/notifications.js', import.meta.url), 'utf8')
const guardia = readFileSync(new URL('../src/guards/route-guard.js', import.meta.url), 'utf8')
const procesadorCorreo = readFileSync(
  new URL('../supabase/functions/_shared/process-email.ts', import.meta.url),
  'utf8',
)

const claves = {
  p256dh: 'A'.repeat(65),
  auth: 'B'.repeat(22),
}

describe('validación defensiva de Web Push', () => {
  it.each([
    'https://fcm.googleapis.com/fcm/send/abc',
    'https://updates.push.services.mozilla.com/wpush/v2/abc',
    'https://web.push.apple.com/QWERTY',
    'https://wns2-par02p.notify.windows.com/w/?token=abc',
  ])('acepta el proveedor permitido %s', (endpoint) => {
    expect(validarSuscripcionPush({ endpoint, expirationTime: null, keys: claves }).endpoint)
      .toMatch(/^https:/)
  })

  it.each([
    'http://fcm.googleapis.com/fcm/send/abc',
    'https://fcm.googleapis.com.ejemplo.test/abc',
    'https://usuario:clave@fcm.googleapis.com/abc',
    'https://127.0.0.1/abc',
    'https://localhost/abc',
    'https://fcm.googleapis.com:8443/abc',
  ])('rechaza el destino hostil %s', (endpoint) => {
    expect(() => validarSuscripcionPush({ endpoint, keys: claves })).toThrow()
  })
})

describe('colas, RLS y minimización', () => {
  it('crea tablas cerradas y reclamos acotados con leases', () => {
    expect(migracionAlertas).toContain('alter table public.notificaciones enable row level security')
    expect(migracionPush).toContain('alter table public.suscripciones_push_web enable row level security')
    expect(migracionPush).toContain('alter table public.entregas_push_web enable row level security')
    expect(migracionPush).toContain('for update of d skip locked')
    expect(migracionPush).toContain("interval '5 minutes'")
    expect(migracionPush).toContain('and intentos = p_intento')
    expect(worker).toContain('p_intento: entrega.intento')
    expect(migracionPush).toContain('least(greatest(coalesce(p_limite, 40), 1), 40)')
    expect(migracionPush).toContain('datos_cifrados')
    expect(migracionPush).not.toContain('endpoint text')
  })

  it('mantiene el Push genérico y separado del contenido privado', () => {
    expect(worker).toContain("JSON.stringify({ notification_id: entrega.notificacion_id })")
    expect(worker).not.toContain('entrega.titulo')
    expect(worker).not.toContain('entrega.monto')
    expect(serviceWorker).toContain('Tenés un vencimiento en Agenda.')
    expect(serviceWorker).not.toContain('correo')
  })

  it('no usa innerHTML para datos del centro de notificaciones', () => {
    expect(interfaz).not.toContain('innerHTML')
    expect(interfaz).toContain('titulo.textContent = notificacion.titulo')
    expect(interfaz).toContain("Notification.requestPermission()")
  })

  it('preserva sólo el destino permitido tras login y difiere la IA temporal un día', () => {
    expect(guardia).toContain("window.location.pathname.endsWith('/agenda.html')")
    expect(guardia).toContain('DESTINO_NOTIFICACION.test(destino)')
    expect(procesadorCorreo).toContain('return 86_400_000')
  })
})
