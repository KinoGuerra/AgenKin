import 'package:agenkin/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const valid = {
    'APP_ENV': 'development',
    'SUPABASE_URL': 'https://example.supabase.co',
    'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_12345678901234567890',
    'AUTH_REDIRECT_URL': 'com.kinovich.agenkin://login-callback/',
  };

  test('crea una configuración pública válida', () {
    final config = AppConfig.fromMap(valid);
    expect(config.environment, AppEnvironment.development);
    expect(config.supabaseUrl.host, 'example.supabase.co');
  });

  test('rechaza una clave ausente o secreta', () {
    expect(
      () => AppConfig.fromMap({...valid, 'SUPABASE_PUBLISHABLE_KEY': ''}),
      throwsA(isA<ConfigException>()),
    );
    expect(
      () => AppConfig.fromMap({
        ...valid,
        'SUPABASE_PUBLISHABLE_KEY': 'service_role_no_permitida',
      }),
      throwsA(isA<ConfigException>()),
    );
  });

  test('exige el deep link registrado por la aplicación', () {
    expect(
      () => AppConfig.fromMap({
        ...valid,
        'AUTH_REDIRECT_URL': 'https://example.com/callback',
      }),
      throwsA(isA<ConfigException>()),
    );
  });
}
