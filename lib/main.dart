import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'core/config/env_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  // Se o app abriu pelo link do convite por e-mail, recuperar sessão e ir para completar cadastro
  String? initialLocation;
  try {
    final Uri? uri = kIsWeb ? Uri.base : await AppLinks().getInitialLink();
    if (uri != null) {
      final s = uri.toString();
      if (s.contains('access_token') || s.contains('type=invite') || s.contains('refresh_token')) {
        await Supabase.instance.client.auth.getSessionFromUrl(uri);
        initialLocation = '/completar-cadastro';
      }
    }
  } catch (_) {
    // Ignora erro ao processar link (ex.: link expirado)
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
