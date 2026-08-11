# Configuración de Groq

AgenKin usa Groq como proveedor predeterminado para clasificar correos y detectar
fechas accionables. La llamada se realiza desde el worker global de Gmail
mediante `supabase/functions/_shared/ai.ts`; `scan-gmail` solo descubre y encola.
El navegador nunca se conecta directamente con Groq.

Groq es opcional. `AI_PROVIDER=none` desactiva las llamadas externas: los casos
ambiguos pasan inmediatamente a revisión, sin reservar presupuesto. Si
`AI_PROVIDER` no está definido, AgenKin usa `groq` cuando encuentra
`AI_API_KEY` o `GROQ_API_KEY`; sin clave adopta `none`.

Groq es el último recurso de clasificación. La marca exacta `(Publicidad)`, una
regla personal de ignorar, un patrón verificado o una clasificación local segura
resuelven el correo antes de cualquier llamada al proveedor.

## 1. Crear el proyecto y la clave

1. Iniciar sesión en [GroqCloud](https://console.groq.com/).
2. Crear o seleccionar un proyecto.
3. Abrir la sección **API Keys** y crear una clave para AgenKin.
4. Copiarla en ese momento y guardarla en un gestor de secretos. No pegarla en
   el repositorio, GitHub Pages, archivos JavaScript, URLs ni registros.

Si una clave se comparte por un canal no destinado a secretos, debe considerarse
expuesta: revocarla y crear una nueva antes de usarla en producción.

## 2. Enlazar Supabase

```bash
supabase login
supabase link --project-ref kpqzwbhprqlapwhadejt
```

## 3. Configurar Supabase Secrets

Ejecutar el siguiente bloque desde una terminal segura. Reemplazar el marcador
por una clave nueva; el valor no debe quedar en el historial compartido, capturas
ni documentación.

```bash
supabase secrets set \
  AI_PROVIDER="groq" \
  AI_API_URL="https://api.groq.com/openai/v1/chat/completions" \
  AI_MODEL="openai/gpt-oss-20b" \
  AI_API_KEY="REEMPLAZAR_CON_CLAVE_GROQ" \
  AI_TIMEOUT_MS="20000" \
  AI_MAX_SOLICITUDES_DIA="300" \
  AI_MAX_TOKENS_DIA="80000" \
  AI_MAX_ATRASO_DIA="20"
```

Los secretos alojados están disponibles para las Edge Functions sin volver a
desplegarlas. No crear variables `VITE_AI_*`: todo valor `VITE_*` forma parte del
bundle público.

Configuración predeterminada:

- proveedor: `groq`;
- endpoint: `https://api.groq.com/openai/v1/chat/completions`;
- modelo: `openai/gpt-oss-20b`;
- timeout: 20 segundos;
- salida máxima: 300 tokens mediante `max_completion_tokens`;
- presupuesto diario: 300 solicitudes, 80.000 tokens no cacheados y 20
  solicitudes históricas;
- razonamiento bajo, sin contenido de razonamiento y temperatura cero.

El adaptador conserva nombres genéricos (`AI_PROVIDER`, `AI_API_URL`,
`AI_MODEL`, `AI_API_KEY`), pero esta versión admite únicamente `groq` y `none`.
Otro valor se rechaza como configuración inválida.

## 4. Desplegar el worker

Después de aplicar las migraciones y revisar los cambios:

```bash
supabase db push
supabase functions deploy scan-gmail
supabase functions deploy process-gmail-queue --no-verify-jwt
```

`scan-gmail` conserva `verify_jwt = true`, valida identidad y suscripción, y
encola mensajes de las cuentas solicitadas. `process-gmail-queue` es global,
requiere el secreto de Cron y usa Groq solamente cuando la marca de publicidad,
una regla, un patrón verificado o la clasificación local segura no resuelven el caso. No existe cupo
comercial de mensajes.

Si se modifica `supabase/functions/_shared/ai.ts`, `patterns.ts` o
`process-email.ts`, desplegar al menos `process-gmail-queue`, que es el worker
que empaqueta y ejecuta esos módulos.

## 5. Prueba local sin Gmail

No hace falta crear una función pública de prueba. Usar un archivo local de
variables ignorado por Git, por ejemplo `.env.groq.local`, y ejecutar:

```bash
npx --yes deno run \
  --allow-env=AI_PROVIDER,AI_API_URL,AI_MODEL,AI_API_KEY,AI_TIMEOUT_MS,AI_MAX_SOLICITUDES_DIA,AI_MAX_TOKENS_DIA,AI_MAX_ATRASO_DIA \
  --allow-net=api.groq.com \
  --env-file=.env.groq.local \
  scripts/probar-clasificacion-ia.ts
```

Contenido local esperado:

```env
AI_PROVIDER=groq
AI_API_URL=https://api.groq.com/openai/v1/chat/completions
AI_MODEL=openai/gpt-oss-20b
AI_API_KEY=REEMPLAZAR_CON_CLAVE_GROQ
AI_TIMEOUT_MS=20000
AI_MAX_SOLICITUDES_DIA=300
AI_MAX_TOKENS_DIA=80000
AI_MAX_ATRASO_DIA=20
```

El script envía solamente un correo ficticio y muestra su clasificación. No
imprime la clave ni datos personales. Las pruebas automatizadas (`npm run test`)
simulan `fetch` y nunca llaman a Groq.

## 6. Errores frecuentes

- **401**: la clave no es válida o fue revocada. Rotarla y actualizar
  `AI_API_KEY`.
- **403**: el proyecto o la clave no tiene permiso para el modelo solicitado.
  Revisar permisos del modelo y del proyecto.
- **429**: se alcanzó temporalmente un límite. AgenKin respeta `Retry-After` y
  los headers de límite, abre un cortacircuito compartido y no repite llamadas
  dentro del mismo intento.
- **5xx**: indisponibilidad transitoria del proveedor. La llamada no se repite
  dentro del worker; el correo puede recibir un segundo y último intento al día
  siguiente.
- **Timeout**: revisar conectividad, estado del proveedor y `AI_TIMEOUT_MS`.

Los límites dependen del proyecto y pueden cambiar. Consultar el uso y los
límites vigentes en la consola de Groq; no asumir que un plan es ilimitado.
Los tres límites `AI_MAX_*` son defensas propias de AgenKin y pueden reducirse
sin cambiar la cuota contratada. Al agotarse, el correo pasa a revisión sin
invocar Groq; patrones y clasificación local continúan funcionando.
Supervisar los conteos de tareas pendientes y `AI_LIMITE_TEMPORAL` sin copiar
asuntos, remitentes ni cuerpos a los logs de diagnóstico.

## 7. Rotar o revocar una clave

1. Crear una clave nueva en Groq.
2. Actualizar solo `AI_API_KEY` con `supabase secrets set`.
3. Confirmar una clasificación ficticia.
4. Revocar la clave anterior en Groq.
5. Revisar el uso reciente y los logs técnicos sanitizados.

Si se sospecha una exposición, revocar primero la clave afectada. Los logs de
AgenKin no deben contener asuntos, remitentes, cuerpos, prompts, respuestas
completas, tokens OAuth ni claves.

## 8. Privacidad antes de comercializar

Antes de habilitar AgenKin para terceros, revisar las condiciones vigentes de
privacidad, tratamiento y retención de Groq, y reflejar las decisiones en la
política de privacidad. Solo se envían asunto, dominio del remitente, fecha del
correo, entidad y candidatos estructurados, más un fragmento sanitizado de hasta
1.200 caracteres. Cada contexto candidato se limita a 240 caracteres. No se
envían adjuntos, HTML completo, direcciones completas, tokens OAuth, roles,
suscripciones ni identificadores internos.

Referencias oficiales:

- [Structured Outputs de Groq](https://console.groq.com/docs/structured-outputs)
- [Referencia de Chat Completions](https://console.groq.com/docs/api-reference)
- [Límites de Groq](https://console.groq.com/docs/rate-limits)
- [Códigos de error de Groq](https://console.groq.com/docs/errors)
- [Secretos de Edge Functions](https://supabase.com/docs/guides/functions/secrets)
