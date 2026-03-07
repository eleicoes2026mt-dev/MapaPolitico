import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dashboard', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(AppConstants.ufLabel, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 24),
          stats.when(
            data: (s) => _Cards(stats: s),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erro: $e'),
          ),
          const SizedBox(height: 24),
          stats.when(
            data: (s) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _VotosPorCidadeChart(items: s.votosPorCidade),
                ),
                const SizedBox(width: 24),
                Expanded(child: _AniversariantesHoje(count: s.aniversariantesHoje)),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          stats.when(
            data: (s) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _ApoiadoresPorPerfilChart(items: s.apoiadoresPorPerfil)),
                const SizedBox(width: 24),
                Expanded(child: _BenfeitoriasCard(total: s.totalBenfeitorias, count: s.benfeitoriasCount)),
                const SizedBox(width: 24),
                Expanded(child: _MensagensCard(count: s.mensagensCount)),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = [
      _CardData('Assessores', stats.assessores, Icons.people, const Color(0xFF1565C0)),
      _CardData('Apoiadores', stats.apoiadores, Icons.person_add, const Color(0xFF7B1FA2)),
      _CardData('Votantes', stats.votantes, Icons.checklist, const Color(0xFF2E7D32)),
      _CardData('Est. Votos', stats.estimativaVotos, Icons.show_chart, const Color(0xFFE65100)),
    ];
    return LayoutBuilder(
      builder: (_, c) {
        final crossCount = c.maxWidth > 900 ? 4 : (c.maxWidth > 600 ? 2 : 1);
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards.map((e) => SizedBox(
            width: crossCount == 1 ? double.infinity : (c.maxWidth / crossCount - 16 * (crossCount - 1) / crossCount).clamp(120.0, 280.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: e.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(e.icon, color: e.color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Text('${e.value}', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Flexible(child: Text(e.label, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
          )).toList(),
        );
      },
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

class _VotosPorCidadeChart extends StatelessWidget {
  const _VotosPorCidadeChart({required this.items});

  final List<MapEntry<String, int>> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bars = items.take(8).map((e) => FlSpot(items.indexOf(e).toDouble(), e.value.toDouble())).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Votos por Cidade (Top 8)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (items.isEmpty ? 1 : items.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble()) * 1.1,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt() < items.length ? items[v.toInt()].key : '',
                          style: theme.textTheme.labelSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        reservedSize: 28,
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(bars.length, (i) => BarChartGroupData(
                    x: i,
                    barRods: [BarChartRodData(toY: bars[i].y, color: theme.colorScheme.primary, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
                    showingTooltipIndicators: [0],
                  )),
                ),
              ),
            ),
          ],
        ),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cake, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Aniversariantes Hoje', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
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

class _ApoiadoresPorPerfilChart extends StatelessWidget {
  const _ApoiadoresPorPerfilChart({required this.items});

  final List<MapEntry<String, int>> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = items.fold<int>(0, (a, e) => a + e.value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apoiadores por Perfil', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (total == 0)
              Text('Nenhum dado', style: theme.textTheme.bodySmall)
            else
              SizedBox(
                height: 160,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(value: 1, color: theme.colorScheme.primary, showTitle: false),
                      PieChartSectionData(value: 1, color: theme.colorScheme.secondary, showTitle: false),
                      PieChartSectionData(value: 1, color: Colors.orange, showTitle: false),
                      PieChartSectionData(value: 1, color: Colors.purple, showTitle: false),
                    ].asMap().entries.take(items.length).map((e) {
                      final i = e.key;
                      final v = items[i].value.toDouble();
                      final colors = [theme.colorScheme.primary, theme.colorScheme.secondary, Colors.orange, Colors.purple];
                      return PieChartSectionData(
                        value: v,
                        color: colors[i % colors.length],
                        title: '${items[i].key} (${items[i].value})',
                        titleStyle: theme.textTheme.labelSmall!,
                      );
                    }).toList(),
                  ),
                ),
              ),
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
    final formatted = 'R\$ ${total.toStringAsFixed(2).replaceFirst('.', ',')}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text('Benfeitorias', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(formatted, style: theme.textTheme.titleLarge?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
            Text('$count registros no total', style: theme.textTheme.bodySmall),
            TextButton(onPressed: () {}, child: const Text('Ver todas →')),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Mensagens Recentes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(count == 0 ? 'Nenhuma mensagem' : '$count mensagem(ns)', style: theme.textTheme.bodyMedium),
            TextButton(onPressed: () {}, child: const Text('Ver todas →')),
          ],
        ),
      ),
    );
  }
}
