import 'package:flutter/material.dart';

class MapaRegionalTab extends StatelessWidget {
  const MapaRegionalTab({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('Mapa Interativo — Regiões de MT', style: theme.textTheme.titleMedium),
          Text('5 POLOS REGIONAIS — MT', style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          Text('Clique em um polo para ver detalhes', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
