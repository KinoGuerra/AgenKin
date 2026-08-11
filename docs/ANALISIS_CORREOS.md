# Análisis de correos

## Flujo efectivo

```text
Gmail History → cola durable → (Publicidad) → regla Ignorar
→ exclusión privada → patrón personal/global verificado → clasificación local segura
→ Groq opcional → revisión manual
→ persistencia atómica → Agenda interna → Calendar principal opcional
```

La marca explícita `(Publicidad)` en el asunto se resuelve primero como
promoción, aunque el contenido incluya fechas, montos o llamados a la acción.
Fuera de esa marca, un correo dudoso continúa hacia Groq si está habilitado: sólo se resuelve como
promoción sin IA cuando no tiene fechas, expresiones temporales, montos ni
acciones, y además combina un asunto promocional inequívoco con
`List-Unsubscribe`.

La clasificación local exige remitente autenticado, una única fecha accionable,
como máximo una hora y un monto, un único tipo deducible y ausencia de señales
contradictorias. Si la fecha ya pasó, el hallazgo puede conservarse como
antecedente, pero no es elegible para autoagenda.

Las reglas personales sólo resuelven la acción `Ignorar`. La creación automática
no requiere una regla `Priorizar`: el interruptor de Configuración es la
autorización general del usuario.

## Contrato compacto de Groq

Payload orientativo:

```json
{
  "asunto": "Tu factura ya está disponible",
  "dominio_remitente": "epec.com.ar",
  "fecha_correo": "2026-08-03T10:00:00-03:00",
  "entidad_candidata": "Epec",
  "acciones": ["pagar", "vence"],
  "fechas_candidatas": [{"indice": 0, "valor": "2026-08-10", "contexto": "Vence el 10/08/2026"}],
  "montos_candidatos": [{"indice": 0, "valor": 25780.5, "contexto": "Total $25.780,50"}],
  "horas_candidatas": [],
  "fragmento": "El vencimiento es el 10/08/2026. Total $25.780,50."
}
```

Respuesta:

```json
{
  "relevante": true,
  "tipo": "pago",
  "fecha_indice": 0,
  "fecha_detectada": null,
  "monto_indice": 0,
  "monto_detectado": null,
  "hora": null,
  "confianza": 0.96,
  "requiere_revision": false
}
```

Categoría, grupo, título, descripción, explicación y zona horaria se generan
localmente. La respuesta rechaza propiedades adicionales, índices inválidos,
fechas inexistentes, importes fuera de rango y horas inválidas.

## Métricas disponibles

`correos_procesados` conserva origen (`regla`, patrón, `local` o `ia`), tokens,
duración, huella y marca de duplicado. `consumos_mensuales` conserva agregados;
las colas y `eventos_calendar.estado_google` permiten medir descubrimiento,
pendientes y errores.

Consultas derivables:

```text
tasa_llamadas_ia = origen_ia / correos_procesados
tasa_cache = tokens_cache / tokens_entrada
tokens_promedio_por_llamada = (tokens_entrada + tokens_salida) / origen_ia
tokens_por_vencimiento = (tokens_entrada + tokens_salida) / vencimientos_detectados
```

No se almacenan prompts, respuestas crudas ni cuerpos completos.

## Presupuesto y prioridad de IA

La cola distingue `incremental`, `reconciliacion` e `historica`. Las dos primeras
se atienden antes y un Gmail ID ya conocido nunca reactiva por sí solo un error
terminal. Cada intento hace una sola petición al proveedor; 429, timeout o 5xx
pueden recibir un segundo y último intento al día siguiente.

Antes de llamar a Groq se reserva capacidad de forma atómica. Los valores
predeterminados globales son 300 solicitudes, 80.000 tokens no cacheados y 20
solicitudes históricas por día. Cuando se alcanza un límite, el correo pasa a
revisión sin llamar al proveedor. Los headers de 429
bloquean además las nuevas reservas hasta el instante informado por Groq.

Gmail History sigue siendo el mecanismo principal. Una reconciliación diaria,
con cursor independiente, pagina los últimos siete días de a 100 IDs para cerrar
huecos sin volver a importar los 90 días iniciales.

## Autoagenda y aprendizaje por descarte

La creación automática exige simultáneamente:

- autorización explícita en Configuración;
- suscripción y cuenta Gmail activas;
- confianza igual o superior al umbral elegido;
- fecha no vencida en la zona horaria del hallazgo;
- `requiere_revision=false`;
- dominio de remitente y huella de plantilla válidos;
- ausencia de un descarte previo para ese usuario, dominio y plantilla;
- ausencia de un evento interno para el mismo vencimiento.

Se crean como máximo cinco eventos por ejecución. La guardia diaria permite
veinte eventos internos activos por usuario; los eventos descartados y marcados
como `eliminado` no consumen ese límite.

Los descartes se recuerdan por usuario, dominio autenticado y huella de
plantilla. No afectan a otros usuarios ni impiden crear manualmente un evento
similar. Los correos futuros semejantes continúan visibles, pero no se
autoagendan.

## Agenda y Google Calendar

Agenda es la fuente principal. `registrar_evento_agenda` confirma primero el
evento interno y, sólo si existe un Calendar principal activo, deja una tarea
`crear` en `calendar_sync`. La interfaz expone el estado real:

- `Sólo en Agenda`: no hay Calendar activo;
- `Google pendiente`: existe una creación o reintento en curso;
- `Sincronizado con Google`: Google confirmó el evento;
- `Error de Google`: la Agenda interna existe, pero la réplica falló.

Al descartar un hallazgo pendiente o autoagendado, una sola transacción registra
la exclusión aprendida, cambia el vencimiento a `descartado`, oculta el evento
interno y encola `eliminar` cuando corresponde. La eliminación usa
`events.delete`; `404` cuenta como éxito y los errores temporales se reintentan.
Los mensajes incluyen la operación para que una tarea vieja de creación no
pueda sobrescribir una eliminación más reciente.

El worker de Calendar procesa hasta tres tareas por ejecución. Un fallo o una
desconexión de Google nunca revierte la creación interna.
El programador también reconstruye tareas de creación ausentes o completadas sin
`google_event_id`; un error `GOOGLE_TEMPORAL` puede continuar hasta diez intentos,
mientras tokens vencidos y errores permanentes esperan una acción explícita.

La deduplicación funcional se activa únicamente cuando el correo aporta una
referencia explícita (por ejemplo, número de factura, comprobante, cuota,
reserva o turno). Sin ese discriminador AgenKin prefiere conservar dos
hallazgos antes que fusionar compromisos legítimos.

## Trabajo posterior deliberadamente fuera de alcance

- separar la identidad Calendar de la conexión Gmail que porta su token;
- modelar una relación N:M entre correos y un vencimiento compartido;
- panel avanzado de salud y métricas;
- varios recordatorios por tipo;
- Groq Batch API para cargas históricas.

La huella actual conserva trazabilidad en cada correo y evita el segundo
vencimiento, pero una relación N:M será necesaria si la interfaz debe enumerar
todos los correos que respaldan un único compromiso.
