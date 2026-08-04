import 'package:agenkin/di/providers.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/domain/repositories/repositories.dart';
import 'package:agenkin/ui/features/agenda/view_models/agenda_view_model.dart';
import 'package:agenkin/ui/features/settings/view_models/settings_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AgendaRepository implements AgendaRepository {
  int loads = 0;

  @override
  Future<AppResult<List<AgendaEvent>>> loadUpcoming() async {
    loads++;
    return AppResult.success([
      AgendaEvent(
        id: 'event-$loads',
        title: 'Evento',
        description: '',
        date: DateTime(2026, 8, 9),
        allDay: true,
        googleStatus: 'pendiente',
        syncStatus: 'creado',
      ),
    ]);
  }
}

class _PreferencesRepository implements PreferencesRepository {
  AppThemeMode theme = AppThemeMode.system;
  bool notifications = true;

  @override
  Future<bool> loadNotificationsEnabled() async => notifications;

  @override
  Future<AppThemeMode> loadThemeMode() async => theme;

  @override
  Future<void> saveNotificationsEnabled(bool enabled) async {
    notifications = enabled;
  }

  @override
  Future<void> saveThemeMode(AppThemeMode mode) async {
    theme = mode;
  }
}

void main() {
  test('AgendaViewModel carga y refresca mediante el repositorio', () async {
    final repository = _AgendaRepository();
    final container = ProviderContainer(
      overrides: [agendaRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final first = await container.read(agendaViewModelProvider.future);
    expect(first.single.id, 'event-1');

    await container.read(agendaViewModelProvider.notifier).reload();
    expect(container.read(agendaViewModelProvider).value?.single.id, 'event-2');
  });

  test(
    'SettingsViewModel conserva preferencias inmutables y las persiste',
    () async {
      final repository = _PreferencesRepository();
      final container = ProviderContainer(
        overrides: [
          preferencesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(settingsViewModelProvider.future);
      await container
          .read(settingsViewModelProvider.notifier)
          .setTheme(AppThemeMode.dark);
      await container
          .read(settingsViewModelProvider.notifier)
          .setNotificationsEnabled(false);

      final state = container.read(settingsViewModelProvider).requireValue;
      expect(state.themeMode, AppThemeMode.dark);
      expect(state.notificationsEnabled, isFalse);
      expect(repository.theme, AppThemeMode.dark);
      expect(repository.notifications, isFalse);
    },
  );
}
