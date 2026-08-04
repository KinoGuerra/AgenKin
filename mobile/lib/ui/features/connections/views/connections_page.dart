import 'package:agenkin/core/errors/app_exception.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/ui/core/theme.dart';
import 'package:agenkin/ui/core/widgets.dart';
import 'package:agenkin/ui/features/connections/view_models/connections_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key});

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(connectionsViewModelProvider.notifier).reload();
    }
  }

  Future<void> _run(Future<void> Function() command, String success) async {
    try {
      await command();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(readableError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectionsViewModelProvider);
    final viewModel = ref.read(connectionsViewModelProvider.notifier);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          ErrorState(message: readableError(error), onRetry: viewModel.reload),
      data: (connections) => RefreshIndicator(
        onRefresh: viewModel.reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _SectionHeader(
              title: 'Gmail',
              subtitle:
                  '${connections.gmailUsed} de ${connections.gmailLimit} cuentas conectadas',
            ),
            const SizedBox(height: 10),
            if (connections.gmailAccounts.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.mark_email_unread_outlined),
                  title: Text('Conectá tu primera cuenta'),
                  subtitle: Text(
                    'AgenKin usa acceso de solo lectura para detectar fechas.',
                  ),
                ),
              )
            else
              for (final account in connections.gmailAccounts) ...[
                _GmailCard(
                  account: account,
                  onSync: () => _run(
                    () => viewModel.requestSync([account.id]),
                    'Actualización solicitada.',
                  ),
                  onDisconnect: () => _confirmDisconnect(account, viewModel),
                  onCalendar: connections.calendar.connected
                      ? null
                      : () => _run(
                          () => viewModel.authorizeCalendar(account.id),
                          'Completá la autorización en Google y volvé a AgenKin.',
                        ),
                ),
                const SizedBox(height: 10),
              ],
            if (connections.gmailUsed < connections.gmailLimit) ...[
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => _run(
                  viewModel.authorizeGmail,
                  'Completá la autorización en Google y volvé a AgenKin.',
                ),
                icon: const Icon(Icons.add),
                label: const Text('Agregar cuenta Gmail'),
              ),
            ],
            const SizedBox(height: 28),
            const _SectionHeader(
              title: 'Google Calendar',
              subtitle: 'La Agenda interna sigue siendo la fuente principal.',
            ),
            const SizedBox(height: 10),
            _CalendarCard(
              calendar: connections.calendar,
              onDisconnect: connections.calendar.connectionId == null
                  ? null
                  : () => _run(
                      () => viewModel.disconnect(
                        connectionId: connections.calendar.connectionId!,
                        service: 'calendar',
                      ),
                      'Calendar fue desconectado.',
                    ),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Automatización',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _StateLine(
                      label: 'Sincronización automática',
                      enabled: connections.autoSync,
                    ),
                    _StateLine(
                      label: 'Eventos de alta confianza',
                      enabled: connections.autoCreateEvents,
                    ),
                    Text(
                      'Umbral: ${(connections.confidenceThreshold * 100).round()}%',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Estos ajustes se administran por ahora desde el portal web.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDisconnect(
    GmailConnection account,
    ConnectionsViewModel viewModel,
  ) async {
    final disconnectAll = account.calendarActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desconectar cuenta'),
        content: Text(
          disconnectAll
              ? 'Esta cuenta también usa Calendar. Se desconectarán ambos servicios.'
              : 'AgenKin dejará de leer correos nuevos de ${account.email}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => viewModel.disconnect(
        connectionId: account.id,
        service: disconnectAll ? 'todo' : 'gmail',
      ),
      'La cuenta fue desconectada.',
    );
  }
}

class _GmailCard extends StatelessWidget {
  const _GmailCard({
    required this.account,
    required this.onSync,
    required this.onDisconnect,
    this.onCalendar,
  });

  final GmailConnection account;
  final VoidCallback onSync;
  final VoidCallback onDisconnect;
  final VoidCallback? onCalendar;

  @override
  Widget build(BuildContext context) {
    final color = account.connected
        ? AgenKinTheme.sync
        : Theme.of(context).colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    account.email,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StatusChip(
                  label: account.connected ? 'Activa' : account.status,
                  color: color,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              account.lastReadAt == null
                  ? 'Todavía sin lecturas registradas'
                  : 'Última lectura ${DateFormat('d/M HH:mm').format(account.lastReadAt!)}',
            ),
            if (account.pendingTasks > 0 || account.errorTasks > 0)
              Text(
                '${account.pendingTasks} pendientes · ${account.errorTasks} con error',
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: onSync,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
                if (onCalendar != null)
                  TextButton.icon(
                    onPressed: onCalendar,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Usar para Calendar'),
                  ),
                TextButton(
                  onPressed: onDisconnect,
                  child: const Text('Desconectar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({required this.calendar, this.onDisconnect});
  final CalendarConnection calendar;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          calendar.connected ? Icons.event_available : Icons.event_busy,
          color: calendar.connected ? AgenKinTheme.sync : null,
        ),
        title: Text(
          calendar.connected ? calendar.email ?? 'Conectado' : 'No conectado',
        ),
        subtitle: Text(
          calendar.connected
              ? '${calendar.pendingEvents} pendientes · ${calendar.errorEvents} con error'
              : 'Elegí una cuenta Gmail conectada para habilitarlo.',
        ),
        trailing: onDisconnect == null
            ? null
            : IconButton(
                tooltip: 'Desconectar Calendar',
                onPressed: onDisconnect,
                icon: const Icon(Icons.link_off),
              ),
      ),
    );
  }
}

class _StateLine extends StatelessWidget {
  const _StateLine({required this.label, required this.enabled});
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(enabled ? Icons.check_circle : Icons.cancel_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(subtitle),
      ],
    );
  }
}
