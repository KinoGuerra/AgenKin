import 'package:agenkin/core/config/app_config.dart';
import 'package:agenkin/data/repositories/repository_implementations.dart';
import 'package:agenkin/data/services/platform_services.dart';
import 'package:agenkin/data/services/supabase_services.dart';
import 'package:agenkin/domain/repositories/repositories.dart';
import 'package:agenkin/domain/use_cases/overview_use_cases.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw StateError('AppConfig no fue inicializada.');
});

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final supabaseAuthServiceProvider = Provider<AuthService>((ref) {
  return SupabaseAuthService(
    ref.watch(supabaseClientProvider),
    ref.watch(appConfigProvider),
  );
});

final supabasePortalServiceProvider = Provider<PortalService>((ref) {
  return SupabasePortalService(ref.watch(supabaseClientProvider));
});

final externalUrlServiceProvider = Provider<UrlLauncherService>((ref) {
  return const ExternalUrlService();
});

final preferencesServiceProvider = Provider<LocalPreferencesService>((ref) {
  return PreferencesService();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(supabaseAuthServiceProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(ref.watch(supabasePortalServiceProvider));
});

final agendaRepositoryProvider = Provider<AgendaRepository>((ref) {
  return AgendaRepositoryImpl(ref.watch(supabasePortalServiceProvider));
});

final commitmentsRepositoryProvider = Provider<CommitmentsRepository>((ref) {
  return CommitmentsRepositoryImpl(ref.watch(supabasePortalServiceProvider));
});

final connectionsRepositoryProvider = Provider<ConnectionsRepository>((ref) {
  return ConnectionsRepositoryImpl(
    ref.watch(supabasePortalServiceProvider),
    ref.watch(externalUrlServiceProvider),
  );
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepositoryImpl(ref.watch(preferencesServiceProvider));
});

final loadHomeUseCaseProvider = Provider<LoadHomeUseCase>((ref) {
  return LoadHomeUseCase(
    ref.watch(dashboardRepositoryProvider),
    ref.watch(commitmentsRepositoryProvider),
    ref.watch(connectionsRepositoryProvider),
  );
});

final loadCommitmentsUseCaseProvider = Provider<LoadCommitmentsUseCase>((ref) {
  return LoadCommitmentsUseCase(
    ref.watch(commitmentsRepositoryProvider),
    ref.watch(connectionsRepositoryProvider),
  );
});
