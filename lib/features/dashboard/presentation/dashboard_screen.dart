import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/amigos_gilberto.dart';
import '../../../core/utils/formato_pt_br.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../mapa/presentation/mapa_regional_panel.dart';
import '../providers/dashboard_provider.dart';

/// Breakpoints para responsividade
class _Breakpoint {
  static const double mobile = 600;
  static const double tablet = 900;
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final padding = width < _Breakpoint.mobile ? 12.0 : 18.0;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardStatsProvider);
        await ref
            .read(dashboardStatsProvider.future)
            .then((_) {})
            .onError((_, __) {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(padding: padding),
            SizedBox(height: padding * 0.5),
            stats.when(
              data: (s) => _StatsCards(stats: s),
              loading: () => const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: EdgeInsets.all(padding),
                child: Text('Erro ao carregar: $e',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error)),
              ),
            ),
            SizedBox(height: padding * 0.75),
            const MapaRegionalPanel(mode: MapaPanelMode.embedded),
            SizedBox(height: padding * 0.35),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => context.push('/mapa'),
                icon: const Icon(Icons.open_in_full, size: 18),
                label: const Text('Abrir mapa em tela cheia'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.padding});

  final double padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < _Breakpoint.mobile;

    return Padding(
      padding: EdgeInsets.only(top: isCompact ? 8 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              'Dashboard',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          const EstadoMTBadge(compact: true),
        ],
      ),
    );
  }
}

class _StatsCards extends StatelessWidget {
  const _StatsCards({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossCount =
        width > _Breakpoint.tablet ? 4 : (width > _Breakpoint.mobile ? 2 : 1);
    final spacing = width < _Breakpoint.mobile ? 10.0 : 12.0;

    final cards = [
      _CardData('Assessores', stats.assessores, Icons.people,
          const Color(0xFF1565C0)),
      _CardData('Apoiadores', stats.apoiadores, Icons.person_add,
          const Color(0xFF7B1FA2)),
      _CardData(kAmigosGilbertoLabel, stats.votantes, Icons.checklist,
          const Color(0xFF2E7D32)),
      _CardData(
        'Est. Votos',
        stats.estimativaVotos,
        Icons.show_chart,
        const Color(0xFFE65100),
        mostrarComparacaoTse: true,
        votosTseEleicao2022: stats.votosTseEleicao2022,
        perfilTseVinculado: stats.perfilTseVinculado,
      ),
    ];

    /// Maior ratio = células mais baixas (mais compacto). Ajuste se «Est. Votos» cortar texto.
    final aspectRatio = switch (crossCount) {
      4 => 1.52,
      2 => 2.12,
      _ => 3.1,
    };

    return GridView.count(
      crossAxisCount: crossCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: aspectRatio,
      children: cards
          .map(
            (c) => Align(
              alignment: Alignment.topCenter,
              child: _StatCard(data: c),
            ),
          )
          .toList(),
    );
  }
}

class _CardData {
  _CardData(
    this.label,
    this.value,
    this.icon,
    this.color, {
    this.mostrarComparacaoTse = false,
    this.votosTseEleicao2022 = 0,
    this.perfilTseVinculado = false,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  /// Só no cartão «Est. Votos»: compara estimativa com votos oficiais TSE (2022).
  final bool mostrarComparacaoTse;
  final int votosTseEleicao2022;
  final bool perfilTseVinculado;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _CardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < _Breakpoint.mobile;
    final tse = data.votosTseEleicao2022;
    final delta = data.mostrarComparacaoTse && tse > 0
        ? data.value - tse
        : null;
    final pctDoTse = data.mostrarComparacaoTse && tse > 0
        ? (data.value / tse) * 100.0
        : null;

    final conteudo = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              Icon(data.icon, color: data.color, size: isCompact ? 24 : 28),
        ),
        SizedBox(width: isCompact ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatarInteiroPtBr(data.value),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                data.label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (data.mostrarComparacaoTse) ...[
                const SizedBox(height: 8),
                if (data.perfilTseVinculado && tse > 0 &&
                    delta != null &&
                    pctDoTse != null) ...[
                  Text(
                    'Votos oficiais TSE (2022): ${formatarInteiroPtBr(tse)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${delta >= 0 ? '+' : ''}${formatarInteiroPtBr(delta)} votos vs TSE · '
                    '${pctDoTse.toStringAsFixed(1)}% do resultado 2022',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: delta >= 0
                          ? const Color(0xFF2E7D32)
                          : theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ] else if (!data.perfilTseVinculado)
                  Text(
                    'Em Meu perfil, vincule o candidato à eleição 2022 (lista TSE) para comparar a estimativa com os dados oficiais.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  )
                else
                  Text(
                    'Não foi possível obter a soma de votos TSE (2022) para este candidato.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 10 : 12),
        child: conteudo,
      ),
    );
  }
}
