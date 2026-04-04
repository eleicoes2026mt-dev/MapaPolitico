import 'package:flutter/material.dart';

/// Faixas de cor iguais ao preenchimento regional (ratio valor / máximo em MT).
const _faixasBenfeitoriasLegenda = <({String hex, String label})>[
  (hex: '#B71C1C', label: 'Muito baixo'),
  (hex: '#D32F2F', label: 'Baixo'),
  (hex: '#E64A19', label: 'Abaixo da média'),
  (hex: '#F57C00', label: 'Médio'),
  (hex: '#F9A825', label: 'Bom'),
  (hex: '#558B2F', label: 'Alto'),
  (hex: '#2E7D32', label: 'Muito alto'),
  (hex: '#FFD700', label: 'Pico (próximo ao máx.)'),
];

/// Legenda da camada de benfeitorias no mapa (escala em R$ relativa ao máximo entre regiões).
class MapaBenfeitoriasLegenda extends StatelessWidget {
  const MapaBenfeitoriasLegenda({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.volunteer_activism_outlined, size: 18, color: const Color(0xFFFFB300)),
                const SizedBox(width: 8),
                Text(
                  'Legenda — benfeitorias por região (R\$)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Cada região é pintada conforme o total de benfeitorias (R\$) nela, em relação à região com maior valor em MT. '
              'Quanto mais quente a cor, menor o valor relativo; verde e dourado = maiores valores.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final item in _faixasBenfeitoriasLegenda)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Color(int.parse(item.hex.replaceFirst('#', 'FF'), radix: 16)),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.label,
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
