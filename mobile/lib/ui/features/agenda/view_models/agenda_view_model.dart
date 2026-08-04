import 'package:agenkin/di/providers.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/ui/core/view_model_helpers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final agendaViewModelProvider =
    AsyncNotifierProvider<AgendaViewModel, List<AgendaEvent>>(
      AgendaViewModel.new,
    );

class AgendaViewModel extends AsyncNotifier<List<AgendaEvent>> {
  @override
  Future<List<AgendaEvent>> build() async {
    return requireSuccess(
      await ref.watch(agendaRepositoryProvider).loadUpcoming(),
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async => requireSuccess(
        await ref.read(agendaRepositoryProvider).loadUpcoming(),
      ),
    );
  }
}
