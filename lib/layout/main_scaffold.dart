import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_constants.dart';
import '../features/auth/providers/auth_provider.dart';
import '../models/profile.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarExpanded = true;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    void onSignOut() async {
      await ref.read(authNotifierProvider.notifier).signOut();
    }
    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _sidebarExpanded
                  ? _Sidebar(
                      profile: profile,
                      onSignOut: onSignOut,
                      onCollapse: () => setState(() => _sidebarExpanded = false),
                      expanded: true,
                    )
                  : _SidebarCollapsed(
                      onExpand: () => setState(() => _sidebarExpanded = true),
                    ),
            ),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
              Navigator.of(context).pop();
            } else {
              _scaffoldKey.currentState?.openDrawer();
            }
          },
          tooltip: 'Abrir menu',
        ),
        title: Text(
          _titleForRoute(GoRouterState.of(context).uri.path),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      drawer: Drawer(
        child: _Sidebar(profile: profile, onSignOut: onSignOut),
      ),
      body: widget.child,
    );
  }
}

String _titleForRoute(String path) {
  const map = {
    '/': 'Dashboard',
    '/assessores': 'Assessores',
    '/apoiadores': 'Apoiadores',
    '/votantes': 'Votantes',
    '/agenda': 'Agenda',
    '/mensagens': 'Mensagens',
    '/benfeitorias': 'Benfeitorias',
    '/estrategia': 'Estratégia',
    '/mapa': 'Mapa',
    '/configuracoes': 'Configurações',
    '/perfil': 'Meu perfil',
  };
  return map[path] ?? 'CampanhaMT';
}

String? _subtitleUltimoAcesso(String path, Profile? p) {
  if (p == null) return null;
  final fmt = DateFormat('dd/MM/yyyy HH:mm');
  if (path == '/assessores' && p.lastAccessAssessoresAt != null) {
    return 'Último acesso: ${fmt.format(p.lastAccessAssessoresAt!.toLocal())}';
  }
  if (path == '/apoiadores' && p.lastAccessApoiadoresAt != null) {
    return 'Último acesso: ${fmt.format(p.lastAccessApoiadoresAt!.toLocal())}';
  }
  return null;
}

/// Barra estreita com botão para expandir o menu (telas largas).
class _SidebarCollapsed extends StatelessWidget {
  const _SidebarCollapsed({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 56,
      color: theme.colorScheme.surfaceContainerHighest,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onExpand,
              tooltip: 'Expandir menu',
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    this.profile,
    required this.onSignOut,
    this.onCollapse,
    this.expanded = false,
  });

  final Profile? profile;
  final VoidCallback onSignOut;
  final VoidCallback? onCollapse;
  final bool expanded;

  static const _items = [
    _NavItem('/', 'Dashboard', Icons.dashboard_outlined),
    _NavItem('/assessores', 'Assessores', Icons.people_outline),
    _NavItem('/apoiadores', 'Apoiadores', Icons.person_add_alt_1_outlined),
    _NavItem('/votantes', 'Votantes', Icons.checklist_outlined),
    _NavItem('/agenda', 'Agenda', Icons.event_outlined),
    _NavItem('/mensagens', 'Mensagens', Icons.chat_bubble_outline),
    _NavItem('/benfeitorias', 'Benfeitorias', Icons.favorite_border),
    _NavItem('/estrategia', 'Estratégia', Icons.location_on_outlined),
    _NavItem('/mapa', 'Mapa', Icons.map_outlined),
    _NavItem('/configuracoes', 'Configurações', Icons.settings_outlined),
    _NavItem('/perfil', 'Meu perfil', Icons.person_outline),
  ];

  /// Apoiador: votantes, agenda (visitas da cidade), mapa e perfil.
  static const _pathsOcultosApoiador = {
    '/',
    '/assessores',
    '/apoiadores',
    '/benfeitorias',
    '/mensagens',
    '/estrategia',
    '/configuracoes',
  };

  /// Assessor: entra em «Apoiadores»; não vê dashboard do candidato nem menu Assessores.
  static const _pathsOcultosAssessor = {'/', '/assessores', '/configuracoes'};

  @override
  Widget build(BuildContext context) {
    final prof = profile;
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                    ],
                  ),
                ),
                if (onCollapse != null)
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: onCollapse,
                    tooltip: 'Recolher menu',
                  ),
              ],
            ),
            if (prof != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Text(
                      prof.fullName ?? prof.email ?? 'Usuário',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      prof.role.toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (prof.cargo != null && prof.cargo!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        prof.cargo!,
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
                    ..._items.where((e) {
                      if (prof == null) return true;
                      if (e.path == '/configuracoes' && prof.role != 'candidato') {
                        return false;
                      }
                      if (prof.role == 'apoiador') {
                        return !_pathsOcultosApoiador.contains(e.path);
                      }
                      if (prof.role == 'assessor') {
                        return !_pathsOcultosAssessor.contains(e.path);
                      }
                      return true;
                    }).map((e) {
                      final selected = loc == e.path;
                      final sub = _subtitleUltimoAcesso(e.path, prof);
                      return ListTile(
                        leading: Icon(e.icon, size: 22),
                        title: Text(e.title, overflow: TextOverflow.ellipsis),
                        subtitle: sub != null
                            ? Text(
                                sub,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.85),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        selected: selected,
                        onTap: () {
                          if (isDrawer) Navigator.of(context).pop();
                          context.go(e.path);
                        },
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
                if (isDrawer) Navigator.of(context).pop();
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
