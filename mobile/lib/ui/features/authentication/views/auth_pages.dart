import 'package:agenkin/core/errors/app_exception.dart';
import 'package:agenkin/ui/features/authentication/view_models/auth_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/branding/agenkin-icon.png',
              width: 112,
              height: 112,
              semanticLabel: 'AgenKin',
            ),
            const SizedBox(height: 24),
            Semantics(
              label: 'Validando sesión',
              child: const CircularProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = ref.watch(authViewModelProvider);
    final error = action.error;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: 28),
                  Text(
                    'Tus fechas importantes, en un solo lugar.',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ingresá con la misma cuenta que usás en AgenKin para consultar tu Agenda y tus compromisos.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 20),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        readableError(error),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: action.isLoading
                        ? null
                        : ref
                              .read(authViewModelProvider.notifier)
                              .signInWithGoogle,
                    icon: action.isLoading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      action.isLoading
                          ? 'Abriendo Google…'
                          : 'Continuar con Google',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'AgenKin no guarda tu contraseña de Google.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RestrictedAccessPage extends ConsumerWidget {
  const RestrictedAccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return _MessagePage(
      icon: Icons.lock_outline,
      title: 'Acceso restringido',
      message:
          'La cuenta ${profile?.email ?? ''} no está activa. Revisá el estado desde el portal web o contactá al administrador.',
      actionLabel: 'Cerrar sesión',
      onAction: ref.read(authViewModelProvider.notifier).signOut,
    );
  }
}

class AccessErrorPage extends ConsumerWidget {
  const AccessErrorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(accessStateProvider).value?.message;
    return _MessagePage(
      icon: Icons.cloud_off_outlined,
      title: 'No pudimos validar tu acceso',
      message: message ?? 'Revisá la conexión e intentá nuevamente.',
      actionLabel: 'Reintentar',
      onAction: ref.read(authViewModelProvider.notifier).retryAccess,
    );
  }
}

class _MessagePage extends StatelessWidget {
  const _MessagePage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48),
                  const SizedBox(height: 18),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: onAction, child: Text(actionLabel)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final asset = Theme.of(context).brightness == Brightness.dark
        ? 'assets/branding/agenkin-logo-dark.png'
        : 'assets/branding/agenkin-logo-light.png';
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        asset,
        width: 270,
        fit: BoxFit.contain,
        semanticLabel: 'AgenKin',
      ),
    );
  }
}
