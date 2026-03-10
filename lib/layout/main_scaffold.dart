import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_constants.dart';
import '../features/auth/providers/auth_provider.dart';

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    void onSignOut() async {
      await ref.read(authNotifierProvider.notifier).signOut();
    }
    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(profile: profile, onSignOut: onSignOut),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: Drawer(
        child: _Sidebar(profile: profile, onSignOut: onSignOut),
      ),
      body: child,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({this.profile, required this.onSignOut});

  final dynamic profile;
  final VoidCallback onSignOut;

  static const _items = [
    _NavItem('/', 'Dashboard', Icons.dashboard_outlined),
    _NavItem('/assessores', 'Assessores', Icons.people_outline),
    _NavItem('/apoiadores', 'Apoiadores', Icons.person_add_alt_1_outlined),
    _NavItem('/votantes', 'Votantes', Icons.checklist_outlined),
    _NavItem('/mensagens', 'Mensagens', Icons.chat_bubble_outline),
    _NavItem('/benfeitorias', 'Benfeitorias', Icons.favorite_border),
    _NavItem('/dados-tse', 'Dados TSE', Icons.bar_chart_outlined),
    _NavItem('/estrategia', 'Estratégia', Icons.location_on_outlined),
    _NavItem('/mapa', 'Mapa', Icons.map_outlined),
    _NavItem('/perfil', 'Meu perfil', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final theme = Theme.of(context);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDrawer = screenWidth < 800;
    final sidebarWidth = isDrawer ? (screenWidth * 0.85).clamp(240.0, 260.0) : 260.0;

    return Container(
      width: sidebarWidth,
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Icon(Icons.how_to_vote, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              AppConstants.appName,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                AppConstants.appSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (profile != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Text(
                      profile.fullName ?? profile.email ?? 'Usuário',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      (profile.role as String?)?.toUpperCase() ?? 'USER',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (profile.cargo != null && profile.cargo!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.cargo!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ..._items.map((e) {
                      final selected = loc == e.path || (e.path == '/' && loc == '/');
                      return ListTile(
                        leading: Icon(e.icon, size: 22),
                        title: Text(e.title, overflow: TextOverflow.ellipsis),
                        selected: selected,
                        onTap: () => context.go(e.path),
                      );
                    }),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () {
                onSignOut();
                context.go('/login');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.title, this.icon);
  final String path;
  final String title;
  final IconData icon;
}
