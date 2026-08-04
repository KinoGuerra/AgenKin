import 'package:agenkin/di/providers.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/domain/repositories/repositories.dart';
import 'package:agenkin/ui/core/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository(this.state);
  final AccessState state;

  @override
  Stream<AccessState> watchAccess() => Stream.value(state);

  @override
  Future<AppResult<void>> signInWithGoogle() async =>
      const AppResult.success(null);

  @override
  Future<AppResult<void>> signOut() async => const AppResult.success(null);
}

class _FakeDashboardRepository implements DashboardRepository {
  @override
  Future<AppResult<DashboardSummary>> load() async =>
      AppResult.success(_summary);
}

class _FakeAgendaRepository implements AgendaRepository {
  @override
  Future<AppResult<List<AgendaEvent>>> loadUpcoming() async =>
      const AppResult.success([]);
}

class _FakeCommitmentsRepository implements CommitmentsRepository {
  @override
  Future<AppResult<void>> discard(String id) async =>
      const AppResult.success(null);

  @override
  Future<AppResult<List<Commitment>>> loadActionable() async =>
      const AppResult.success([]);
}

class _FakeConnectionsRepository implements ConnectionsRepository {
  @override
  Future<AppResult<ConnectionsState>> load() async =>
      const AppResult.success(_connections);

  @override
  Future<AppResult<void>> authorizeCalendar(String connectionId) async =>
      const AppResult.success(null);

  @override
  Future<AppResult<void>> authorizeGmail() async =>
      const AppResult.success(null);

  @override
  Future<AppResult<void>> disconnect({
    required String connectionId,
    required String service,
  }) async => const AppResult.success(null);

  @override
  Future<AppResult<void>> requestSync(List<String> connectionIds) async =>
      const AppResult.success(null);
}

class _FakePreferencesRepository implements PreferencesRepository {
  @override
  Future<bool> loadNotificationsEnabled() async => true;

  @override
  Future<AppThemeMode> loadThemeMode() async => AppThemeMode.light;

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {}

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async {}
}

const _profile = UserProfile(
  id: 'user-1',
  name: 'Kino',
  email: 'kino@example.com',
  accessStatus: 'activo',
);

const _summary = DashboardSummary(
  daysUsingAgenKin: 1,
  emailsToday: 0,
  totalEmails: 0,
  pendingReviews: 0,
  eventsCreated: 0,
  planName: 'Prueba',
);

const _connections = ConnectionsState(
  gmailAccounts: [],
  gmailUsed: 0,
  gmailLimit: 1,
  calendar: CalendarConnection(
    connected: false,
    pendingEvents: 0,
    errorEvents: 0,
  ),
  autoSync: false,
  autoCreateEvents: false,
  confidenceThreshold: 0.9,
);

Widget _testApp(AccessState state) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository(state)),
      dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepository()),
      agendaRepositoryProvider.overrideWithValue(_FakeAgendaRepository()),
      commitmentsRepositoryProvider.overrideWithValue(
        _FakeCommitmentsRepository(),
      ),
      connectionsRepositoryProvider.overrideWithValue(
        _FakeConnectionsRepository(),
      ),
      preferencesRepositoryProvider.overrideWithValue(
        _FakePreferencesRepository(),
      ),
    ],
    child: const AgenKinApp(),
  );
}

void main() {
  testWidgets('una sesión ausente muestra login sin mostrar el portal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(const AccessState(status: AccessStatus.signedOut)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('una cuenta bloqueada muestra el estado restringido', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const AccessState(status: AccessStatus.blocked, profile: _profile),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Acceso restringido'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('la navegación inferior abre Agenda', (tester) async {
    await tester.pumpWidget(
      _testApp(
        const AccessState(status: AccessStatus.active, profile: _profile),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agenda').last);
    await tester.pumpAndSettle();

    expect(find.text('Tu Agenda está al día'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
