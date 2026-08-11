const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i

globalThis.addEventListener('push', (evento) => {
  let notificacionId
  try {
    const datos = evento.data?.json()
    notificacionId = String(datos?.notification_id || '')
  } catch {
    return
  }
  if (!UUID.test(notificacionId)) return
  evento.waitUntil(globalThis.registration.showNotification('AgenKin', {
    body: 'Tenés un vencimiento en Agenda.',
    data: { notification_id: notificacionId },
    tag: `agenkin-${notificacionId}`,
  }))
})

globalThis.addEventListener('notificationclick', (evento) => {
  evento.notification.close()
  const notificacionId = String(evento.notification.data?.notification_id || '')
  if (!UUID.test(notificacionId)) return
  const destino = new globalThis.URL('agenda.html', globalThis.registration.scope)
  destino.searchParams.set('notificacion', notificacionId)
  evento.waitUntil((async () => {
    const ventanas = await globalThis.clients.matchAll({ type: 'window', includeUncontrolled: true })
    const existente = ventanas.find((ventana) => ventana.url.startsWith(globalThis.registration.scope))
    if (existente) {
      await existente.navigate(destino.href)
      await existente.focus()
      existente.postMessage({ tipo: 'AGENKIN_NOTIFICACION_ABIERTA' })
      return
    }
    await globalThis.clients.openWindow(destino.href)
  })())
})
