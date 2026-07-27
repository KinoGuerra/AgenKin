# Reglas del proyecto AgenKin

- Toda interfaz y documentación orientada al usuario debe estar en español.
- No exponer secretos, tokens OAuth ni la clave `service_role` en el frontend, commits o logs.
- Centralizar el acceso frontend a Supabase en `src/services/supabase.js`.
- Las operaciones administrativas sensibles y las integraciones con Google se ejecutan únicamente mediante Edge Functions.
- Mantener RLS activa y validar siempre la identidad desde el JWT.
- No almacenar cuerpos completos de correos.
- No crear eventos de Calendar sin confirmación explícita.
- No incorporar datos ficticios en producción.
- Antes de entregar cambios ejecutar `npm run lint`, `npm run test` y `npm run build`.
- No hacer commit, push o despliegue sin autorización explícita.
