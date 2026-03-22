import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/mapa_camadas_filtradas_provider.dart';
import '../../providers/mapa_kpis_regiao_provider.dart';

/// Indicadores da campanha conforme filtro de região no mapa.
class MapaKpisRegiaoPanel extends ConsumerWidget {
  const MapaKpisRegiaoPanel({super.key});

  static String _fmtValor(double v) {
    if (v >= 1e6) return 'R\$ ${(v / 1e6).toStringAsFixed(1)} mi';
    if (v >= 1e3) return 'R\$ ${(v / 1e3).toStringAsFixed(1)} mil';
    return 'R\$ ${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = ref.watch(mapaKpisRegiaoProvider);
    final temTseNoMapa = ref.watch(mapaVotosTseAjustadosProvider).isNotEmpty;
    final theme = Theme.of(context);

    if (!k.temFiltroRegiao &&
        k.totalVotantesCadastrados == 0 &&
        k.valorTotalBenfeitorias <= 0 &&
        !temTseNoMapa) {
      return const SizedBox.shrink();
    }

    final titulo = k.temFiltroRegiao
        ? 'Indicadores — ${k.nomeRegiao ?? 'Região'}'
        : 'Indicadores — Mato Grosso (campanha)';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (k.temFiltroRegiao)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Filtrado pela região selecionada no mapa. Escolha “Todas” nos filtros para ver o estado inteiro.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 10),
            if (k.totalVotantesCadastrados == 0 && k.valorTotalBenfeitorias <= 0 && temTseNoMapa)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Cadastre votantes e benfeitorias para preencher estes indicadores. A legenda acima refere-se aos votos TSE no mapa.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _chip(
                  theme,
                  Icons.how_to_vote_outlined,
                  'Votantes',
                  '${k.totalVotantesCadastrados}',
                  subtitle: '${k.totalVotosEstimadosRede} votos na rede',
                ),
                if (k.cidadeMaisVotosNome != null && k.cidadeMaisVotosValor > 0)
                  _chip(
                    theme,
                    Icons.location_city,
                    'Cidade com mais votos',
                    k.cidadeMaisVotosNome!,
                    subtitle: '${k.cidadeMaisVotosValor} votos estimados',
                  ),
                if (k.apoiadorMaisVotantesNome != null && k.apoiadorMaisVotantesQtd > 0)
                  _chip(
                    theme,
                    Icons.groups_outlined,
                    'Apoiador com mais votantes',
                    k.apoiadorMaisVotantesNome!,
                    subtitle: '${k.apoiadorMaisVotantesQtd} votante(s) cadastrado(s)',
                  ),
                _chip(
                  theme,
                  Icons.volunteer_activism_outlined,
                  'Benfeitorias (valor)',
                  _fmtValor(k.valorTotalBenfeitorias),
                  subtitle: 'Soma nas cidades da área',
                ),
              ],
            ),
            if (k.benfeitoriasPorCidadeTop.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Benfeitorias por cidade (top)', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              ...k.benfeitoriasPorCidadeTop.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(b.cidadeNome, style: theme.textTheme.bodySmall)),
                      Text(
                        '${b.qtd} • ${_fmtValor(b.valor)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(ThemeData theme, IconData icon, String label, String value, {String? subtitle}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (subtitle != null)
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
