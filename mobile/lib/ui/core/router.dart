import 'package:agenkin/domain/models/app_models.dart';
import 'package:agenkin/ui/core/navigation_scaffold.dart';
import 'package:agenkin/ui/features/agenda/views/agenda_page.dart';
import 'package:agenkin/ui/features/authentication/view_models/auth_view_model.dart';
import 'package:agenkin/ui/features/authentication/views/auth_pages.dart';
import 'package:agenkin/ui/features/commitments/views/commitments_page.dart';
import 'package:agenkin/ui/features/connections/views/connections_page.dart';
import 'package:agenkin/ui/features/home/views/home_page.dart';
import 'package:agenkin/ui/features/settings/views/settings_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

String? accessRedirect(AccessStatus status, String location) {
  const sessionRoutes = {'/splash', '/login', '/acceso-restringido', '/error'};
  return switch (status) {
    AccessStatus.checking => location == '/splash' ? null : '/splash',
    AccessStatus.signedOut => location == '/login' ? null : '/login',
    AccessStatus.blocked =>
      location == '/acceso-restringido' ? null : '/acceso-restringido',
    AccessStatus.failed => location == '/error' ? null : '/error',
    AccessStatus.active => sessionRoutes.contains(location) ? '/inicio' : null,
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  final access = ref.watch(accessStateProvider);
  final accessStatus = access.when(
    data: (value) => value.status,
    error: (_, _) => AccessStatus.failed,
    loading: () => AccessStatus.checking,
  );

  return GoRouter(
    initialLocation: '/splash',
    redirect: (_, state) => accessRedirect(accessStatus, state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(
        path: '/acceso-restringido',
        builder: (_, _) => const RestrictedAccessPage(),
      ),
      GoRoute(path: '/error', builder: (_, _) => const AccessErrorPage()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            NavigationScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/inicio', builder: (_, _) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/agenda', builder: (_, _) => const AgendaPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/compromisos',
                builder: (_, _) => const CommitmentsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/conexiones',
                builder: (_, _) => const ConnectionsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/configuracion',
                builder: (_, _) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/compromisos/:id',
        builder: (_, state) =>
            CommitmentDetailPage(commitmentId: state.pathParameters['id']!),
      ),
    ],
  );
});
