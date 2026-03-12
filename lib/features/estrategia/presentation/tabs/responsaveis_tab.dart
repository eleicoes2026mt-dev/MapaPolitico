import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../assessores/providers/assessores_provider.dart';
import '../../providers/regioes_fundidas_provider.dart';
import '../../providers/responsavel_regiao_provider.dart';
import '../../widgets/edit_regiao_nome_dialog.dart';

class ResponsaveisTab extends ConsumerWidget {
  const ResponsaveisTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final efetivas = ref.watch(regioesEfetivasProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final responsaveisAsync = ref.watch(responsavelRegiaoProvider);
    final assessoresAsync = ref.watch(assessoresListProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Atribuição de Responsáveis Regionais', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Regiões de MT. Atribua um responsável (assessor) a cada região.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          responsaveisAsync.when(
            data: (responsaveis) {
              return assessoresAsync.when(
                data: (assessores) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                              title: InkWell(
                                onTap: isAdmin ? () => showEditRegiaoNomeDialog(context, ref, r) : null,
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Região ${r.nome}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isAdmin) ...[
                                        const SizedBox(width: 4),
                                        Icon(Icons.edit_outlined, size: 18, color: theme.colorScheme.primary),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              subtitle: Text(r.descricao, maxLines: 2, overflow: TextOverflow.ellipsis),
                              trailing: DropdownButton<String?>(
                                value: responsaveis[r.id],
                                isExpanded: false,
                                hint: const Text('Sem responsável'),
                                items: [
                                  const DropdownMenuItem<String?>(value: null, child: Text('Sem responsável')),
                                  ...assessores.map((a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.nome, overflow: TextOverflow.ellipsis))),
                                ],
                                onChanged: (String? assessorId) {
                                  ref.read(responsavelRegiaoProvider.notifier).setResponsavel(r.id, assessorId);
                                },
                              ),
                            ),
                          )),
                      const SizedBox(height: 24),
                      Consumer(
                        builder: (context, ref, _) {
                          final notifier = ref.read(responsavelRegiaoProvider.notifier);
                          final current = ref.watch(responsavelRegiaoProvider).valueOrNull ?? {};
                          return FilledButton.icon(
                            onPressed: () async {
                              try {
                                await notifier.save(current);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Responsáveis salvos.')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: theme.colorScheme.error),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.save),
                            label: const Text('Salvar Responsáveis'),
                          );
                        },
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (e, _) => Text('Erro ao carregar assessores: $e', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => Text('Erro ao carregar responsáveis: $e', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
