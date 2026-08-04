import 'package:agenkin/domain/models/app_models.dart';

abstract interface class AuthRepository {
  Stream<AccessState> watchAccess();
  Future<AppResult<void>> signInWithGoogle();
  Future<AppResult<void>> signOut();
}

abstract interface class DashboardRepository {
  Future<AppResult<DashboardSummary>> load();
}

abstract interface class AgendaRepository {
  Future<AppResult<List<AgendaEvent>>> loadUpcoming();
}

abstract interface class CommitmentsRepository {
  Future<AppResult<List<Commitment>>> loadActionable();
  Future<AppResult<void>> discard(String id);
}

abstract interface class ConnectionsRepository {
  Future<AppResult<ConnectionsState>> load();
  Future<AppResult<void>> authorizeGmail();
  Future<AppResult<void>> authorizeCalendar(String connectionId);
  Future<AppResult<void>> disconnect({
    required String connectionId,
    required String service,
  });
  Future<AppResult<void>> requestSync(List<String> connectionIds);
}

abstract interface class PreferencesRepository {
  Future<AppThemeMode> loadThemeMode();
  Future<void> saveThemeMode(AppThemeMode mode);
  Future<bool> loadNotificationsEnabled();
  Future<void> saveNotificationsEnabled(bool enabled);
}
