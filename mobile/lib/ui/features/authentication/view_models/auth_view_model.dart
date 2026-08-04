import 'package:agenkin/di/providers.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/ui/core/view_model_helpers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final accessStateProvider = StreamProvider<AccessState>((ref) {
  return ref.watch(authRepositoryProvider).watchAccess();
});

final currentProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(accessStateProvider).value?.profile;
});

final authViewModelProvider = NotifierProvider<AuthViewModel, AsyncValue<void>>(
  AuthViewModel.new,
);

class AuthViewModel extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<void> signInWithGoogle() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      requireSuccess(await ref.read(authRepositoryProvider).signInWithGoogle());
    });
  }

  Future<void> signOut() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      requireSuccess(await ref.read(authRepositoryProvider).signOut());
    });
  }

  void retryAccess() => ref.invalidate(accessStateProvider);
}
