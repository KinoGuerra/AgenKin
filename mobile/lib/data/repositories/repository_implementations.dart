import 'package:agenkin/data/models/api_models.dart';
import 'package:agenkin/data/services/platform_services.dart';
import 'package:agenkin/data/services/supabase_services.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/domain/repositories/repositories.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._service);

  final AuthService _service;

  @override
  Stream<AccessState> watchAccess() {
    return _service.watchSessions().asyncMap(_resolveAccess);
  }

  Future<AccessState> _resolveAccess(Session? session) async {
    if (session == null) {
      return const AccessState(status: AccessStatus.signedOut);
    }
    try {
      final validSession = session.isExpired
          ? (await _service.refreshSession()) ?? session
          : session;
      final profile = (await _service.loadProfile(
        validSession.user.id,
      )).toDomain();
      if (!profile.isActive) {
        return AccessState(status: AccessStatus.blocked, profile: profile);
      }
      await _service.registerLastAccess();
      return AccessState(status: AccessStatus.active, profile: profile);
    } on AuthException {
      return const AccessState(status: AccessStatus.signedOut);
    } catch (_) {
      return const AccessState(
        status: AccessStatus.failed,
        message:
            'No pudimos validar tu acceso. Revisá la conexión e intentá nuevamente.',
      );
    }
  }

  @override
  Future<AppResult<void>> signInWithGoogle() async {
    try {
      if (!await _service.signInWithGoogle()) {
        return const AppResult.failure(
          'No se pudo abrir el acceso con Google.',
        );
      }
      return const AppResult.success(null);
    } catch (_) {
      return const AppResult.failure(
        'No se pudo iniciar sesión con Google. Intentá nuevamente.',
      );
    }
  }

  @override
  Future<AppResult<void>> signOut() async {
    try {
      await _service.signOut();
      return const AppResult.success(null);
    } catch (_) {
      return const AppResult.failure('No se pudo cerrar la sesión.');
    }
  }
}

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this._service);
  final PortalService _service;

  @override
  Future<AppResult<DashboardSummary>> load() async {
    try {
      return AppResult.success((await _service.loadDashboard()).toDomain());
    } on FormatException {
      return const AppResult.failure('Tu suscripción no está habilitada.');
    } catch (_) {
      return const AppResult.failure(
        'No pudimos cargar el resumen de AgenKin.',
      );
    }
  }
}

class AgendaRepositoryImpl implements AgendaRepository {
  const AgendaRepositoryImpl(this._service, {this.now = DateTime.now});
  final PortalService _service;
  final DateTime Function() now;

  @override
  Future<AppResult<List<AgendaEvent>>> loadUpcoming() async {
    try {
      final today = _startOfLocalDay(now());
      final result = (await _service.loadUpcomingAgenda())
          .map((item) => item.toDomain())
          .where((item) => !_startOfLocalDay(item.date).isBefore(today))
          .toList(growable: false);
      return AppResult.success(result);
    } catch (_) {
      return const AppResult.failure('No pudimos cargar tu Agenda.');
    }
  }
}

class CommitmentsRepositoryImpl implements CommitmentsRepository {
  const CommitmentsRepositoryImpl(this._service, {this.now = DateTime.now});
  final PortalService _service;
  final DateTime Function() now;

  @override
  Future<AppResult<List<Commitment>>> loadActionable() async {
    try {
      final today = _startOfLocalDay(now());
      final result = (await _service.loadActionableCommitments())
          .map((item) => item.toDomain())
          .where((item) => !_startOfLocalDay(item.date).isBefore(today))
          .toList(growable: false);
      return AppResult.success(result);
    } catch (_) {
      return const AppResult.failure('No pudimos cargar tus compromisos.');
    }
  }

  @override
  Future<AppResult<void>> discard(String id) async {
    try {
      await _service.discardCommitment(id);
      return const AppResult.success(null);
    } catch (_) {
      return const AppResult.failure('No pudimos descartar el compromiso.');
    }
  }
}

DateTime _startOfLocalDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

class ConnectionsRepositoryImpl implements ConnectionsRepository {
  const ConnectionsRepositoryImpl(this._service, this._urlService);

  final PortalService _service;
  final UrlLauncherService _urlService;

  @override
  Future<AppResult<ConnectionsState>> load() async {
    try {
      return AppResult.success((await _service.loadConnections()).toDomain());
    } on FormatException {
      return const AppResult.failure('Tu cuenta no está habilitada.');
    } catch (_) {
      return const AppResult.failure('No pudimos consultar tus conexiones.');
    }
  }

  @override
  Future<AppResult<void>> authorizeGmail() => _authorize('gmail');

  @override
  Future<AppResult<void>> authorizeCalendar(String connectionId) {
    return _authorize('calendar', connectionId: connectionId);
  }

  Future<AppResult<void>> _authorize(
    String service, {
    String? connectionId,
  }) async {
    try {
      final url = await _service.createAuthorizationUrl(
        service,
        connectionId: connectionId,
      );
      if (!await _urlService.open(url)) {
        return const AppResult.failure('No se pudo abrir Google.');
      }
      return const AppResult.success(null);
    } catch (_) {
      return const AppResult.failure(
        'No se pudo iniciar la autorización con Google.',
      );
    }
  }

  @override
  Future<AppResult<void>> disconnect({
    required String connectionId,
    required String service,
  }) async {
    try {
      await _service.disconnect(connectionId: connectionId, service: service);
      return const AppResult.success(null);
    } catch (_) {
      return const AppResult.failure('No pudimos actualizar la conexión.');
    }
  }

  @override
  Future<AppResult<void>> requestSync(List<String> connectionIds) async {
    try {
      await _service.requestSync(connectionIds);
      return const AppResult.success(null);
    } catch (_) {
      return const AppResult.failure(
        'No pudimos solicitar la actualización. Esperá un minuto e intentá nuevamente.',
      );
    }
  }
}

class PreferencesRepositoryImpl implements PreferencesRepository {
  const PreferencesRepositoryImpl(this._service);
  final LocalPreferencesService _service;

  @override
  Future<AppThemeMode> loadThemeMode() => _service.loadThemeMode();

  @override
  Future<void> saveThemeMode(AppThemeMode mode) {
    return _service.saveThemeMode(mode);
  }

  @override
  Future<bool> loadNotificationsEnabled() {
    return _service.loadNotificationsEnabled();
  }

  @override
  Future<void> saveNotificationsEnabled(bool enabled) {
    return _service.saveNotificationsEnabled(enabled);
  }
}

extension UserProfileDtoMapping on UserProfileDto {
  UserProfile toDomain() => UserProfile(
    id: id,
    name: name,
    email: email,
    accessStatus: accessStatus,
    avatarUrl: avatarUrl,
  );
}

extension DashboardSummaryDtoMapping on DashboardSummaryDto {
  DashboardSummary toDomain() => DashboardSummary(
    daysUsingAgenKin: daysUsingAgenKin,
    emailsToday: emailsToday,
    totalEmails: totalEmails,
    pendingReviews: pendingReviews,
    eventsCreated: eventsCreated,
    planName: planName,
  );
}

extension AgendaEventDtoMapping on AgendaEventDto {
  AgendaEvent toDomain() => AgendaEvent(
    id: id,
    title: title,
    description: description,
    date: date,
    allDay: allDay,
    googleStatus: googleStatus,
    syncStatus: syncStatus,
  );
}

extension CommitmentDtoMapping on CommitmentDto {
  Commitment toDomain() => Commitment(
    id: id,
    type: type,
    title: title,
    description: description,
    date: date,
    confidence: confidence,
    status: status,
    requiresReview: requiresReview,
    time: time,
    emailSubject: emailSubject,
    connectionId: connectionId,
  );
}

extension GmailConnectionDtoMapping on GmailConnectionDto {
  GmailConnection toDomain() => GmailConnection(
    id: id,
    email: email,
    connected: connected,
    status: status,
    calendarActive: calendarActive,
    pendingTasks: pendingTasks,
    errorTasks: errorTasks,
    lastReadAt: lastReadAt,
    lastError: lastError,
  );
}

extension CalendarConnectionDtoMapping on CalendarConnectionDto {
  CalendarConnection toDomain() => CalendarConnection(
    connected: connected,
    pendingEvents: pendingEvents,
    errorEvents: errorEvents,
    connectionId: connectionId,
    email: email,
    lastSyncAt: lastSyncAt,
  );
}

extension ConnectionsStateDtoMapping on ConnectionsStateDto {
  ConnectionsState toDomain() => ConnectionsState(
    gmailAccounts: gmailAccounts
        .map((account) => account.toDomain())
        .toList(growable: false),
    gmailUsed: gmailUsed,
    gmailLimit: gmailLimit,
    calendar: calendar.toDomain(),
    autoSync: autoSync,
    autoCreateEvents: autoCreateEvents,
    confidenceThreshold: confidenceThreshold,
  );
}
