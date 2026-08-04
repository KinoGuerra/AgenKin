import 'package:agenkin/data/models/api_models.dart';
import 'package:agenkin/data/repositories/repository_implementations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('convierte un perfil real de Supabase', () {
    final profile = UserProfileDto.fromMap({
      'id': 'user-1',
      'nombre_completo': 'Kino',
      'email': 'kino@example.com',
      'estado_acceso': 'activo',
    }).toDomain();
    expect(profile.isActive, isTrue);
    expect(profile.displayName, 'Kino');
  });

  test('convierte un evento y expone el estado de Google', () {
    final event = AgendaEventDto.fromMap({
      'id': 'event-1',
      'titulo': 'Pagar tarjeta',
      'descripcion': '',
      'fecha_evento': '2026-08-09T03:00:00.000Z',
      'es_dia_completo': true,
      'estado_google': 'pendiente',
      'estado_sincronizacion': 'creado',
    }).toDomain();
    expect(event.title, 'Pagar tarjeta');
    expect(event.googleLabel, 'Google pendiente');
  });

  test('convierte un compromiso con el correo de origen', () {
    final item = CommitmentDto.fromMap({
      'id': 'commitment-1',
      'tipo': 'pago',
      'titulo': 'Factura',
      'fecha_vencimiento': '2026-08-09',
      'confianza': 0.94,
      'estado': 'pendiente',
      'requiere_revision': false,
      'correos_procesados': {
        'asunto': 'Tu factura',
        'conexion_google_id': 'connection-1',
      },
    }).toDomain();
    expect(item.emailSubject, 'Tu factura');
    expect(item.connectionId, 'connection-1');
    expect(item.confidence, 0.94);
  });

  test('convierte los contratos JSON de panel y conexiones', () {
    final summary = DashboardSummaryDto.fromMap({
      'dias_usando_agenkin': 4,
      'correos_analizados_hoy': 8,
      'correos_analizados_total': 30,
      'pendientes_revision': 2,
      'eventos_creados': 3,
      'suscripcion': {'plan': 'AgenKin'},
    }).toDomain();
    final connections = ConnectionsStateDto.fromMap({
      'gmail': {
        'usadas': 1,
        'limite': 3,
        'cuentas': [
          {
            'id': 'connection-1',
            'email': 'kino@example.com',
            'conectado': true,
            'estado': 'activa',
          },
        ],
      },
      'calendar': {'conectado': false},
      'umbral_confianza_automatica': 0.9,
    }).toDomain();
    expect(summary.planName, 'AgenKin');
    expect(connections.gmailAccounts.single.email, 'kino@example.com');
    expect(connections.gmailLimit, 3);
  });
}
