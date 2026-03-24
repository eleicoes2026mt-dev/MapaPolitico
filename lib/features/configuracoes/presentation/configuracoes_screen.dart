import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/campanha_audit_log.dart';
import '../providers/campanha_audit_provider.dart';

/// Configurações da campanha: histórico de alterações e restauração (somente candidato).
class ConfiguracoesScreen extends ConsumerWidget {
  const ConfiguracoesScreen({super.key});

  static final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(campanhaAuditLogProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Configurações', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Registro de tudo que foi incluído, editado ou excluído na sua campanha. '
            'Apenas você (candidato) vê esta área. É possível restaurar exclusões e reverter edições.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: () => ref.invalidate(campanhaAuditLogProvider),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Atualizar lista'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          async.when(
            data: (logs) {
              if (logs.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nenhum registro ainda. As alterações em assessores, apoiadores, votantes e benfeitorias aparecerão aqui.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final log = logs[i];
                  return _AuditTile(
                    log: log,
                    onRestaurarExclusao: log.action == 'delete'
                        ? () => _confirmarRestaurarExclusao(context, ref, log)
                        : null,
                    onReverterEdicao: log.action == 'update'
                        ? () => _confirmarReverterEdicao(context, ref, log)
                        : null,
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Card(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  e is Exception ? e.toString().replaceFirst('Exception: ', '') : '$e',
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarRestaurarExclusao(BuildContext context, WidgetRef ref, CampanhaAuditLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar registro excluído?'),
        content: Text(
          'Será recriado o registro em «${log.tableLabelPt}» (ID ${log.recordId.substring(0, 8)}…). '
          'Conflitos ocorrem se já existir um registro com o mesmo ID.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await restaurarExclusaoAudit(ref, log.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro restaurado.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _confirmarReverterEdicao(BuildContext context, WidgetRef ref, CampanhaAuditLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reverter para a versão anterior?'),
        content: Text(
          'O registro em «${log.tableLabelPt}» voltará ao estado imediatamente antes desta edição '
          '(${_fmt.format(log.createdAt)}).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reverter')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await reverterEdicaoAudit(ref, log);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edição revertida.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({
    required this.log,
    this.onRestaurarExclusao,
    this.onReverterEdicao,
  });

  final CampanhaAuditLog log;
  final VoidCallback? onRestaurarExclusao;
  final VoidCallback? onReverterEdicao;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dt = ConfiguracoesScreen._fmt.format(log.createdAt.toLocal());
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      title: Text(
        '${log.tableLabelPt} · ${log.actionLabelPt}',
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dt, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(
            'ID: ${log.recordId}',
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11),
          ),
        ],
      ),
      trailing: Wrap(
        spacing: 8,
        children: [
          if (onRestaurarExclusao != null)
            FilledButton.tonal(
              onPressed: onRestaurarExclusao,
              child: const Text('Restaurar'),
            ),
          if (onReverterEdicao != null)
            OutlinedButton(
              onPressed: onReverterEdicao,
              child: const Text('Reverter edição'),
            ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
