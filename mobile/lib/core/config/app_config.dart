class ConfigException implements Exception {
  const ConfigException(this.message);

  final String message;
}

enum AppEnvironment { development, production }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.authRedirectUrl,
  });

  factory AppConfig.fromEnvironment() {
    return AppConfig.fromMap({
      'APP_ENV': const String.fromEnvironment('APP_ENV'),
      'SUPABASE_URL': const String.fromEnvironment('SUPABASE_URL'),
      'SUPABASE_PUBLISHABLE_KEY': const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      'AUTH_REDIRECT_URL': const String.fromEnvironment('AUTH_REDIRECT_URL'),
    });
  }

  factory AppConfig.fromMap(Map<String, String> values) {
    final environment = switch (values['APP_ENV']) {
      'development' => AppEnvironment.development,
      'production' => AppEnvironment.production,
      _ => throw const ConfigException(
        'APP_ENV debe ser development o production.',
      ),
    };
    final url = Uri.tryParse(values['SUPABASE_URL'] ?? '');
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw const ConfigException(
        'SUPABASE_URL debe ser una URL HTTPS válida.',
      );
    }
    final key = values['SUPABASE_PUBLISHABLE_KEY'] ?? '';
    if (!key.startsWith('sb_publishable_') || key.length < 24) {
      throw const ConfigException(
        'SUPABASE_PUBLISHABLE_KEY no es una clave publicable válida.',
      );
    }
    final redirect = Uri.tryParse(values['AUTH_REDIRECT_URL'] ?? '');
    if (redirect == null ||
        redirect.scheme != 'com.kinovich.agenkin' ||
        redirect.host != 'login-callback') {
      throw const ConfigException(
        'AUTH_REDIRECT_URL debe usar com.kinovich.agenkin://login-callback/.',
      );
    }

    return AppConfig(
      environment: environment,
      supabaseUrl: url,
      supabasePublishableKey: key,
      authRedirectUrl: redirect,
    );
  }

  final AppEnvironment environment;
  final Uri supabaseUrl;
  final String supabasePublishableKey;
  final Uri authRedirectUrl;
}
