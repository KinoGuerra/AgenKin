import 'package:agenkin/core/errors/app_exception.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/ui/core/theme.dart';
import 'package:agenkin/ui/core/widgets.dart';
import 'package:agenkin/ui/features/agenda/view_models/agenda_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AgendaPage extends ConsumerWidget {
  const AgendaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(agendaViewModelProvider);
    final viewModel = ref.read(agendaViewModelProvider.notifier);
    return events.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          ErrorState(message: readableError(error), onRetry: viewModel.reload),
      data: (items) => RefreshIndicator(
        onRefresh: viewModel.reload,
        child: items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 180),
                  EmptyState(
                    icon: Icons.calendar_today_outlined,
                    title: 'Tu Agenda está al día',
                    message:
                        'Cuando AgenKin cree un evento futuro, aparecerá en esta línea de tiempo.',
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final event = items[index];
                  final showDay =
                      index == 0 ||
                      !_sameDay(items[index - 1].date, event.date);
                  return _TimelineEvent(event: event, showDay: showDay);
                },
              ),
      ),
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({required this.event, required this.showDay});

  final AgendaEvent event;
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (event.googleStatus) {
      'sincronizado' => AgenKinTheme.sync,
      'error' => Theme.of(context).colorScheme.error,
      'pendiente' => AgenKinTheme.attention,
      _ => Theme.of(context).colorScheme.outline,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDay)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 10),
            child: Text(
              DateFormat('EEEE d MMMM y', 'es_AR').format(event.date),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      event.allDay
                          ? 'Todo el día'
                          : DateFormat('HH:mm').format(event.date),
                    ),
                  ],
                ),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    event.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                StatusChip(label: event.googleLabel, color: statusColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
