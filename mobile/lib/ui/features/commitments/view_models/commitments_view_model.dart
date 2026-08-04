import 'package:agenkin/di/providers.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/ui/core/view_model_helpers.dart';
import 'package:agenkin/ui/features/agenda/view_models/agenda_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final commitmentsViewModelProvider =
    AsyncNotifierProvider<CommitmentsViewModel, CommitmentsOverview>(
      CommitmentsViewModel.new,
    );

class CommitmentsViewModel extends AsyncNotifier<CommitmentsOverview> {
  @override
  Future<CommitmentsOverview> build() async {
    return requireSuccess(
      await ref.watch(loadCommitmentsUseCaseProvider).call(),
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> discard(String id) async {
    requireSuccess(await ref.read(commitmentsRepositoryProvider).discard(id));
    ref.invalidate(agendaViewModelProvider);
    state = await AsyncValue.guard(_load);
  }

  Future<CommitmentsOverview> _load() async {
    return requireSuccess(
      await ref.read(loadCommitmentsUseCaseProvider).call(),
    );
  }
}
