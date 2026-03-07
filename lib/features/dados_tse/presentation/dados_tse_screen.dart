import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';

class DadosTseScreen extends ConsumerWidget {
  const DadosTseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dados TSE', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(AppConstants.ufLabel, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('Importar Dados TSE', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Faça upload de arquivo .csv com as colunas do TSE (DT_GERACAO, ANO_ELEICAO, NM_MUNICIPIO, QT_VOTOS, etc.)',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Upload CSV'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Icon(Icons.bar_chart, size: 80, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
                const SizedBox(height: 16),
                Text('Nenhum dado TSE importado', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Importe um arquivo CSV para visualizar os dados eleitorais',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
