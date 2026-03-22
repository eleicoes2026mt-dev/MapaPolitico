import 'package:flutter/material.dart';
import '../../data/tse_votos_escala.dart';

/// Legenda das cores dos círculos TSE; toque em cada faixa para ver cidades e intervalo de votos.
class MapaTseLegenda extends StatelessWidget {
  const MapaTseLegenda({super.key, required this.votosPorCidade});

  final Map<String, int> votosPorCidade;

  void _abrirDetalhe(BuildContext context, TseVotoTier tier, int minV, int maxV) {
    final lista = cidadesNoTier(votosPorCidade, tier, minV, maxV);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tier.tituloLegenda),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                textoFaixaVotos(tier, minV, maxV),
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                '${lista.length} cidade(s) nesta faixa (votos TSE 2022)',
                style: Theme.of(ctx).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: lista.isEmpty
                    ? const Center(child: Text('Nenhuma cidade nesta faixa com os filtros atuais.'))
                    : ListView.builder(
                        itemCount: lista.length,
                        itemBuilder: (_, i) {
                          final c = lista[i];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: corCentroTier(tier).withValues(alpha: 0.35),
                              child: Text(
                                '${c.votos}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                            title: Text(nomeExibicaoCidadeTse(c.key)),
                            subtitle: Text('${c.votos} votos'),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (votosPorCidade.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final mm = minMaxVotos(votosPorCidade);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Legenda — votos por cidade (TSE)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Toque numa cor para ver o intervalo de votos e a lista de cidades.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TseVotoTier.values.map((tier) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _abrirDetalhe(context, tier, mm.minV, mm.maxV),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  corCentroTier(tier).withValues(alpha: 0.9),
                                  corCentroTier(tier).withValues(alpha: 0.15),
                                ],
                                stops: const [0.35, 1.0],
                              ),
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              tier.tituloLegenda,
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
