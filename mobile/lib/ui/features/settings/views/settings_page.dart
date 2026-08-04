import 'package:agenkin/core/errors/app_exception.dart';
import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/ui/core/widgets.dart';
import 'package:agenkin/ui/features/authentication/view_models/auth_view_model.dart';
import 'package:agenkin/ui/features/settings/view_models/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final preferences = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);
    return preferences.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorState(
        message: readableError(error),
        onRetry: () => ref.invalidate(settingsViewModelProvider),
      ),
      data: (settings) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  (profile?.displayName ?? 'A').characters.first.toUpperCase(),
                ),
              ),
              title: Text(profile?.displayName ?? 'Usuario'),
              subtitle: Text(profile?.email ?? ''),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Apariencia',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          SegmentedButton<AppThemeMode>(
            segments: const [
              ButtonSegment(value: AppThemeMode.system, label: Text('Sistema')),
              ButtonSegment(value: AppThemeMode.light, label: Text('Claro')),
              ButtonSegment(value: AppThemeMode.dark, label: Text('Oscuro')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (selection) async {
              try {
                await viewModel.setTheme(selection.first);
              } catch (error) {
                if (context.mounted) _showError(context, error);
              }
            },
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Avisos dentro de la app'),
            subtitle: const Text(
              'Preferencia local preparada para la etapa de notificaciones.',
            ),
            value: settings.notificationsEnabled,
            onChanged: (value) async {
              try {
                await viewModel.setNotificationsEnabled(value);
              } catch (error) {
                if (context.mounted) _showError(context, error);
              }
            },
          ),
          const Divider(height: 36),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline),
            title: Text('AgenKin para Android'),
            subtitle: Text('Versión 0.1.0 · primera etapa'),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authViewModelProvider.notifier).signOut();
              final error = ref.read(authViewModelProvider).error;
              if (error != null && context.mounted) _showError(context, error);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(readableError(error))));
  }
}
