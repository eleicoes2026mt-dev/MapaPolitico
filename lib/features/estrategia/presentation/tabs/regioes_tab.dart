import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/regioes_fundidas.dart';
import '../../providers/regioes_fundidas_provider.dart';
import '../../widgets/edit_regiao_nome_dialog.dart';

class RegioesTab extends ConsumerStatefulWidget {
  const RegioesTab({super.key});

  @override
  ConsumerState<RegioesTab> createState() => _RegioesTabState();
}

class _RegioesTabState extends ConsumerState<RegioesTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fundidasAsync = ref.watch(regioesFundidasProvider);
    final efetivas = ref.watch(regioesEfetivasProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Regiões e nomenclatura',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Fundir regiões em uma única região com novo nome. No mapa, Metas e Responsáveis será usada esta nomenclatura.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showFundirDialog(context),
                  icon: const Icon(Icons.merge_type),
                  label: const Text('Fundir regiões'),
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final canUndo = ref.watch(canUndoRegioesFundidasProvider);
                    return OutlinedButton.icon(
                      onPressed: canUndo ? () => _desfazer(context) : null,
                      icon: const Icon(Icons.undo),
                      label: const Text('Desfazer'),
                    );
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () => _restaurarNomesPadrao(context),
                  icon: const Icon(Icons.restore),
                  label: const Text('Restaurar nomes padrão'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('Regiões em uso', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          fundidasAsync.when(
            data: (state) {
              final fundidas = state.list;
              if (efetivas.isEmpty) {
                return Text(
                  'Nenhuma região carregada.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                );
              }
              if (fundidas.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nenhuma fusão. As ${efetivas.length} regiões são exibidas separadamente no mapa, Metas e Responsáveis.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    ...efetivas.map((r) => _buildRegiaoCard(context, theme, r, isAdmin)),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: efetivas.map((r) => _buildRegiaoCard(context, theme, r, isAdmin)).toList(),
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => Text('Erro: $e', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildRegiaoCard(BuildContext context, ThemeData theme, RegiaoEfetiva r, bool isAdmin) {
    return Card(
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
          onTap: isAdmin
              ? () async {
                  final ok = await showEditRegiaoNomeDialog(context, ref, r);
                  if (ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome da região atualizado.')));
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Flexible(
                  child: Text(r.nome, overflow: TextOverflow.ellipsis),
                ),
                if (isAdmin) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.edit_outlined, size: 18, color: theme.colorScheme.primary),
                ],
              ],
            ),
          ),
        ),
        subtitle: Text(
          r.descricao,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isAdmin && r.eFundida
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Remover fusão',
                onPressed: () => _removerFusao(context, r.id),
              )
            : null,
      ),
    );
  }

  Future<void> _showFundirDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final fundidas = ref.read(regioesFundidasProvider).valueOrNull?.list ?? [];
    final covered = <String>{};
    for (final f in fundidas) {
      for (final id in f.ids) covered.add(id);
    }
    final base = ref.read(regioesMapeadasMTProvider).valueOrNull ?? [];
    final disponiveis = base.where((r) => true).toList();

    final selecionados = <String>{};
    final nomeController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Fundir regiões'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selecione as regiões que formarão uma nova região com um único nome:'),
                    const SizedBox(height: 16),
                    ...disponiveis.map((r) {
                      final inMerge = covered.contains(r.id);
                      final selected = selecionados.contains(r.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: inMerge
                            ? null
                            : (v) {
                                setDialogState(() {
                                  if (v == true) {
                                    selecionados.add(r.id);
                                  } else {
                                    selecionados.remove(r.id);
                                  }
                                });
                              },
                        title: Text(r.nome),
                        subtitle: inMerge ? Text('Já está em uma fusão', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)) : null,
                      );
                    }),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da nova região',
                        hintText: 'Ex.: Centro-Norte, Grande Cuiabá',
                      ),
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: selecionados.length >= 1 && nomeController.text.trim().isNotEmpty
                      ? () => Navigator.of(ctx).pop(true)
                      : null,
                  child: const Text('Salvar fusão'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && nomeController.text.trim().isNotEmpty) {
      final ids = selecionados.toList()..sort();
      if (ids.isEmpty) return;
      final id = 'merge_${ids.join("_")}';
      final fundida = RegiaoFundida(id: id, nome: nomeController.text.trim(), ids: ids);
      await ref.read(regioesFundidasProvider.notifier).add(fundida);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fusão "${fundida.nome}" criada.')),
        );
      }
    }
  }

  Future<void> _desfazer(BuildContext context) async {
    final ok = await ref.read(regioesFundidasProvider.notifier).undo();
    if (context.mounted && ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Última ação desfeita.')));
    }
  }

  Future<void> _restaurarNomesPadrao(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar nomes padrão'),
        content: const Text(
          'Todos os nomes editados das regiões serão removidos. O mapa e as telas Metas, Responsáveis e Regiões passarão a exibir apenas os nomes padrão (do mapa). Deseja continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(nomesCustomizadosProvider.notifier).restoreNomesPadrao();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomes restaurados para o padrão do mapa.')),
      );
    }
  }

  Future<void> _removerFusao(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover fusão'),
        content: const Text('As regiões voltarão a aparecer separadamente. Deseja continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(regioesFundidasProvider.notifier).remove(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fusão removida.')));
      }
    }
  }
}
