import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/regioes_fundidas_provider.dart';

class ResponsaveisTab extends ConsumerWidget {
  const ResponsaveisTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final efetivas = ref.watch(regioesEfetivasProvider);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Atribuição de Responsáveis Regionais', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Regiões de MT. Atribua um responsável a cada região.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          ...efetivas.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: r.cor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  title: Text('Região ${r.nome}'),
                  subtitle: Text(r.descricao, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: DropdownButton<String>(
                    value: 'Sem responsável',
                    items: const [
                      DropdownMenuItem(value: 'Sem responsável', child: Text('Sem responsável')),
                    ],
                    onChanged: (_) {},
                  ),
                ),
              )),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.save),
            label: const Text('Salvar Responsáveis'),
          ),
        ],
      ),
    );
  }
}
