import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/jwt_recovery.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/cadastro_amigos_gilberto_screen.dart';
import '../../features/auth/presentation/cadastro_screen.dart';
import '../../features/auth/presentation/completar_cadastro_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/assessores/presentation/assessores_screen.dart';
import '../../features/apoiadores/presentation/apoiadores_screen.dart';
import '../../features/votantes/presentation/votantes_screen.dart';
import '../../features/agenda/presentation/agenda_screen.dart';
import '../../features/apoiador_home/presentation/apoiador_home_screen.dart';
import '../../features/mensagens/presentation/mensagens_screen.dart';
import '../../features/estrategia/presentation/estrategia_screen.dart';
import '../../features/mapa/presentation/mapa_screen.dart';
import '../../features/perfil/presentation/meu_perfil_screen.dart';
import '../../features/configuracoes/presentation/configuracoes_screen.dart';
import '../../layout/main_scaffold.dart';
import '../../models/profile.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'navigation_keys.dart';
import 'profile_role_cache.dart';
import 'role_home.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

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

      // QR / links antigos: cadastro com ?amigos=1 → página dedicada
      if (path == '/cadastro' && state.uri.queryParameters['amigos'] == '1') {
        return '/cadastro-amigos';
      }

      // Reset de senha (PKCE): JWT com amr recovery — não mandar para home do assessor.
      if (session != null &&
          path != '/redefinir-senha' &&
          accessTokenIndicatesPasswordRecovery(session.accessToken)) {
        return '/redefinir-senha';
      }

      // Convite assessor/apoiador: amr invite — obrigar tela de criar senha (não dashboard do deputado).
      if (session != null &&
          path != '/completar-cadastro' &&
          accessTokenIndicatesInvite(session.accessToken)) {
        return '/completar-cadastro';
      }

      final isAuthPage =
          path == '/login' || path == '/cadastro' || path == '/cadastro-amigos';
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

      if (session != null && path == '/benfeitorias') {
        final role = await cachedProfileRole(session.user.id);
        return homePathForProfileRole(role);
      }

      if (session != null) {
        final role = await cachedProfileRole(session.user.id);
        if (role != 'candidato' && path == '/configuracoes') {
          return homePathForProfileRole(role);
        }
        if (role == 'apoiador' && path == '/apoiadores') {
          return '/apoiador-home';
        }
        if (role == 'votante') {
          const gestaoCandidato = {
            '/',
            '/assessores',
            '/apoiadores',
            '/configuracoes',
            '/estrategia',
            '/mapa',
          };
          if (gestaoCandidato.contains(path)) {
            return '/apoiador-home';
          }
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
        path: '/cadastro-amigos',
        builder: (_, __) => const CadastroAmigosGilbertoScreen(),
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
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => _RoleShellWrapper(
              location: state.uri.path,
              child: child,
            ),
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
            path: '/apoiador-home',
            pageBuilder: (_, state) => const NoTransitionPage(child: ApoiadorHomeScreen()),
          ),
          GoRoute(
            path: '/agenda',
            pageBuilder: (_, state) => const NoTransitionPage(child: AgendaScreen()),
          ),
          GoRoute(
            path: '/mensagens',
            pageBuilder: (_, state) => const NoTransitionPage(child: MensagensScreen()),
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
          GoRoute(
            path: '/configuracoes',
            pageBuilder: (_, state) => const NoTransitionPage(child: ConfiguracoesScreen()),
          ),
        ],
      ),
    ],
  );
}

/// Restrições por papel + redirecionamento do painel do apoiador.
class _RoleShellWrapper extends ConsumerStatefulWidget {
  const _RoleShellWrapper({required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<_RoleShellWrapper> createState() => _RoleShellWrapperState();
}

class _RoleShellWrapperState extends ConsumerState<_RoleShellWrapper> {
  static const _forbiddenApoiador = {
    '/assessores',
    '/apoiadores',
    '/mensagens',
    '/estrategia',
    '/',
  };

  static String _redirectApoiador(String path) {
    if (path == '/mensagens') return '/apoiador-home';
    return '/votantes';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<Profile?>>(profileProvider, (_, next) {
      final p = next.valueOrNull;
      if (p != null && !p.ativo) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await ref.read(authNotifierProvider.notifier).signOut();
          if (context.mounted) context.go('/login');
        });
      }
    });

    final profile = ref.watch(profileProvider).valueOrNull;
    final role = profile?.role;

    if (role == 'apoiador' && _forbiddenApoiador.contains(widget.location)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(_redirectApoiador(widget.location));
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (role == 'votante' && _forbiddenApoiador.contains(widget.location)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(_redirectApoiador(widget.location));
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (role == 'assessor' && widget.location == '/assessores') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/apoiadores');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (role != 'candidato' && widget.location == '/configuracoes') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (role == 'apoiador' || role == 'votante') {
          context.go('/apoiador-home');
        } else if (role == 'assessor') {
          context.go('/apoiadores');
        } else {
          context.go('/');
        }
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return MainScaffold(child: widget.child);
  }
}
