import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isAuthPage = state.uri.path == '/login' || state.uri.path == '/cadastro';
      final isCompletarCadastro = state.uri.path == '/completar-cadastro';
      if (session == null && !isAuthPage && !isCompletarCadastro) return '/login';
      if (session == null && isCompletarCadastro) return '/login';
      if (session != null && isAuthPage) return '/';
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
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) =>
            _ApoiadorShellWrapper(location: state.uri.path, child: child),
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

/// Apoiador só acessa dashboard, apoiadores (próprio), votantes, mapa e perfil.
class _ApoiadorShellWrapper extends ConsumerWidget {
  const _ApoiadorShellWrapper({required this.location, required this.child});

  final String location;
  final Widget child;

  static const _forbidden = {'/assessores', '/benfeitorias', '/mensagens', '/estrategia'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    if (profile?.role == 'apoiador' && _forbidden.contains(location)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/votantes');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return MainScaffold(child: child);
  }
}
