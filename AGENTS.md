# AGENTS.md — AgenKin

## Objetivo

AgenKin convierte fechas importantes detectadas en correos autorizados en
eventos de Google Calendar, siempre después de la confirmación del usuario.

## Stack y arquitectura

- Vite multipágina con JavaScript ES, HTML semántico y CSS responsive.
- Sin React ni router: cada portal tiene su propio archivo HTML.
- Supabase Auth, PostgreSQL, RLS y Edge Functions con Deno.
- GitHub Pages bajo el base path `/AgenKin/`.
- Vitest y ESLint para validación local.

Rutas principales:

- `index.html`: landing y login.
- `app.html`: portal del usuario.
- `access.html`: selector exclusivo del superadministrador.
- `admin.html`: administración.
- `src/services/supabase.js`: único cliente Supabase del frontend.
- `supabase/migrations/`: esquema, funciones y RLS.
- `supabase/functions/`: administración e integraciones externas.

## Reglas obligatorias

- Escribir interfaz y documentación en español.
- Mantener la solución más simple que cubra el requisito.
- No agregar React, frameworks, dependencias o abstracciones sin necesidad real.
- No usar datos simulados en producción ni botones que aparenten funcionar.
- Mostrar estados claros de carga, error, éxito, vacío o configuración requerida.
- Mantener accesibilidad básica, contraste y diseño móvil.
- No insertar datos externos mediante `innerHTML`; usar `textContent` y nodos DOM.

## Seguridad

- Nunca exponer secretos, tokens OAuth ni `SUPABASE_SERVICE_ROLE_KEY`.
- Ningún secreto puede usar el prefijo `VITE_`.
- Validar identidad desde el JWT; nunca confiar en un correo enviado por el frontend.
- Mantener RLS activa y evitar lecturas cruzadas entre usuarios.
- Ejecutar acciones administrativas sensibles mediante Edge Functions.
- Cifrar refresh tokens y no mostrarlos ni escribirlos en logs.
- No almacenar permanentemente el cuerpo completo de los correos.
- No crear eventos sin confirmación manual.
- No asignar automáticamente el rol `superadministrador`.

## Base de datos y Edge Functions

- Las migraciones deben ser ordenadas, reproducibles e idempotentes.
- Evitar recursividad en RLS usando funciones auxiliares seguras.
- Las acciones administrativas deben ser transaccionales y auditadas.
- Gmail se usa únicamente con alcance de lectura.
- El modelo y proveedor de IA se configuran mediante variables de entorno.
- Las integraciones deben fallar con “Configuración requerida” cuando falten secretos.

## Validación

Antes de entregar cambios ejecutar:

```bash
npm run lint
npm run test
npm run build
```

Para cambios en Edge Functions ejecutar también:

```bash
npx --yes deno check supabase/functions/<funcion>/index.ts
```

Revisar enlaces, consola, rutas de GitHub Pages, vista móvil y ausencia de secretos.

## Git y publicación

- No hacer commit, push, despliegue ni cambios remotos sin autorización explícita.
- No sobrescribir cambios ajenos ni usar comandos Git destructivos.
- El workflow de Pages debe conservar lint, pruebas y build como pasos obligatorios.
- GitHub Pages requiere habilitación previa; en planes sin Pages privadas, solicitar
  autorización antes de cambiar la visibilidad del repositorio.
