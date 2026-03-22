import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/jwt_recovery.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/cadastro_screen.dart';
import '../../features/auth/presentation/completar_cadastro_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/assessores/presentation/assessores_screen.dart';
import '../../features/apoiadores/presentation/apoiadores_screen.dart';
import '../../features/votantes/presentation/votantes_screen.dart';
import '../../features/mensagens/presentation/mensagens_screen.dart';
import '../../features/benfeitorias/presentation/benfeitorias_screen.dart';
import '../../features/estrategia/presentation/estrategia_screen.dart';
import '../../features/mapa/presentation/mapa_screen.dart';
import '../../features/perfil/presentation/meu_perfil_screen.dart';
import '../../layout/main_scaffold.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'profile_role_cache.dart';
import 'role_home.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Notifica o GoRouter quando o stream de auth emite (login/logout).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

GoRouter createAppRouter({String? initialLocation}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: initialLocation ?? '/',
    refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
    redirect: (context, state) async {
      final session = Supabase.instance.client.auth.currentSession;
      final path = state.uri.path;

      // Reset de senha (PKCE): JWT com amr recovery — não mandar para home do assessor.
      if (session != null &&
          path != '/redefinir-senha' &&
          accessTokenIndicatesPasswordRecovery(session.accessToken)) {
        return '/redefinir-senha';
      }

      final isAuthPage = path == '/login' || path == '/cadastro';
      final isCompletarCadastro = path == '/completar-cadastro';
      final isRedefinirSenha = path == '/redefinir-senha';
      final isPasswordFlow = isCompletarCadastro || isRedefinirSenha;

      if (session == null && !isAuthPage && !isPasswordFlow) {
        return '/login';
      }
      if (session == null && isPasswordFlow) {
        return '/login';
      }

      if (session != null && isAuthPage) {
        final role = await cachedProfileRole(session.user.id);
        return homePathForProfileRole(role);
      }

      if (session != null && path == '/') {
        final role = await cachedProfileRole(session.user.id);
        final home = homePathForProfileRole(role);
        if (home != '/') return home;
      }

      if (session != null) {
        final role = await cachedProfileRole(session.user.id);
        if (role == 'apoiador' && path == '/apoiadores') {
          return '/votantes';
        }
        if (role == 'assessor' && path == '/assessores') {
          return '/apoiadores';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/cadastro',
        builder: (_, __) => const CadastroScreen(),
      ),
      GoRoute(
        path: '/completar-cadastro',
        builder: (_, __) => const CompletarCadastroScreen(),
      ),
      GoRoute(
        path: '/redefinir-senha',
        builder: (_, __) => const CompletarCadastroScreen(isPasswordRecovery: true),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) =>
            _RoleShellWrapper(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, state) => const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/assessores',
            pageBuilder: (_, state) => const NoTransitionPage(child: AssessoresScreen()),
          ),
          GoRoute(
            path: '/apoiadores',
            pageBuilder: (_, state) => const NoTransitionPage(child: ApoiadoresScreen()),
          ),
          GoRoute(
            path: '/votantes',
            pageBuilder: (_, state) => const NoTransitionPage(child: VotantesScreen()),
          ),
          GoRoute(
            path: '/mensagens',
            pageBuilder: (_, state) => const NoTransitionPage(child: MensagensScreen()),
          ),
          GoRoute(
            path: '/benfeitorias',
            pageBuilder: (_, state) => const NoTransitionPage(child: BenfeitoriasScreen()),
          ),
          GoRoute(
            path: '/estrategia',
            pageBuilder: (_, state) => const NoTransitionPage(child: EstrategiaScreen()),
          ),
          GoRoute(
            path: '/mapa',
            pageBuilder: (_, state) => const NoTransitionPage(child: MapaScreen()),
          ),
          GoRoute(
            path: '/perfil',
            pageBuilder: (_, state) => const NoTransitionPage(child: MeuPerfilScreen()),
          ),
        ],
      ),
    ],
  );
}

/// Restrições por papel + redirecionamento do painel do apoiador.
class _RoleShellWrapper extends ConsumerWidget {
  const _RoleShellWrapper({required this.location, required this.child});

  final String location;
  final Widget child;

  static const _forbiddenApoiador = {
    '/assessores',
    '/apoiadores',
    '/benfeitorias',
    '/mensagens',
    '/estrategia',
    '/',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final role = profile?.role;

    if (role == 'apoiador' && _forbiddenApoiador.contains(location)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/votantes');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (role == 'assessor' && location == '/assessores') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/apoiadores');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MainScaffold(child: child);
  }
}
