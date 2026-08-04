import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_models.freezed.dart';

enum AccessStatus { checking, signedOut, active, blocked, failed }

enum AppThemeMode { system, light, dark }

@freezed
abstract class UserProfile with _$UserProfile {
  const UserProfile._();

  const factory UserProfile({
    required String id,
    required String name,
    required String email,
    required String accessStatus,
    String? avatarUrl,
  }) = _UserProfile;

  String get displayName => name.isEmpty ? email.split('@').first : name;
  bool get isActive => accessStatus == 'activo';
}

@freezed
abstract class AccessState with _$AccessState {
  const factory AccessState({
    required AccessStatus status,
    UserProfile? profile,
    String? message,
  }) = _AccessState;
}

@freezed
abstract class AgendaEvent with _$AgendaEvent {
  const AgendaEvent._();

  const factory AgendaEvent({
    required String id,
    required String title,
    required String description,
    required DateTime date,
    required bool allDay,
    required String googleStatus,
    required String syncStatus,
  }) = _AgendaEvent;

  String get googleLabel => switch (googleStatus) {
    'sincronizado' => 'Sincronizado',
    'pendiente' => 'Google pendiente',
    'error' => 'Error de Google',
    _ => 'Sólo en Agenda',
  };
}

@freezed
abstract class Commitment with _$Commitment {
  const factory Commitment({
    required String id,
    required String type,
    required String title,
    required String description,
    required DateTime date,
    required double confidence,
    required String status,
    required bool requiresReview,
    String? time,
    String? emailSubject,
    String? connectionId,
  }) = _Commitment;
}

@freezed
abstract class DashboardSummary with _$DashboardSummary {
  const factory DashboardSummary({
    required int daysUsingAgenKin,
    required int emailsToday,
    required int totalEmails,
    required int pendingReviews,
    required int eventsCreated,
    required String planName,
  }) = _DashboardSummary;
}

@freezed
abstract class GmailConnection with _$GmailConnection {
  const factory GmailConnection({
    required String id,
    required String email,
    required bool connected,
    required String status,
    required bool calendarActive,
    required int pendingTasks,
    required int errorTasks,
    DateTime? lastReadAt,
    String? lastError,
  }) = _GmailConnection;
}

@freezed
abstract class CalendarConnection with _$CalendarConnection {
  const factory CalendarConnection({
    required bool connected,
    required int pendingEvents,
    required int errorEvents,
    String? connectionId,
    String? email,
    DateTime? lastSyncAt,
  }) = _CalendarConnection;
}

@freezed
abstract class ConnectionsState with _$ConnectionsState {
  const ConnectionsState._();

  const factory ConnectionsState({
    required List<GmailConnection> gmailAccounts,
    required int gmailUsed,
    required int gmailLimit,
    required CalendarConnection calendar,
    required bool autoSync,
    required bool autoCreateEvents,
    required double confidenceThreshold,
  }) = _ConnectionsState;

  Map<String, String> get emailsByConnection => {
    for (final account in gmailAccounts) account.id: account.email,
  };
}

@freezed
sealed class AppResult<T> with _$AppResult<T> {
  const factory AppResult.success(T value) = AppSuccess<T>;
  const factory AppResult.failure(String message) = AppFailure<T>;
}

@freezed
abstract class HomeOverview with _$HomeOverview {
  const factory HomeOverview({
    required DashboardSummary summary,
    required List<Commitment> commitments,
    required ConnectionsState connections,
  }) = _HomeOverview;
}

@freezed
abstract class CommitmentsOverview with _$CommitmentsOverview {
  const factory CommitmentsOverview({
    required List<Commitment> commitments,
    required Map<String, String> emailsByConnection,
  }) = _CommitmentsOverview;
}

@freezed
abstract class UserPreferences with _$UserPreferences {
  const factory UserPreferences({
    required AppThemeMode themeMode,
    required bool notificationsEnabled,
  }) = _UserPreferences;
}
