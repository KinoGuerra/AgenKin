import 'package:agenkin/domain/models/app_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

abstract interface class UrlLauncherService {
  Future<bool> open(Uri url);
}

class ExternalUrlService implements UrlLauncherService {
  const ExternalUrlService();

  @override
  Future<bool> open(Uri url) {
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

abstract interface class LocalPreferencesService {
  Future<AppThemeMode> loadThemeMode();
  Future<void> saveThemeMode(AppThemeMode mode);
  Future<bool> loadNotificationsEnabled();
  Future<void> saveNotificationsEnabled(bool enabled);
}

abstract interface class PreferencesStore {
  Future<String?> getString(String key);
  Future<bool?> getBool(String key);
  Future<void> setString(String key, String value);
  Future<void> setBool(String key, bool value);
}

class SharedPreferencesStore implements PreferencesStore {
  SharedPreferencesStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<bool?> getBool(String key) => _preferences.getBool(key);

  @override
  Future<void> setString(String key, String value) {
    return _preferences.setString(key, value);
  }

  @override
  Future<void> setBool(String key, bool value) {
    return _preferences.setBool(key, value);
  }
}

class PreferencesService implements LocalPreferencesService {
  PreferencesService({PreferencesStore? store})
    : _store = store ?? SharedPreferencesStore();

  static const _themeKey = 'theme_mode';
  static const _notificationsKey = 'notifications_enabled';

  final PreferencesStore _store;

  @override
  Future<AppThemeMode> loadThemeMode() async {
    return switch (await _store.getString(_themeKey)) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.system,
    };
  }

  @override
  Future<void> saveThemeMode(AppThemeMode mode) {
    return _store.setString(_themeKey, mode.name);
  }

  @override
  Future<bool> loadNotificationsEnabled() async {
    return await _store.getBool(_notificationsKey) ?? true;
  }

  @override
  Future<void> saveNotificationsEnabled(bool enabled) {
    return _store.setBool(_notificationsKey, enabled);
  }
}
