import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'core/auth/auth_callback_url.dart';
import 'core/auth/jwt_recovery.dart'
    show accessTokenIndicatesInvite, accessTokenIndicatesPasswordRecovery;
import 'core/auth/supabase_auth_fragment.dart';
import 'core/bootstrap/arcgis_environment.dart';
import 'core/config/env_config.dart';
import 'core/router/app_router.dart';
import 'core/services/pwa_service.dart';
import 'core/theme/app_theme.dart';

/// Fragmento `#access_token=...` ou `#/login?access_token=...` (hash router).
Map<String, String> _queryParamsFromHashFragment(String frag) {
  if (frag.isEmpty) return {};
  final q = frag.indexOf('?');
  final query = q >= 0 ? frag.substring(q + 1) : frag;
  try {
    return Uri.splitQueryString(query);
  } catch (_) {
    return {};
  }
}

void main() {
  runZonedGuarded(() {
    _mainAsync().catchError((Object e, StackTrace st) {
      debugPrint('Erro no bootstrap: $e\n$st');
    });
  }, (error, stack) {
    debugPrint('Erro não tratado: $error\n$stack');
  });
}

Future<void> _mainAsync() async {
  WidgetsFlutterBinding.ensureInitialized();
  initArcgisEnvironment();
  if (kIsWeb) PwaService.instance.init();
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  /// Convite / magic link: na **web** o Supabase coloca tokens ou erros em `#fragmento`.
  /// Se não limparmos o fragmento, o GoRouter trata `error=access_denied&...` como rota → "Page Not Found".
  String? initialLocation;
  try {
    if (kIsWeb) {
      final uri = currentUriWithFragment();
      // PKCE (reset de senha): `?code=` é trocado no [Supabase.initialize]. O hash pode
      // continuar `#/apoiadores` (sessão antiga / restauração) — forçar tela de nova senha.
      final sess = Supabase.instance.client.auth.currentSession;
      if (uri.queryParameters.containsKey('code') && sess != null) {
        if (accessTokenIndicatesPasswordRecovery(sess.accessToken)) {
          replaceBrowserPath('/redefinir-senha');
          initialLocation = '/redefinir-senha';
        } else if (accessTokenIndicatesInvite(sess.accessToken)) {
          replaceBrowserPath('/completar-cadastro');
          initialLocation = '/completar-cadastro';
        }
      }

      final frag = uri.fragment;
      if (frag.isNotEmpty) {
        final params = Uri.splitQueryString(frag);
        if (params.containsKey('error')) {
          final msg = messageForSupabaseAuthFragment(params);
          storePendingAuthErrorMessage(msg);
          replaceBrowserPath('/login');
          initialLocation = '/login';
        } else if (frag.contains('access_token') || frag.contains('refresh_token')) {
          // Sair da sessão anterior (ex.: deputado no mesmo browser) antes de aplicar o convite.
          try {
            await Supabase.instance.client.auth.signOut();
          } catch (_) {}
          await Supabase.instance.client.auth.getSessionFromUrl(uri);
          final newSess = Supabase.instance.client.auth.currentSession;
          if (newSess != null) {
            if (accessTokenIndicatesPasswordRecovery(newSess.accessToken)) {
              replaceBrowserPath('/redefinir-senha');
              initialLocation = '/redefinir-senha';
            } else if (accessTokenIndicatesInvite(newSess.accessToken)) {
              replaceBrowserPath('/completar-cadastro');
              initialLocation = '/completar-cadastro';
            } else {
              final p = _queryParamsFromHashFragment(frag);
              final isRecovery = p['type'] == 'recovery';
              if (isRecovery) {
                replaceBrowserPath('/redefinir-senha');
                initialLocation = '/redefinir-senha';
              } else {
                replaceBrowserPath('/completar-cadastro');
                initialLocation = '/completar-cadastro';
              }
            }
          }
        }
      }
    } else {
      final Uri? uri = await AppLinks().getInitialLink();
      if (uri != null) {
        final s = uri.toString();
        if (s.contains('access_token') || s.contains('type=invite') || s.contains('refresh_token')) {
          await Supabase.instance.client.auth.getSessionFromUrl(uri);
          initialLocation = '/completar-cadastro';
        }
      }
    }
  } catch (e, st) {
    debugPrint('Falha ao processar link de auth: $e\n$st');
    if (kIsWeb) {
      storePendingAuthErrorMessage(
        'Não foi possível concluir o acesso por este link. Tente entrar com e-mail e senha ou peça um novo convite.',
      );
      replaceBrowserPath('/login');
      initialLocation = '/login';
    }
  }

  final router = createAppRouter(initialLocation: initialLocation);
  runApp(
    ProviderScope(
      child: CampanhaMTApp(router: router),
    ),
  );
}

class CampanhaMTApp extends ConsumerWidget {
  const CampanhaMTApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CampanhaMT - Gestão Eleitoral',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en'),
      ],
      locale: const Locale('pt', 'BR'),
    );
  }
}
