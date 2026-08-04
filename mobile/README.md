# AgenKin para Android

Primera etapa de la aplicación móvil para usuarios finales. Comparte Supabase
Auth, PostgreSQL, RLS, RPC y Edge Functions con el portal web; no duplica lógica
de negocio, no incorpora administración y no contiene secretos.

## Alcance implementado

- inicio de sesión con Google mediante Supabase Auth y PKCE;
- sesión persistida con `flutter_secure_storage`;
- validación de `perfiles.estado_acceso` antes de mostrar el portal;
- rutas protegidas con GoRouter y estados de sesión ausente, bloqueada y error;
- navegación inferior: Inicio, Agenda, Compromisos, Conexiones y Configuración;
- Agenda interna con estado real de Google Calendar;
- compromisos futuros, detalle, cuenta Gmail de origen y descarte mediante RPC;
- estado multicuenta Gmail/Calendar y acciones reales de autorizar, actualizar y
  desconectar mediante Edge Functions existentes;
- tema claro, oscuro o del sistema y preferencia local de avisos;
- estados de carga, error, vacío y reintento, con interfaz Material 3 accesible.

No se incluyeron biometría, notificaciones push, administración, pagos ni datos
simulados. La preferencia local de avisos deja preparado el ajuste, pero no
programa notificaciones en esta etapa.

## Arquitectura

```text
lib/
├── data/
│   ├── models/              DTO inmutables de los contratos remotos
│   ├── services/            Supabase, plataforma y preferencias locales
│   └── repositories/        conversión de DTO a modelos de dominio
├── domain/
│   ├── models/              modelos inmutables y resultados tipados
│   ├── repositories/        interfaces de acceso a datos
│   └── use_cases/           coordinación entre repositorios
├── ui/
│   ├── core/                tema, router, navegación y widgets compartidos
│   └── features/            Views y ViewModels por funcionalidad
├── di/                      providers de inyección de dependencias
└── core/                    configuración, errores y sesión segura
```

Riverpod administra dependencias y datos asíncronos; GoRouter aplica las
guardas y conserva las cinco ramas de navegación. Las Views sólo renderizan y
delegan acciones a ViewModels. Freezed genera DTO, modelos y estados inmutables;
los repositorios ocultan nombres SQL y devuelven resultados tipados con mensajes
seguros.

## Backend reutilizado

Lecturas con RLS:

- `perfiles`: identidad visible del usuario y `estado_acceso`;
- `eventos_calendar`: Agenda interna y estado de réplica;
- `vencimientos_detectados`: compromisos futuros accionables;
- `correos_procesados`: asunto y `conexion_google_id` mediante la relación ya
  expuesta por el portal.

RPC autenticadas:

- `registrar_ultimo_acceso()`;
- `obtener_panel_usuario()`;
- `obtener_estado_conexion_google()`;
- `descartar_vencimiento(p_vencimiento_id)`.

Edge Functions autenticadas:

- `google-oauth-start`;
- `google-disconnect`;
- `scan-gmail`.

La aplicación nunca consulta directamente columnas de tokens de
`conexiones_google`: el estado seguro se obtiene por
`obtener_estado_conexion_google()`.

## Requisitos

- Flutter estable 3.44 o superior;
- Dart 3.12 o superior;
- Android SDK y JDK 17 para ejecutar o construir APK/AAB;
- proyecto Supabase de AgenKin con migraciones y Edge Functions desplegadas.

El identificador Android es `com.kinovich.agenkin` y el mínimo es Android SDK
24.

En la estación preparada para AgenKin, Flutter está agregado al PATH del
usuario, OpenJDK 17 está instalado y el SDK mínimo se encuentra en
`%LOCALAPPDATA%\Android\Sdk` con Platform/Build Tools 36, NDK 28.2 y CMake
3.22.1, requerido por los plugins nativos actuales.

## Configuración por entorno

No se leen archivos `.env` en tiempo de ejecución. Flutter compila variables
públicas mediante `--dart-define-from-file`, lo que permite separar desarrollo
y producción sin sumar otra dependencia.

```powershell
cd mobile
Copy-Item .env.example .env.development
```

Completar únicamente:

```env
APP_ENV=development
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_reemplazar
AUTH_REDIRECT_URL=com.kinovich.agenkin://login-callback/
```

Para producción usar `.env.production` con `APP_ENV=production`. Ambos archivos
están ignorados por Git. La URL y clave publicable forman parte de cualquier
cliente público; nunca agregar `service_role`, secretos OAuth, refresh tokens ni
claves de IA.

## Supabase Auth y deep link

1. En Supabase → Authentication → URL Configuration agregar exactamente:

   ```text
   com.kinovich.agenkin://login-callback/
   ```

2. Mantener Google habilitado como proveedor de Supabase Auth con el cliente web
   ya usado por AgenKin.
3. El `AndroidManifest.xml` ya declara el esquema y host anteriores.
4. El login abre Google en el navegador externo y Supabase Flutter recupera la
   sesión desde el deep link.

Supabase Flutter 2 usa PKCE por defecto. La app además fija PKCE explícitamente y
valida de nuevo el perfil contra la base antes de habilitar las rutas privadas.

## Permisos adicionales Gmail y Calendar

Las autorizaciones adicionales no son el login principal. La app invoca la Edge
Function existente `google-oauth-start`, abre la URL real de Google y refresca el
estado al volver al primer plano.

Limitación conocida: `google-oauth-callback` redirige hoy siempre a
`APP_PUBLIC_URL/app.html`. La autorización puede completarse, pero el final del
flujo queda en el portal web. Para una devolución móvil completa, el cambio
mínimo de backend es:

1. aceptar en `google-oauth-start` un destino enumerado `web | android`;
2. persistir ese valor en `oauth_states`, asociado al estado aleatorio existente;
3. en `google-oauth-callback`, redirigir sólo el destino `android` a una URI fija
   permitida, por ejemplo
   `com.kinovich.agenkin://integration-callback?estado=conectado&servicio=gmail`;
4. registrar ese host en Android y refrescar `obtener_estado_conexion_google` al
   recibirlo.

No se debe aceptar una URL arbitraria enviada por el cliente: el backend debe
elegir entre destinos fijos para evitar redirecciones abiertas. Este cambio no se
incluyó porque modifica el contrato OAuth compartido con el portal.

## Ejecutar

```powershell
cd mobile
flutter pub get
flutter run --dart-define-from-file=.env.development
```

Para producción:

```powershell
flutter build appbundle --release --dart-define-from-file=.env.production
```

La firma release debe configurarse fuera del repositorio antes de publicar. El
proyecto no reutiliza la clave debug para builds release y no publica en Play
Console. Para generar el APK universal de prueba:

```powershell
flutter build apk --debug --dart-define-from-file=.env.development
```

## Validación

```powershell
cd mobile
flutter analyze
flutter test
```

Las pruebas cubren configuración, guardas, ausencia de sesión, cuenta bloqueada,
navegación inferior, Services, Repositories, ViewModels y conversión de los
contratos reales de Supabase.

## Seguridad

- La sesión se guarda en Android Keystore mediante `flutter_secure_storage`.
- Las preferencias visuales no sensibles usan `shared_preferences`.
- Toda lectura directa depende de RLS y toda transición sensible reutiliza RPC o
  Edge Function autenticada.
- La app no incluye `service_role`, funciones administrativas ni secretos.
- Los mensajes de error no exponen respuestas internas, tokens ni PII técnica.
