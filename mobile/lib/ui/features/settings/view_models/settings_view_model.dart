import 'package:agenkin/di/providers.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final settingsViewModelProvider =
    AsyncNotifierProvider<SettingsViewModel, UserPreferences>(
      SettingsViewModel.new,
    );

final themeModeProvider = Provider<ThemeMode>((ref) {
  final mode = ref.watch(settingsViewModelProvider).value?.themeMode;
  return switch (mode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});

class SettingsViewModel extends AsyncNotifier<UserPreferences> {
  @override
  Future<UserPreferences> build() async {
    final repository = ref.watch(preferencesRepositoryProvider);
    final theme = await repository.loadThemeMode();
    final notifications = await repository.loadNotificationsEnabled();
    return UserPreferences(
      themeMode: theme,
      notificationsEnabled: notifications,
    );
  }

  Future<void> setTheme(AppThemeMode mode) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(themeMode: mode));
    try {
      await ref.read(preferencesRepositoryProvider).saveThemeMode(mode);
    } catch (error, stackTrace) {
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(notificationsEnabled: enabled));
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .saveNotificationsEnabled(enabled);
    } catch (error, stackTrace) {
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
