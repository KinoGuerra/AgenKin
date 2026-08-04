import 'package:agenkin/core/config/app_config.dart';
import 'package:agenkin/core/security/secure_session_storage.dart';
import 'package:agenkin/di/providers.dart';
import 'package:agenkin/ui/core/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final config = AppConfig.fromEnvironment();
    await initializeDateFormatting('es_AR');
    await Supabase.initialize(
      url: config.supabaseUrl.toString(),
      publishableKey: config.supabasePublishableKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: SecureSessionStorage(),
      ),
    );

    runApp(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(config)],
        child: const AgenKinApp(),
      ),
    );
  } on ConfigException catch (error) {
    runApp(ConfigurationErrorApp(message: error.message));
  }
}
