import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/ui/core/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('una sesión ausente siempre vuelve al login', () {
    expect(accessRedirect(AccessStatus.signedOut, '/inicio'), '/login');
    expect(accessRedirect(AccessStatus.signedOut, '/login'), isNull);
  });

  test('una cuenta bloqueada nunca entra al portal', () {
    expect(
      accessRedirect(AccessStatus.blocked, '/agenda'),
      '/acceso-restringido',
    );
  });

  test('la validación inicial conserva el splash sin mostrar contenido', () {
    expect(accessRedirect(AccessStatus.checking, '/inicio'), '/splash');
    expect(accessRedirect(AccessStatus.checking, '/splash'), isNull);
  });

  test('una sesión activa sale de las rutas de autenticación', () {
    expect(accessRedirect(AccessStatus.active, '/login'), '/inicio');
    expect(accessRedirect(AccessStatus.active, '/agenda'), isNull);
  });
}
