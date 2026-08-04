import 'package:agenkin/di/providers.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/ui/core/view_model_helpers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final homeViewModelProvider =
    AsyncNotifierProvider<HomeViewModel, HomeOverview>(HomeViewModel.new);

class HomeViewModel extends AsyncNotifier<HomeOverview> {
  @override
  Future<HomeOverview> build() async {
    return requireSuccess(await ref.watch(loadHomeUseCaseProvider).call());
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async =>
          requireSuccess(await ref.read(loadHomeUseCaseProvider).call()),
    );
  }
}
