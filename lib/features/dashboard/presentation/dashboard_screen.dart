import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
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
    final padding = width < _Breakpoint.mobile ? 16.0 : 24.0;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardStatsProvider);
        await ref.read(dashboardStatsProvider.future).then((_) {}).onError((_, __) {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          _Header(padding: padding),
          SizedBox(height: padding),
          stats.when(
            data: (s) => _StatsCards(stats: s),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            error: (e, _) => Padding(
              padding: EdgeInsets.all(padding),
              child: Text('Erro ao carregar: $e', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
            ),
          ),
          SizedBox(height: padding * 1.25),
          const MapaRegionalPanel(mode: MapaPanelMode.embedded),
          SizedBox(height: padding),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.push('/mapa'),
              icon: const Icon(Icons.open_in_full, size: 18),
              label: const Text('Abrir mapa em tela cheia'),
            ),
          ),
          SizedBox(height: padding),
          stats.when(
            data: (s) => _AniversariantesHoje(count: s.aniversariantesHoje),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          SizedBox(height: padding),
          stats.when(
            data: (s) => _BottomSection(
              apoiadoresPorPerfil: s.apoiadoresPorPerfil,
              totalBenfeitorias: s.totalBenfeitorias,
              benfeitoriasCount: s.benfeitoriasCount,
              mensagensCount: s.mensagensCount,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
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
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
    final crossCount = width > _Breakpoint.tablet ? 4 : (width > _Breakpoint.mobile ? 2 : 1);
    final spacing = width < _Breakpoint.mobile ? 12.0 : 16.0;

    final cards = [
      _CardData('Assessores', stats.assessores, Icons.people, const Color(0xFF1565C0)),
      _CardData('Apoiadores', stats.apoiadores, Icons.person_add, const Color(0xFF7B1FA2)),
      _CardData('Votantes', stats.votantes, Icons.checklist, const Color(0xFF2E7D32)),
      _CardData('Est. Votos', stats.estimativaVotos, Icons.show_chart, const Color(0xFFE65100)),
    ];

    if (crossCount == 1) {
      return Column(
        children: List.generate(cards.length, (i) => Padding(
          padding: EdgeInsets.only(bottom: i < cards.length - 1 ? spacing : 0),
          child: _StatCard(data: cards[i]),
        )),
      );
    }

    if (crossCount == 4) {
      return Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Expanded(child: _StatCard(data: cards[i])),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(data: cards[0])),
            SizedBox(width: spacing),
            Expanded(child: _StatCard(data: cards[1])),
          ],
        ),
        SizedBox(height: spacing),
        Row(
          children: [
            Expanded(child: _StatCard(data: cards[2])),
            SizedBox(width: spacing),
            Expanded(child: _StatCard(data: cards[3])),
          ],
        ),
      ],
    );
  }
}

class _CardData {
  _CardData(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _CardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < _Breakpoint.mobile;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16 : 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: data.color, size: isCompact ? 24 : 28),
            ),
            SizedBox(width: isCompact ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${data.value}',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.label,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChartPlaceholder extends StatelessWidget {
  const _EmptyChartPlaceholder({required this.message, required this.height});

  final String message;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AniversariantesHoje extends StatelessWidget {
  const _AniversariantesHoje({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < _Breakpoint.mobile;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cake_outlined, color: theme.colorScheme.primary, size: isCompact ? 20 : 24),
                SizedBox(width: isCompact ? 8 : 12),
                Flexible(
                  child: Text(
                    'Aniversariantes Hoje',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              count == 0 ? 'Nenhum aniversariante hoje' : '$count aniversariante(s)',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSection extends StatelessWidget {
  const _BottomSection({
    required this.apoiadoresPorPerfil,
    required this.totalBenfeitorias,
    required this.benfeitoriasCount,
    required this.mensagensCount,
  });

  final List<MapEntry<String, int>> apoiadoresPorPerfil;
  final double totalBenfeitorias;
  final int benfeitoriasCount;
  final int mensagensCount;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final spacing = width < _Breakpoint.mobile ? 12.0 : 24.0;

    if (width < _Breakpoint.mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ApoiadoresPorPerfilChart(items: apoiadoresPorPerfil),
          SizedBox(height: spacing),
          _BenfeitoriasCard(total: totalBenfeitorias, count: benfeitoriasCount),
          SizedBox(height: spacing),
          _MensagensCard(count: mensagensCount),
        ],
      );
    }

    if (width < _Breakpoint.tablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 2, child: _ApoiadoresPorPerfilChart(items: apoiadoresPorPerfil)),
              SizedBox(width: spacing),
              Expanded(flex: 1, child: _BenfeitoriasCard(total: totalBenfeitorias, count: benfeitoriasCount)),
            ],
          ),
          SizedBox(height: spacing),
          _MensagensCard(count: mensagensCount),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: _ApoiadoresPorPerfilChart(items: apoiadoresPorPerfil),
        ),
        SizedBox(width: spacing),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _BenfeitoriasCard(total: totalBenfeitorias, count: benfeitoriasCount),
              SizedBox(height: spacing),
              _MensagensCard(count: mensagensCount),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApoiadoresPorPerfilChart extends StatelessWidget {
  const _ApoiadoresPorPerfilChart({required this.items});

  final List<MapEntry<String, int>> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = items.fold<int>(0, (a, e) => a + e.value);
    final isCompact = MediaQuery.sizeOf(context).width < _Breakpoint.mobile;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apoiadores por Perfil',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (total == 0)
              _EmptyChartPlaceholder(
                message: 'Nenhum dado de apoiadores ainda.',
                height: 140,
              )
            else
              SizedBox(
                height: isCompact ? 140 : 160,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: isCompact ? 32 : 40,
                    sections: [
                      for (var i = 0; i < items.length; i++)
                        PieChartSectionData(
                          value: items[i].value.toDouble(),
                          color: [theme.colorScheme.primary, theme.colorScheme.secondary, Colors.orange, Colors.deepPurple][i % 4],
                          title: '${items[i].value}',
                          titleStyle: theme.textTheme.labelSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                          radius: 24,
                        ),
                    ],
                  ),
                ),
              ),
            if (total > 0) ...[
              const SizedBox(height: 8),
              ...items.map((e) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: [theme.colorScheme.primary, theme.colorScheme.secondary, Colors.orange, Colors.deepPurple][items.indexOf(e) % 4],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${e.key}: ${e.value}',
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

class _BenfeitoriasCard extends StatelessWidget {
  const _BenfeitoriasCard({required this.total, required this.count});

  final double total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < _Breakpoint.mobile;
    final formatted = 'R\$ ${total.toStringAsFixed(2).replaceFirst('.', ',')}';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_border, color: Colors.green.shade700, size: isCompact ? 20 : 24),
                SizedBox(width: isCompact ? 8 : 12),
                Text(
                  'Benfeitorias',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatted,
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.bold),
            ),
            Text('$count registros no total', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              onPressed: () {},
              child: const Text('Ver todas →'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MensagensCard extends StatelessWidget {
  const _MensagensCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < _Breakpoint.mobile;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: theme.colorScheme.primary, size: isCompact ? 20 : 24),
                SizedBox(width: isCompact ? 8 : 12),
                Flexible(
                  child: Text(
                    'Mensagens Recentes',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              count == 0 ? 'Nenhuma mensagem' : '$count mensagem(ns)',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
              onPressed: () {},
              child: const Text('Ver todas →'),
            ),
          ],
        ),
      ),
    );
  }
}

