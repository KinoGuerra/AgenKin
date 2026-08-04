import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/domain/repositories/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.states);

  final List<AccessState> states;
  bool signedOut = false;

  @override
  Stream<AccessState> watchAccess() => Stream.fromIterable(states);

  @override
  Future<AppResult<void>> signInWithGoogle() async =>
      const AppResult.success(null);

  @override
  Future<AppResult<void>> signOut() async {
    signedOut = true;
    return const AppResult.success(null);
  }
}

void main() {
  test('expone explícitamente una sesión ausente', () async {
    final repository = FakeAuthRepository(const [
      AccessState(status: AccessStatus.signedOut),
    ]);
    expect(
      (await repository.watchAccess().first).status,
      AccessStatus.signedOut,
    );
  });

  test('conserva el perfil de una cuenta bloqueada', () async {
    const profile = UserProfile(
      id: 'user-1',
      name: 'Kino',
      email: 'kino@example.com',
      accessStatus: 'bloqueado',
    );
    final repository = FakeAuthRepository(const [
      AccessState(status: AccessStatus.blocked, profile: profile),
    ]);
    final state = await repository.watchAccess().first;
    expect(state.status, AccessStatus.blocked);
    expect(state.profile?.email, 'kino@example.com');
  });
}
