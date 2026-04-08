import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/amigos_gilberto.dart';
import '../core/bootstrap/app_deploy_update.dart';
import '../core/bootstrap/reload_page_stub.dart'
    if (dart.library.html) '../core/bootstrap/reload_page_web.dart' as reload_page;
import '../core/data/candidato_campanha_public.dart';
import '../core/services/realtime_notifications_service.dart';
import '../core/supabase/supabase_provider.dart';
import '../core/widgets/amigos_gilberto_qr_dialog.dart';
import '../core/widgets/pwa_onboarding_dialog.dart';
import '../features/agenda/providers/agenda_provider.dart';
import '../features/agenda/widgets/sidebar_aniversariantes_banner.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/assessores/providers/gestao_campanha_provider.dart';
import '../models/profile.dart';
import '../models/visita.dart';

bool _mostrarQrConviteAmigos(Profile? p) =>
    p != null && const {'candidato', 'assessor', 'apoiador', 'votante'}.contains(p.role);

/// Evita repetir o SnackBar de aniversário no mesmo dia (candidato/assessor).
const _kBirthdaySnackPrefKey = 'campanha_mt_aniversario_snack_dia';

String _formatarNomesAniversarioSnack(List<String> nomes) {
  if (nomes.isEmpty) return '';
  if (nomes.length <= 5) {
    if (nomes.length == 1) return nomes.first;
    if (nomes.length == 2) return '${nomes[0]} e ${nomes[1]}';
    return '${nomes.sublist(0, nomes.length - 1).join(', ')} e ${nomes.last}';
  }
  final head = nomes.take(4).join(', ');
  final rest = nomes.length - 4;
  return '$head e mais $rest';
}

Future<void> _abrirDialogQrAmigos(BuildContext context, Profile p) async {
  CandidatoCampanhaPublic? campanha;
  try {
    final raw = await supabase.rpc('candidato_campanha_public');
    campanha = CandidatoCampanhaPublic.tryParse(raw);
  } catch (_) {}

  if (!context.mounted) return;

  final fotoCampanha = campanha?.sidebarBrandImageUrl ??
      (p.role == 'candidato' ? p.sidebarBrandImageUrl : null);

  String? nomeCampanha;
  final rpcNome = campanha?.fullName?.trim();
  if (rpcNome != null && rpcNome.isNotEmpty) {
    nomeCampanha = rpcNome;
  } else if (p.role == 'candidato') {
    final n = p.fullName?.trim();
    if (n != null && n.isNotEmpty) nomeCampanha = n;
  }

  showAmigosGilbertoQrDialog(
    context,
    inviterProfileId: p.id,
    inviterDisplayName: p.fullName,
    candidatePhotoUrl: fotoCampanha,
    candidateName: nomeCampanha,
  );
}

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _sidebarExpanded = true;
  Timer? _deployPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      RealtimeNotificationsService.instance.setNotificacaoCallback(
        (title, body, url) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        if (body.isNotEmpty)
                          Text(body, style: const TextStyle(color: Colors.white70, fontSize: 12), maxLines: 2),
                      ],
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 5),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
      );
      RealtimeNotificationsService.instance.init(ref as Ref);
      if (kIsWeb) {
        checkAndMaybePromptDeployUpdate(context);
        _deployPollTimer = Timer.periodic(const Duration(minutes: 8), (_) {
          if (!mounted) return;
          checkAndMaybePromptDeployUpdate(context);
        });
      }
    });
  }

  @override
  void dispose() {
    _deployPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    RealtimeNotificationsService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && kIsWeb && mounted) {
      checkAndMaybePromptDeployUpdate(context);
    }
  }

  void _abrirOrientacaoAppENotificacoes() {
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      mostrarPwaOnboarding(context, ref, force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final theme = Theme.of(context);

    ref.listen<AsyncValue<List<Aniversariante>>>(aniversariantesHojeProvider, (prev, next) {
      Future<void> maybeSnack() async {
        final p = ref.read(profileProvider).valueOrNull;
        final role = p?.role;
        if (role != 'candidato' && role != 'assessor') return;
        final list = next.valueOrNull;
        if (list == null || list.isEmpty) return;
        final prefs = await SharedPreferences.getInstance();
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        if (prefs.getString(_kBirthdaySnackPrefKey) == today) return;
        await prefs.setString(_kBirthdaySnackPrefKey, today);
        if (!mounted) return;
        final nomes = list.map((e) => e.nome).toList();
        final texto = _formatarNomesAniversarioSnack(nomes);
        final msg = list.length == 1
            ? 'Hoje é aniversário de $texto.'
            : 'Hoje é aniversário de: $texto.';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cake_rounded, color: theme.colorScheme.onInverseSurface, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      msg,
                      style: TextStyle(color: theme.colorScheme.onInverseSurface),
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 8),
              behavior: SnackBarBehavior.floating,
              backgroundColor: theme.colorScheme.inverseSurface,
            ),
          );
        });
      }

      maybeSnack();
    });

    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final abrirPwa = kIsWeb ? _abrirOrientacaoAppENotificacoes : null;

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
                      onOpenPwaOrientacao: abrirPwa,
                    )
                  : _SidebarCollapsed(
                      onExpand: () => setState(() => _sidebarExpanded = true),
                      onOpenPwaOrientacao: abrirPwa,
                      profile: profile,
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
        actions: [
          if (_mostrarQrConviteAmigos(profile))
            IconButton(
              icon: const Icon(Icons.qr_code_2_rounded),
              tooltip: 'QR — convite $kAmigosGilbertoLabel',
              onPressed: () => _abrirDialogQrAmigos(context, profile!),
            ),
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.add_to_home_screen_outlined),
              tooltip: 'Instalar app e ativar notificações',
              onPressed: _abrirOrientacaoAppENotificacoes,
            ),
          if (kIsWeb)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Atualizar página',
              onPressed: () => reload_page.reloadPageIfWeb(),
            ),
        ],
      ),
      drawer: Drawer(
        child: _Sidebar(
          profile: profile,
          onSignOut: onSignOut,
          onOpenPwaOrientacao: abrirPwa,
        ),
      ),
      body: widget.child,
    );
  }
}

/// Topo do menu: foto de perfil, senão bandeira do partido, senão bandeira em branco (sem partido/sem foto), senão ícone.
class _SidebarBrandMark extends StatelessWidget {
  const _SidebarBrandMark({required this.profile, required this.theme});

  final Profile? profile;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final prof = profile;
    final url = prof?.sidebarBrandImageUrl;
    const double markSize = 64;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: markSize,
          height: markSize,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.how_to_vote,
            size: markSize,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }
    if (prof != null &&
        prof.partidoId == null &&
        prof.role == 'candidato' &&
        (prof.avatarUrl == null || prof.avatarUrl!.trim().isEmpty)) {
      return Container(
        width: markSize,
        height: markSize,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.45),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.flag_outlined,
          size: 30,
          color: theme.colorScheme.outline,
        ),
      );
    }
    return Icon(
      Icons.how_to_vote,
      size: markSize,
      color: theme.colorScheme.primary,
    );
  }
}

String _titleForRoute(String path) {
  const map = {
    '/apoiador-home': 'Início',
    '/': 'Dashboard',
    '/assessores': 'Assessores',
    '/apoiadores': 'Apoiadores',
    '/votantes': kAmigosGilbertoLabel,
    '/agenda': 'Agenda',
    '/mensagens': 'Mensagens',
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
  const _SidebarCollapsed({
    required this.onExpand,
    this.onOpenPwaOrientacao,
    this.profile,
  });

  final VoidCallback onExpand;
  final VoidCallback? onOpenPwaOrientacao;
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showQr = _mostrarQrConviteAmigos(profile);
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
            if (onOpenPwaOrientacao != null) ...[
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.add_to_home_screen_outlined),
                onPressed: onOpenPwaOrientacao,
                tooltip: 'Instalar app e notificações',
              ),
            ],
            if (showQr) ...[
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded),
                onPressed: () => _abrirDialogQrAmigos(context, profile!),
                tooltip: 'QR — convite $kAmigosGilbertoLabel',
              ),
            ],
            if (kIsWeb) ...[
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => reload_page.reloadPageIfWeb(),
                tooltip: 'Atualizar página',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    this.profile,
    required this.onSignOut,
    this.onCollapse,
    this.expanded = false,
    this.onOpenPwaOrientacao,
  });

  final Profile? profile;
  final VoidCallback onSignOut;
  final VoidCallback? onCollapse;
  final bool expanded;
  final VoidCallback? onOpenPwaOrientacao;

  static const _items = [
    _NavItem('/apoiador-home', 'Início', Icons.home_outlined),
    _NavItem('/', 'Dashboard', Icons.dashboard_outlined),
    _NavItem('/assessores', 'Assessores', Icons.people_outline),
    _NavItem('/apoiadores', 'Apoiadores', Icons.person_add_alt_1_outlined),
    _NavItem('/votantes', kAmigosGilbertoLabel, Icons.checklist_outlined),
    _NavItem('/agenda', 'Agenda', Icons.event_outlined),
    _NavItem('/mensagens', 'Mensagens', Icons.chat_bubble_outline),
    _NavItem('/estrategia', 'Estratégia', Icons.location_on_outlined),
    _NavItem('/mapa', 'Mapa', Icons.map_outlined),
    _NavItem('/configuracoes', 'Configurações', Icons.settings_outlined),
    _NavItem('/perfil', 'Meu perfil', Icons.person_outline),
  ];

  /// Itens ocultos no menu para todos os perfis (rotas podem existir; não aparecem na lateral).
  static const _pathsOcultosMenuGlobal = {
    '/estrategia',
    '/mapa',
  };

  /// Apoiador: início (home), votantes, agenda e perfil. Mensagens só no bloco da tela Início.
  /// Dashboard e itens de gestão ficam ocultos.
  static const _pathsOcultosApoiador = {
    '/', // Dashboard do candidato
    '/assessores',
    '/apoiadores',
    '/configuracoes',
    '/mensagens',
  };

  /// Candidato/assessor: /apoiador-home é exclusivo dos apoiadores.
  static const _pathsOcultosCandidatoAssessor = {'/apoiador-home'};

  /// Assessor: nunca vê «Assessores» (só o candidato gere convites de assessor). Grau 1 mantém resto da gestão.
  static const _pathsOcultosAssessor = {'/assessores'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prof = profile;
    final gestaoCompleta = ref.watch(podeGestaoCampanhaCompletaProvider);
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
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(child: _SidebarBrandMark(profile: prof, theme: theme)),
                      if (prof != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            prof.fullName ?? prof.email ?? 'Usuário',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (prof.cargo != null && prof.cargo!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: Text(
                              prof.cargo!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                if (onCollapse != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: onCollapse,
                      tooltip: 'Recolher menu',
                    ),
                  ),
              ],
            ),
            if (onOpenPwaOrientacao != null || _mostrarQrConviteAmigos(prof) || kIsWeb) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (onOpenPwaOrientacao != null)
                    IconButton.filledTonal(
                      onPressed: onOpenPwaOrientacao,
                      icon: const Icon(Icons.add_to_home_screen_outlined),
                      tooltip: 'Instalar app e ativar notificações',
                    ),
                  if (_mostrarQrConviteAmigos(prof)) ...[
                    if (onOpenPwaOrientacao != null) const SizedBox(width: 4),
                    IconButton.filledTonal(
                      onPressed: () => _abrirDialogQrAmigos(context, prof!),
                      icon: const Icon(Icons.qr_code_2_rounded),
                      tooltip: 'QR — convite $kAmigosGilbertoLabel',
                    ),
                  ],
                  if (kIsWeb) ...[
                    if (onOpenPwaOrientacao != null || _mostrarQrConviteAmigos(prof))
                      const SizedBox(width: 4),
                    IconButton.filledTonal(
                      onPressed: () => reload_page.reloadPageIfWeb(),
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Atualizar página',
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 24),
            if (prof != null && mostrarAniversariantesNoMenu(role: prof.role)) ...[
              SidebarAniversariantesBanner(isDrawer: isDrawer),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ..._items.where((e) {
                      if (prof == null) return true;
                      if (_pathsOcultosMenuGlobal.contains(e.path)) return false;
                      if (e.path == '/configuracoes' && !gestaoCompleta) return false;
                      if (prof.role == 'apoiador' || prof.role == 'votante') {
                        if (prof.role == 'votante' && e.path == '/votantes') {
                          return false;
                        }
                        return !_pathsOcultosApoiador.contains(e.path);
                      }
                      if (prof.role == 'assessor') {
                        return !_pathsOcultosAssessor.contains(e.path) &&
                            !_pathsOcultosCandidatoAssessor.contains(e.path);
                      }
                      // Candidato: ocultar /apoiador-home (exclusivo dos apoiadores)
                      return !_pathsOcultosCandidatoAssessor.contains(e.path);
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
