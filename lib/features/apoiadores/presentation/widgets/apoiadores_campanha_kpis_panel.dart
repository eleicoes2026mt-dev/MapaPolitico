import 'package:flutter/material.dart';

import '../../providers/campanha_kpis_provider.dart';

/// Resumo por assessor + totais (votos estimados: apoiadores + votantes).
class ApoiadoresCampanhaKpisPanel extends StatelessWidget {
  const ApoiadoresCampanhaKpisPanel({super.key, required this.resumo});

  final CampanhaKpisResumo resumo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          'Indicadores por assessor',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Total: ${resumo.totalApoiadores} apoiadores · ${resumo.totalVotantes} votantes · '
          '~${resumo.totalEstimativaApoiadores} votos est. (redes de apoiadores) · '
          '~${resumo.totalEstimativaVotantes} votos est. (cadastro de votantes)',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Column(
              children: resumo.porAssessor.map((l) {
                final vazio = l.qtdApoiadores == 0 && l.qtdVotantes == 0;
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    l.nome,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    vazio
                        ? 'Nenhum apoiador ou votante vinculado ainda'
                        : '${l.qtdApoiadores} apoiador(es) · ${l.qtdVotantes} votante(s) · '
                            '~${l.estimativaVotosApoiadores} est. apoiadores · ~${l.estimativaVotosVotantes} est. votantes',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
