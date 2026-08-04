import 'package:agenkin/di/providers.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/ui/core/view_model_helpers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectionsViewModelProvider =
    AsyncNotifierProvider<ConnectionsViewModel, ConnectionsState>(
      ConnectionsViewModel.new,
    );

class ConnectionsViewModel extends AsyncNotifier<ConnectionsState> {
  @override
  Future<ConnectionsState> build() async {
    return requireSuccess(
      await ref.watch(connectionsRepositoryProvider).load(),
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> authorizeGmail() =>
      _run(() => ref.read(connectionsRepositoryProvider).authorizeGmail());

  Future<void> authorizeCalendar(String connectionId) => _run(
    () =>
        ref.read(connectionsRepositoryProvider).authorizeCalendar(connectionId),
  );

  Future<void> disconnect({
    required String connectionId,
    required String service,
  }) => _run(
    () => ref
        .read(connectionsRepositoryProvider)
        .disconnect(connectionId: connectionId, service: service),
  );

  Future<void> requestSync(List<String> connectionIds) => _run(
    () => ref.read(connectionsRepositoryProvider).requestSync(connectionIds),
  );

  Future<void> _run(Future<AppResult<void>> Function() command) async {
    if (state.isLoading) return;
    final previous = state;
    state = const AsyncLoading();
    try {
      requireSuccess(await command());
      state = await AsyncValue.guard(_load);
    } catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<ConnectionsState> _load() async {
    return requireSuccess(await ref.read(connectionsRepositoryProvider).load());
  }
}
