import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/mensagens_provider.dart';

class MensagensScreen extends ConsumerWidget {
  const MensagensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final count = ref.watch(mensagensCountProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mensagens', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text(AppConstants.ufLabel, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${count.valueOrNull ?? 0} mensagens no total', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Nova Mensagem'),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Icon(Icons.send, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('Nenhuma mensagem', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Crie mensagens globais, regionais ou de reunião',
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
