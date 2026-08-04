import 'package:agenkin/core/config/app_config.dart';
import 'package:agenkin/data/models/api_models.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class AuthService {
  Stream<Session?> watchSessions();
  Future<Session?> refreshSession();
  Future<UserProfileDto> loadProfile(String userId);
  Future<void> registerLastAccess();
  Future<bool> signInWithGoogle();
  Future<void> signOut();
}

class SupabaseAuthService implements AuthService {
  const SupabaseAuthService(this._client, this._config);

  final SupabaseClient _client;
  final AppConfig _config;

  @override
  Stream<Session?> watchSessions() async* {
    yield _client.auth.currentSession;
    yield* _client.auth.onAuthStateChange.map((change) => change.session);
  }

  @override
  Future<Session?> refreshSession() async {
    return (await _client.auth.refreshSession()).session;
  }

  @override
  Future<UserProfileDto> loadProfile(String userId) async {
    final raw = await _client
        .from('perfiles')
        .select('id,nombre_completo,email,avatar_url,estado_acceso')
        .eq('id', userId)
        .single();
    return UserProfileDto.fromMap(raw);
  }

  @override
  Future<void> registerLastAccess() {
    return _client.rpc<void>('registrar_ultimo_acceso');
  }

  @override
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _config.authRedirectUrl.toString(),
      scopes: 'openid email profile',
      authScreenLaunchMode: LaunchMode.externalApplication,
      queryParams: const {'prompt': 'select_account'},
    );
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}

abstract interface class PortalService {
  Future<DashboardSummaryDto> loadDashboard();
  Future<List<AgendaEventDto>> loadUpcomingAgenda();
  Future<List<CommitmentDto>> loadActionableCommitments();
  Future<void> discardCommitment(String id);
  Future<ConnectionsStateDto> loadConnections();
  Future<Uri> createAuthorizationUrl(String service, {String? connectionId});
  Future<void> disconnect({
    required String connectionId,
    required String service,
  });
  Future<void> requestSync(List<String> connectionIds);
}

class SupabasePortalService implements PortalService {
  const SupabasePortalService(this._client);

  final SupabaseClient _client;

  @override
  Future<DashboardSummaryDto> loadDashboard() async {
    final raw = await _client.rpc<Object?>('obtener_panel_usuario');
    if (raw is! Map) throw const FormatException('panel inválido');
    return DashboardSummaryDto.fromMap(Map<String, dynamic>.from(raw));
  }

  @override
  Future<List<AgendaEventDto>> loadUpcomingAgenda() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final raw = await _client
        .from('eventos_calendar')
        .select(
          'id,titulo,descripcion,fecha_evento,zona_horaria,es_dia_completo,estado_google,estado_sincronizacion',
        )
        .neq('estado_sincronizacion', 'eliminado')
        .gte('fecha_evento', startOfToday.toUtc().toIso8601String())
        .order('fecha_evento')
        .limit(100);
    return raw.map(AgendaEventDto.fromMap).toList(growable: false);
  }

  @override
  Future<List<CommitmentDto>> loadActionableCommitments() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final raw = await _client
        .from('vencimientos_detectados')
        .select(
          'id,tipo,titulo,descripcion,fecha_vencimiento,hora_vencimiento,zona_horaria,confianza,estado,requiere_revision,correos_procesados!vencimientos_correo_usuario_fkey(asunto,conexion_google_id)',
        )
        .gte('fecha_vencimiento', today)
        .inFilter('estado', const [
          'pendiente',
          'confirmado',
          'evento_creado',
          'error',
        ])
        .order('fecha_vencimiento')
        .limit(100);
    return raw.map(CommitmentDto.fromMap).toList(growable: false);
  }

  @override
  Future<void> discardCommitment(String id) {
    return _client.rpc<void>(
      'descartar_vencimiento',
      params: {'p_vencimiento_id': id},
    );
  }

  @override
  Future<ConnectionsStateDto> loadConnections() async {
    final raw = await _client.rpc<Object?>('obtener_estado_conexion_google');
    if (raw is! Map) throw const FormatException('conexiones inválidas');
    return ConnectionsStateDto.fromMap(Map<String, dynamic>.from(raw));
  }

  @override
  Future<Uri> createAuthorizationUrl(
    String service, {
    String? connectionId,
  }) async {
    final response = await _client.functions.invoke(
      'google-oauth-start',
      body: {'servicio': service, 'conexion_id': ?connectionId},
    );
    final data = response.data;
    final rawUrl = data is Map ? data['url'] as String? : null;
    final url = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (url == null || url.scheme != 'https') {
      throw const FormatException('autorización inválida');
    }
    return url;
  }

  @override
  Future<void> disconnect({
    required String connectionId,
    required String service,
  }) async {
    await _client.functions.invoke(
      'google-disconnect',
      body: {'conexion_id': connectionId, 'servicio': service},
    );
  }

  @override
  Future<void> requestSync(List<String> connectionIds) async {
    await _client.functions.invoke(
      'scan-gmail',
      body: {'conexion_ids': connectionIds},
    );
  }
}
