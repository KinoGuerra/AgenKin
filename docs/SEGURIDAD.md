# Seguridad de AgenKin

## Límites de confianza

- El frontend no decide roles, identidad, suscripción ni cupos.
- Supabase obtiene la identidad desde el JWT.
- RLS protege las consultas propias.
- Las operaciones administrativas y de Google usan Edge Functions.
- La función SQL administrativa verifica el rol, bloquea el auto-bloqueo, actualiza y audita dentro de una transacción.

## Tokens y secretos

El refresh token de Google se cifra con AES-256-GCM. `TOKEN_ENCRYPTION_KEY` debe contener 32 bytes aleatorios codificados en base64:

```bash
openssl rand -base64 32
```

Guardar el resultado solo como Supabase Secret. La rotación requiere descifrar y volver a cifrar los tokens existentes o desconectar las cuentas.

Secretos requeridos:

- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `GOOGLE_REDIRECT_URI`
- `TOKEN_ENCRYPTION_KEY`
- `APP_PUBLIC_URL`
- `AI_PROVIDER`
- `AI_API_KEY`
- `AI_MODEL`
- `AI_API_URL`
- `AI_TIMEOUT_MS`

`SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` son inyectados por Supabase en las funciones. La clave `service_role` nunca debe salir de ese entorno.

## Correo e IA

- Gmail se abre en modo de solo lectura.
- No se registran tokens ni cuerpos en logs.
- Groq se invoca solo desde `scan-gmail`; no existe una llamada desde el navegador.
- La clave de Groq vive únicamente en Supabase Secrets y nunca usa prefijo `VITE_`.
- Se envían únicamente asunto, remitente, fecha y texto plano sanitizado.
- No se envían tokens OAuth, identificadores internos, roles, datos de
  suscripción, adjuntos, HTML completo ni historial innecesario.
- El asunto se limita a 500 caracteres, el remitente a 300 y el texto a 12.000.
- El cuerpo plano se sanitiza, se limita antes de enviarse y no se persiste.
- La base conserva identificadores, remitente, asunto, categoría y resultado estructurado.
- El JSON Schema estricto se complementa con validación local de categorías,
  tipos, confianza, fecha, hora, zona horaria, coherencia y longitudes.
- Los correos se deduplican por `usuario_id + gmail_message_id` y cada correo
  puede generar como máximo un vencimiento.
- Un fallo técnico de IA devuelve el cupo mensual. Los intentos internos no
  vuelven a reservarlo; el correo queda en estado recuperable.
- Los logs técnicos incluyen solamente proveedor, modelo, duración, estado HTTP,
  intentos, código interno y conteos de tokens cuando existen.
- Verificar las condiciones de tratamiento y retención del proveedor antes de habilitarlo.

Los errores enviados al frontend están normalizados y nunca incluyen el cuerpo,
la respuesta cruda del proveedor, headers, claves ni detalles de infraestructura.
La configuración operativa está en
[Configuración de Groq](CONFIGURACION_GROQ.md).

## OAuth

- `state` tiene entropía criptográfica, se almacena como hash, vence en diez minutos y es de un solo uso.
- Las URLs de aplicación y callback deben usar HTTPS, salvo localhost.
- El callback nunca agrega tokens a la redirección.

## Frontend y GitHub Pages

GitHub Pages no permite definir encabezados HTTP arbitrarios. Cada página pública principal usa una política CSP mediante `<meta>`. Esto no reemplaza encabezados como HSTS o `frame-ancestors`; si el producto requiere controles completos, publicar el frontend detrás de un servicio que permita encabezados.

El código dinámico usa `textContent` y creación de nodos; no inserta datos externos con `innerHTML`.

## Respuesta a incidentes

1. Deshabilitar las funciones afectadas.
2. Rotar las credenciales implicadas.
3. Revocar conexiones Google cuando corresponda.
4. Revisar `auditoria_administrativa` y errores recientes sin copiar datos sensibles.
5. Notificar a las personas afectadas conforme a la normativa aplicable.

Para una clave de Groq expuesta: revocarla en Groq, crear una nueva, actualizar
`AI_API_KEY` en Supabase Secrets y revisar el uso reciente sin copiar contenido
de correos a los registros del incidente.
