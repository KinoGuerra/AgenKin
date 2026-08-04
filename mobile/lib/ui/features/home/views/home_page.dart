import 'package:agenkin/core/errors/app_exception.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/ui/core/theme.dart';
import 'package:agenkin/ui/core/widgets.dart';
import 'package:agenkin/ui/features/authentication/view_models/auth_view_model.dart';
import 'package:agenkin/ui/features/home/view_models/home_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final overview = ref.watch(homeViewModelProvider);
    final viewModel = ref.read(homeViewModelProvider.notifier);
    return overview.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          ErrorState(message: readableError(error), onRetry: viewModel.reload),
      data: (data) => RefreshIndicator(
        onRefresh: viewModel.reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'Hola, ${profile?.displayName ?? ''}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Esto es lo que necesita tu atención.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 22),
            _SummaryCard(summary: data.summary),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Próximos compromisos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.go('/compromisos'),
                  child: const Text('Ver todos'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _Upcoming(items: data.commitments.take(3).toList()),
            const SizedBox(height: 24),
            Text(
              'Estado de sincronización',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                onTap: () => context.go('/conexiones'),
                leading: Icon(
                  data.connections.calendar.connected
                      ? Icons.sync
                      : Icons.sync_disabled,
                  color: data.connections.calendar.connected
                      ? AgenKinTheme.sync
                      : Theme.of(context).colorScheme.outline,
                ),
                title: Text(
                  data.connections.calendar.connected
                      ? 'Calendar conectado'
                      : 'Sólo Agenda interna',
                ),
                subtitle: Text(
                  '${data.connections.gmailUsed} de ${data.connections.gmailLimit} cuentas Gmail · ${data.connections.calendar.pendingEvents} eventos pendientes',
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Hoy',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(summary.planName),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _Metric(value: summary.emailsToday, label: 'correos'),
                _Metric(value: summary.pendingReviews, label: 'por revisar'),
                _Metric(value: summary.eventsCreated, label: 'eventos'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.items});
  final List<Commitment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.event_available),
          title: Text('No hay compromisos futuros'),
          subtitle: Text('Los próximos hallazgos aparecerán acá.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              onTap: () => context.go('/compromisos/${items[index].id}'),
              leading: SizedBox(
                width: 42,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat(
                        'MMM',
                        'es_AR',
                      ).format(items[index].date).toUpperCase(),
                    ),
                    Text(
                      '${items[index].date.day}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${items[index].date.year}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              title: Text(items[index].title),
              subtitle: Text(items[index].type),
              trailing: const Icon(Icons.chevron_right),
            ),
            if (index < items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
