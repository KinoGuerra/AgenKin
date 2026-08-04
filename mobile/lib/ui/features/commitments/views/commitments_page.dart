import 'package:agenkin/core/errors/app_exception.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/ui/core/theme.dart';
import 'package:agenkin/ui/core/widgets.dart';
import 'package:agenkin/ui/features/commitments/view_models/commitments_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CommitmentsPage extends ConsumerWidget {
  const CommitmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(commitmentsViewModelProvider);
    final viewModel = ref.read(commitmentsViewModelProvider.notifier);
    return overview.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          ErrorState(message: readableError(error), onRetry: viewModel.reload),
      data: (data) => RefreshIndicator(
        onRefresh: viewModel.reload,
        child: data.commitments.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 180),
                  EmptyState(
                    icon: Icons.task_alt,
                    title: 'Nada pendiente',
                    message:
                        'No hay vencimientos futuros que necesiten revisión.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: data.commitments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = data.commitments[index];
                  return _CommitmentCard(
                    item: item,
                    accountEmail: data.emailsByConnection[item.connectionId],
                  );
                },
              ),
      ),
    );
  }
}

class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard({required this.item, this.accountEmail});
  final Commitment item;
  final String? accountEmail;

  @override
  Widget build(BuildContext context) {
    final color = item.requiresReview
        ? AgenKinTheme.attention
        : AgenKinTheme.sync;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.go('/compromisos/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 46,
                child: Column(
                  children: [
                    Text(
                      DateFormat(
                        'MMM',
                        'es_AR',
                      ).format(item.date).toUpperCase(),
                    ),
                    Text(
                      '${item.date.day}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${item.date.year}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      accountEmail == null
                          ? item.type
                          : '${item.type} · $accountEmail',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusChip(
                          label: item.requiresReview
                              ? 'Requiere revisión'
                              : 'Alta confianza',
                          color: color,
                        ),
                        StatusChip(
                          label: '${(item.confidence * 100).round()}%',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class CommitmentDetailPage extends ConsumerWidget {
  const CommitmentDetailPage({required this.commitmentId, super.key});
  final String commitmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(commitmentsViewModelProvider);
    final viewModel = ref.read(commitmentsViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del compromiso')),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: readableError(error),
          onRetry: viewModel.reload,
        ),
        data: (data) {
          final item = data.commitments
              .where((value) => value.id == commitmentId)
              .firstOrNull;
          if (item == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Compromiso no disponible',
              message: 'Puede haber sido descartado o ya no estar vigente.',
            );
          }
          return _CommitmentDetail(
            item: item,
            accountEmail: data.emailsByConnection[item.connectionId],
            onDiscard: () => _confirmDiscard(context, viewModel, item),
          );
        },
      ),
    );
  }

  Future<void> _confirmDiscard(
    BuildContext context,
    CommitmentsViewModel viewModel,
    Commitment item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar compromiso'),
        content: const Text(
          'AgenKin recordará este descarte para no autoagendar correos similares.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await viewModel.discard(item.id);
      if (context.mounted) context.go('/compromisos');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(readableError(error))));
      }
    }
  }
}

class _CommitmentDetail extends StatelessWidget {
  const _CommitmentDetail({
    required this.item,
    required this.onDiscard,
    this.accountEmail,
  });
  final Commitment item;
  final String? accountEmail;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final discardable =
        item.status == 'pendiente' || item.status == 'evento_creado';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          item.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(DateFormat('EEEE d MMMM y', 'es_AR').format(item.date)),
        if (item.time != null) Text('Hora: ${item.time!.substring(0, 5)}'),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _DetailRow(label: 'Tipo', value: item.type),
                _DetailRow(
                  label: 'Confianza',
                  value: '${(item.confidence * 100).round()}%',
                ),
                _DetailRow(label: 'Estado', value: item.status),
                if (item.emailSubject != null)
                  _DetailRow(label: 'Correo', value: item.emailSubject!),
                if (item.connectionId != null)
                  _DetailRow(
                    label: 'Cuenta',
                    value: accountEmail ?? 'Cuenta conectada',
                  ),
              ],
            ),
          ),
        ),
        if (item.description.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(item.description),
        ],
        if (discardable) ...[
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: onDiscard,
            icon: const Icon(Icons.delete_outline),
            label: Text(
              item.status == 'evento_creado'
                  ? 'Descartar y eliminar de Agenda'
                  : 'Descartar',
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
