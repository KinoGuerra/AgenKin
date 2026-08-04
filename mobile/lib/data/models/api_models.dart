import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_models.freezed.dart';

@freezed
abstract class UserProfileDto with _$UserProfileDto {
  const factory UserProfileDto({
    required String id,
    required String name,
    required String email,
    required String accessStatus,
    String? avatarUrl,
  }) = _UserProfileDto;

  factory UserProfileDto.fromMap(Map<String, dynamic> map) => UserProfileDto(
    id: map['id'] as String,
    name: (map['nombre_completo'] as String?)?.trim() ?? '',
    email: map['email'] as String? ?? '',
    avatarUrl: map['avatar_url'] as String?,
    accessStatus: map['estado_acceso'] as String? ?? 'bloqueado',
  );
}

@freezed
abstract class AgendaEventDto with _$AgendaEventDto {
  const factory AgendaEventDto({
    required String id,
    required String title,
    required String description,
    required DateTime date,
    required bool allDay,
    required String googleStatus,
    required String syncStatus,
  }) = _AgendaEventDto;

  factory AgendaEventDto.fromMap(Map<String, dynamic> map) => AgendaEventDto(
    id: map['id'] as String,
    title: map['titulo'] as String? ?? 'Evento sin título',
    description: map['descripcion'] as String? ?? '',
    date: DateTime.parse(map['fecha_evento'] as String).toLocal(),
    allDay: map['es_dia_completo'] as bool? ?? true,
    googleStatus: map['estado_google'] as String? ?? 'no_conectado',
    syncStatus: map['estado_sincronizacion'] as String? ?? 'creado',
  );
}

@freezed
abstract class CommitmentDto with _$CommitmentDto {
  const factory CommitmentDto({
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
  }) = _CommitmentDto;

  factory CommitmentDto.fromMap(Map<String, dynamic> map) {
    final rawEmail = map['correos_procesados'];
    final email = rawEmail is List
        ? (rawEmail.isEmpty ? null : rawEmail.first)
        : rawEmail;
    final emailMap = email is Map ? Map<String, dynamic>.from(email) : null;
    return CommitmentDto(
      id: map['id'] as String,
      type: map['tipo'] as String? ?? 'otro',
      title: map['titulo'] as String? ?? 'Compromiso',
      description: map['descripcion'] as String? ?? '',
      date: DateTime.parse(map['fecha_vencimiento'] as String),
      time: map['hora_vencimiento'] as String?,
      confidence: (map['confianza'] as num?)?.toDouble() ?? 0,
      status: map['estado'] as String? ?? 'pendiente',
      requiresReview: map['requiere_revision'] as bool? ?? true,
      emailSubject: emailMap?['asunto'] as String?,
      connectionId: emailMap?['conexion_google_id'] as String?,
    );
  }
}

@freezed
abstract class DashboardSummaryDto with _$DashboardSummaryDto {
  const factory DashboardSummaryDto({
    required int daysUsingAgenKin,
    required int emailsToday,
    required int totalEmails,
    required int pendingReviews,
    required int eventsCreated,
    required String planName,
  }) = _DashboardSummaryDto;

  factory DashboardSummaryDto.fromMap(Map<String, dynamic> map) {
    final subscription = Map<String, dynamic>.from(
      map['suscripcion'] as Map? ?? const {},
    );
    return DashboardSummaryDto(
      daysUsingAgenKin: (map['dias_usando_agenkin'] as num?)?.toInt() ?? 0,
      emailsToday: (map['correos_analizados_hoy'] as num?)?.toInt() ?? 0,
      totalEmails: (map['correos_analizados_total'] as num?)?.toInt() ?? 0,
      pendingReviews: (map['pendientes_revision'] as num?)?.toInt() ?? 0,
      eventsCreated: (map['eventos_creados'] as num?)?.toInt() ?? 0,
      planName: subscription['plan'] as String? ?? 'Sin plan',
    );
  }
}

@freezed
abstract class GmailConnectionDto with _$GmailConnectionDto {
  const factory GmailConnectionDto({
    required String id,
    required String email,
    required bool connected,
    required String status,
    required bool calendarActive,
    required int pendingTasks,
    required int errorTasks,
    DateTime? lastReadAt,
    String? lastError,
  }) = _GmailConnectionDto;

  factory GmailConnectionDto.fromMap(Map<String, dynamic> map) =>
      GmailConnectionDto(
        id: map['id'] as String,
        email: map['email'] as String? ?? 'Cuenta de Google',
        connected: map['conectado'] as bool? ?? false,
        status: map['estado'] as String? ?? 'desconectada',
        calendarActive: map['calendar_activo'] as bool? ?? false,
        pendingTasks: (map['tareas_pendientes'] as num?)?.toInt() ?? 0,
        errorTasks: (map['tareas_error'] as num?)?.toInt() ?? 0,
        lastReadAt: _date(map['ultima_lectura_en']),
        lastError: map['error_ultima_sincronizacion'] as String?,
      );
}

@freezed
abstract class CalendarConnectionDto with _$CalendarConnectionDto {
  const factory CalendarConnectionDto({
    required bool connected,
    required int pendingEvents,
    required int errorEvents,
    String? connectionId,
    String? email,
    DateTime? lastSyncAt,
  }) = _CalendarConnectionDto;

  factory CalendarConnectionDto.fromMap(Map<String, dynamic> map) =>
      CalendarConnectionDto(
        connected: map['conectado'] as bool? ?? false,
        pendingEvents: (map['eventos_pendientes'] as num?)?.toInt() ?? 0,
        errorEvents: (map['eventos_error'] as num?)?.toInt() ?? 0,
        connectionId: map['conexion_id'] as String?,
        email: map['email'] as String?,
        lastSyncAt: _date(map['ultima_sincronizacion_en']),
      );
}

@freezed
abstract class ConnectionsStateDto with _$ConnectionsStateDto {
  const factory ConnectionsStateDto({
    required List<GmailConnectionDto> gmailAccounts,
    required int gmailUsed,
    required int gmailLimit,
    required CalendarConnectionDto calendar,
    required bool autoSync,
    required bool autoCreateEvents,
    required double confidenceThreshold,
  }) = _ConnectionsStateDto;

  factory ConnectionsStateDto.fromMap(Map<String, dynamic> map) {
    final gmail = Map<String, dynamic>.from(map['gmail'] as Map? ?? const {});
    final calendar = Map<String, dynamic>.from(
      map['calendar'] as Map? ?? const {},
    );
    return ConnectionsStateDto(
      gmailAccounts: (gmail['cuentas'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                GmailConnectionDto.fromMap(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false),
      gmailUsed: (gmail['usadas'] as num?)?.toInt() ?? 0,
      gmailLimit: (gmail['limite'] as num?)?.toInt() ?? 1,
      calendar: CalendarConnectionDto.fromMap(calendar),
      autoSync: map['sincronizacion_automatica'] as bool? ?? false,
      autoCreateEvents: map['creacion_automatica_eventos'] as bool? ?? false,
      confidenceThreshold:
          (map['umbral_confianza_automatica'] as num?)?.toDouble() ?? 0.9,
    );
  }
}

DateTime? _date(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}
