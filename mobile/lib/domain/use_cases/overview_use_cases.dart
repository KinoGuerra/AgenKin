import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/domain/repositories/repositories.dart';

class LoadHomeUseCase {
  const LoadHomeUseCase(this._dashboard, this._commitments, this._connections);

  final DashboardRepository _dashboard;
  final CommitmentsRepository _commitments;
  final ConnectionsRepository _connections;

  Future<AppResult<HomeOverview>> call() async {
    final summaryFuture = _dashboard.load();
    final commitmentsFuture = _commitments.loadActionable();
    final connectionsFuture = _connections.load();
    final summary = await summaryFuture;
    final commitments = await commitmentsFuture;
    final connections = await connectionsFuture;
    if (summary case AppFailure(message: final message)) {
      return AppResult.failure(message);
    }
    if (commitments case AppFailure(message: final message)) {
      return AppResult.failure(message);
    }
    if (connections case AppFailure(message: final message)) {
      return AppResult.failure(message);
    }
    return AppResult.success(
      HomeOverview(
        summary: (summary as AppSuccess<DashboardSummary>).value,
        commitments: (commitments as AppSuccess<List<Commitment>>).value,
        connections: (connections as AppSuccess<ConnectionsState>).value,
      ),
    );
  }
}

class LoadCommitmentsUseCase {
  const LoadCommitmentsUseCase(this._commitments, this._connections);

  final CommitmentsRepository _commitments;
  final ConnectionsRepository _connections;

  Future<AppResult<CommitmentsOverview>> call() async {
    final commitmentsFuture = _commitments.loadActionable();
    final connectionsFuture = _connections.load();
    final commitments = await commitmentsFuture;
    final connections = await connectionsFuture;
    if (commitments case AppFailure(message: final message)) {
      return AppResult.failure(message);
    }
    if (connections case AppFailure(message: final message)) {
      return AppResult.failure(message);
    }
    return AppResult.success(
      CommitmentsOverview(
        commitments: (commitments as AppSuccess<List<Commitment>>).value,
        emailsByConnection: (connections as AppSuccess<ConnectionsState>)
            .value
            .emailsByConnection,
      ),
    );
  }
}
