import 'package:agenkin/data/models/api_models.dart';
import 'package:agenkin/data/repositories/repository_implementations.dart';
import 'package:agenkin/data/services/platform_services.dart';
import 'package:agenkin/data/services/supabase_services.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPreferencesStore implements PreferencesStore {
  final Map<String, Object> values = {};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;

  @override
  Future<String?> getString(String key) async => values[key] as String?;

  @override
  Future<void> setBool(String key, bool value) async {
    values[key] = value;
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _FakePortalService implements PortalService {
  bool failAgenda = false;
  List<AgendaEventDto> agendaEvents = [
    AgendaEventDto(
      id: 'event-1',
      title: 'Vencimiento',
      description: '',
      date: DateTime(2026, 8, 9),
      allDay: true,
      googleStatus: 'sincronizado',
      syncStatus: 'creado',
    ),
  ];
  List<CommitmentDto> commitments = const [];
  Uri authorizationUrl = Uri.parse(
    'https://accounts.google.com/o/oauth2/v2/auth',
  );

  @override
  Future<List<AgendaEventDto>> loadUpcomingAgenda() async {
    if (failAgenda) throw StateError('detalle privado');
    return agendaEvents;
  }

  @override
  Future<Uri> createAuthorizationUrl(
    String service, {
    String? connectionId,
  }) async => authorizationUrl;

  @override
  Future<void> discardCommitment(String id) async {}

  @override
  Future<void> disconnect({
    required String connectionId,
    required String service,
  }) async {}

  @override
  Future<List<CommitmentDto>> loadActionableCommitments() async => commitments;

  @override
  Future<ConnectionsStateDto> loadConnections() async => ConnectionsStateDto(
    gmailAccounts: const [],
    gmailUsed: 0,
    gmailLimit: 1,
    calendar: const CalendarConnectionDto(
      connected: false,
      pendingEvents: 0,
      errorEvents: 0,
    ),
    autoSync: false,
    autoCreateEvents: false,
    confidenceThreshold: 0.9,
  );

  @override
  Future<DashboardSummaryDto> loadDashboard() async =>
      const DashboardSummaryDto(
        daysUsingAgenKin: 1,
        emailsToday: 2,
        totalEmails: 3,
        pendingReviews: 0,
        eventsCreated: 1,
        planName: 'AgenKin',
      );

  @override
  Future<void> requestSync(List<String> connectionIds) async {}
}

class _FakeUrlLauncher implements UrlLauncherService {
  bool opened = false;

  @override
  Future<bool> open(Uri url) async {
    opened = true;
    return true;
  }
}

void main() {
  test('PreferencesService persiste únicamente preferencias locales', () async {
    final service = PreferencesService(store: _MemoryPreferencesStore());

    expect(await service.loadThemeMode(), AppThemeMode.system);
    expect(await service.loadNotificationsEnabled(), isTrue);
    await service.saveThemeMode(AppThemeMode.dark);
    await service.saveNotificationsEnabled(false);
    expect(await service.loadThemeMode(), AppThemeMode.dark);
    expect(await service.loadNotificationsEnabled(), isFalse);
  });

  test(
    'AgendaRepository transforma DTOs sin filtrar nombres SQL al dominio',
    () async {
      final result = await AgendaRepositoryImpl(
        _FakePortalService(),
      ).loadUpcoming();

      expect(result, isA<AppSuccess<List<AgendaEvent>>>());
      final events = (result as AppSuccess<List<AgendaEvent>>).value;
      expect(events.single.googleLabel, 'Sincronizado');
    },
  );

  test(
    'AgendaRepository reemplaza errores internos por un mensaje seguro',
    () async {
      final service = _FakePortalService()..failAgenda = true;
      final result = await AgendaRepositoryImpl(service).loadUpcoming();

      expect(result, isA<AppFailure<List<AgendaEvent>>>());
      expect(
        (result as AppFailure<List<AgendaEvent>>).message,
        'No pudimos cargar tu Agenda.',
      );
    },
  );

  test('los repositorios descartan fechas anteriores al día actual', () async {
    final service = _FakePortalService()
      ..agendaEvents = [
        AgendaEventDto(
          id: 'past-event',
          title: 'Evento vencido',
          description: '',
          date: DateTime(2026, 6, 14),
          allDay: true,
          googleStatus: 'sincronizado',
          syncStatus: 'creado',
        ),
        AgendaEventDto(
          id: 'today-event',
          title: 'Evento de hoy',
          description: '',
          date: DateTime(2026, 8, 3),
          allDay: true,
          googleStatus: 'pendiente',
          syncStatus: 'creado',
        ),
      ]
      ..commitments = [
        CommitmentDto(
          id: 'past-commitment',
          type: 'pago',
          title: 'Compromiso vencido',
          description: '',
          date: DateTime(2026, 6, 14),
          confidence: 0.97,
          status: 'evento_creado',
          requiresReview: false,
        ),
        CommitmentDto(
          id: 'future-commitment',
          type: 'pago',
          title: 'Compromiso futuro',
          description: '',
          date: DateTime(2026, 8, 10),
          confidence: 0.97,
          status: 'evento_creado',
          requiresReview: false,
        ),
      ];
    DateTime now() => DateTime(2026, 8, 3, 18);

    final agenda = await AgendaRepositoryImpl(service, now: now).loadUpcoming();
    final commitments = await CommitmentsRepositoryImpl(
      service,
      now: now,
    ).loadActionable();

    expect(
      (agenda as AppSuccess<List<AgendaEvent>>).value.single.id,
      'today-event',
    );
    expect(
      (commitments as AppSuccess<List<Commitment>>).value.single.id,
      'future-commitment',
    );
  });

  test(
    'ConnectionsRepository abre únicamente la URL validada por el Service',
    () async {
      final launcher = _FakeUrlLauncher();
      final result = await ConnectionsRepositoryImpl(
        _FakePortalService(),
        launcher,
      ).authorizeGmail();

      expect(result, isA<AppSuccess<void>>());
      expect(launcher.opened, isTrue);
    },
  );
}
