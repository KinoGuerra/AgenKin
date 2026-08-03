# Análisis de correos

## Flujo efectivo

```text
Gmail History → cola durable → regla personal → patrón verificado
→ clasificación local segura → Groq compacto → persistencia atómica
→ Agenda interna → Calendar principal opcional
```

Un correo dudoso continúa hacia Groq. Sólo se resuelve como promoción sin IA
cuando no tiene fechas, expresiones temporales, montos ni acciones, y además
combina un asunto promocional inequívoco con `List-Unsubscribe`.

La clasificación local exige remitente autenticado, una fecha accionable
vigente, como máximo una hora y un monto, un único tipo deducible y ausencia de
señales contradictorias.

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
