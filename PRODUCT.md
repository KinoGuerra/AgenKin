# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

AgenKin está pensado para personas que reciben vencimientos, pagos, turnos y
otras fechas importantes en una o varias cuentas Gmail. Su trabajo principal
es mantener esos compromisos organizados sin revisar manualmente cada bandeja
ni copiar fechas a un calendario.

El producto también tiene un portal web separado para el superadministrador,
que gestiona accesos, planes y salud operativa sin acceder al contenido de los
correos de los usuarios.

## Product Purpose

AgenKin detecta fechas accionables en cuentas Gmail autorizadas, las guarda
primero en una Agenda interna y, si el usuario lo habilita, replica los eventos
en un único Google Calendar. El éxito significa que los compromisos relevantes
aparezcan de forma confiable, sin duplicados ni cruces entre usuarios y con la
menor intervención cotidiana posible.

La lectura incremental de Gmail, el análisis y la creación de eventos deben
ejecutarse en segundo plano y acercarse al comportamiento automático. Esto
describe una experiencia sin acciones repetitivas del usuario, no una promesa
de tiempo real: la latencia depende de colas durables, Cron, capacidad disponible
y las APIs de Google.

## Positioning

AgenKin combina automatización prudente con una Agenda propia que no depende de
Google Calendar. Gmail se utiliza en modo lectura; los casos seguros pueden
autoagendarse y los ambiguos quedan visibles para revisión. Calendar y Web Push
son extensiones voluntarias, no condiciones para conservar un evento.

## Operating Context

El usuario inicia sesión con su identidad básica de Google y luego conecta por
separado las cuentas Gmail permitidas por su plan. La importación inicial y los
cambios posteriores se procesan mediante Gmail History y workers globales. El
usuario consulta una Agenda consolidada, puede confirmar o descartar hallazgos,
activar la creación automática y elegir una sola conexión Calendar opcional.

El servicio tiene landing, portal web de usuario, administración web y una
aplicación Android que comparte Auth, RLS, RPC y Edge Functions. La beta actual
opera sobre Supabase y GitHub Pages con capacidad acotada y modalidad de mejor
esfuerzo.

## Capabilities and Constraints

- Varias cuentas Gmail según el plan, sin cupo comercial por cantidad de
  mensajes, y un único Calendar principal por usuario.
- Agenda interna como fuente principal; una falla de Google no elimina ni
  impide conservar el evento interno.
- Sincronización incremental, colas durables, reintentos acotados y operaciones
  idempotentes para acercar el flujo a automático sin bloquear otras cuentas.
- Autoagenda únicamente con autorización del usuario, fecha futura, confianza
  suficiente, remitente autenticado, ausencia de contradicciones y
  `requiere_revision=false`.
- Revisión manual para resultados ambiguos y exclusiones privadas aprendidas de
  descartes, sin afectar a otros usuarios.
- Gmail exclusivamente con `gmail.readonly`; no se guardan cuerpos completos ni
  adjuntos y no se amplían permisos sin una decisión explícita.
- Procesamiento local y por patrones antes de IA; la IA es opcional y recibe
  solamente contexto relevante, sanitizado y limitado.
- Interfaz en español, rutas multipágina bajo `/AgenKin/` y ausencia deliberada
  de React, router o Realtime.
- El plan interno AgenKin es gratuito, no vence y solo puede asignarlo un
  superadministrador.

## Brand Commitments

El nombre del producto es AgenKin y su promesa verbal vigente es “Del correo a
tu agenda, automáticamente”. La voz es clara, directa y cercana, en español
argentino, sin exagerar la precisión ni ocultar las condiciones de seguridad.

Los logotipos vigentes están en `src/assets/agenkin-logo-light.png`,
`src/assets/agenkin-logo-dark.png` y `src/assets/agenkin-oauth-logo.png`.

## Evidence on Hand

El repositorio contiene una beta funcional con landing, portales, aplicación
Android, migraciones, políticas RLS, Edge Functions, workers, pruebas y
documentación operativa. La arquitectura y las restricciones verificables están
registradas en `README.md`, `AGENTS.md` y `docs/`.

No hay testimonios, métricas comerciales, precios publicados ni garantías de
disponibilidad que puedan presentarse como prueba. El contenido futuro no debe
inventarlos.

## Product Principles

1. Automatizar el trabajo repetitivo sin automatizar la incertidumbre.
2. Guardar primero en Agenda y tratar las integraciones externas como réplicas.
3. Acceder y conservar únicamente los datos necesarios para la función.
4. Mantener aislados usuarios, cuentas y dispositivos, con deduplicación e
   idempotencia explícitas.
5. Mostrar estados honestos cuando una tarea esté pendiente, requiera revisión
   o dependa de configuración externa.

## Accessibility & Inclusion

Las superficies web deben conservar navegación por teclado, foco visible,
contraste suficiente, semántica y ARIA adecuadas, adaptación móvil y respeto por
movimiento reducido. Los estados no pueden depender únicamente del color y los
datos externos se presentan como texto seguro.
