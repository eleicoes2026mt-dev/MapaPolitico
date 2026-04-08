import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/pwa_install_banner.dart';
import '../../../models/campanha_audit_log.dart';
import '../../mapa/providers/mapa_visual_prefs_provider.dart';
import '../providers/campanha_audit_provider.dart';

/// Configurações da campanha: histórico de alterações e restauração (candidato ou assessor grau 1).
class ConfiguracoesScreen extends ConsumerWidget {
  const ConfiguracoesScreen({super.key});

  static final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(campanhaAuditLogProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(campanhaAuditLogProvider);
        await ref.read(campanhaAuditLogProvider.future).then((_) {}).onError((_, __) {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('Configurações', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          const PwaInstallBanner(),
          const SizedBox(height: 24),
          const _MapaRegionalPrefsCard(),
          const SizedBox(height: 24),
          Text(
            'Registro de alterações',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Inclusões, edições e exclusões em assessores, apoiadores, votantes, benfeitorias, mensagens, agenda e alterações de papel/acesso. '
            'Quem executou cada ação e a data/hora vêm do registo (ator e carimbo de tempo). '
            'Candidato e assessores de grau 1 podem consultar; é possível restaurar exclusões e reverter edições quando aplicável.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
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
                      'Nenhum registro ainda. Alterações na campanha aparecerão aqui com data, hora e utilizador (quando disponível).',
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
    ),
    );
  }

  Future<void> _confirmarRestaurarExclusao(BuildContext context, WidgetRef ref, CampanhaAuditLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar registro excluído?'),
        content: Text(
          log.tableName == 'apoiadores'
              ? 'O apoiador volta à lista da campanha. Se havia login vinculado, o perfil será reativado para ele poder entrar de novo (ID ${log.recordId.substring(0, 8)}…).'
              : 'Será recriado o registro em «${log.tableLabelPt}» (ID ${log.recordId.substring(0, 8)}…). '
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

class _MapaRegionalPrefsCard extends ConsumerStatefulWidget {
  const _MapaRegionalPrefsCard();

  @override
  ConsumerState<_MapaRegionalPrefsCard> createState() => _MapaRegionalPrefsCardState();
}

class _MapaRegionalPrefsCardState extends ConsumerState<_MapaRegionalPrefsCard> {
  MapaVisualPrefs? _draft;
  bool _dirty = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final committed = ref.watch(mapaVisualPrefsProvider);
    if (!_dirty) {
      _draft = committed;
    }
    final d = _draft!;

    Future<void> salvar() async {
      await ref.read(mapaVisualPrefsProvider.notifier).commit(d);
      if (!context.mounted) return;
      setState(() => _dirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferências do mapa salvas neste dispositivo.')),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mapa regional',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Tamanho dos marcadores (bolhas TSE, rede, polos) e espessura das linhas de contorno das regiões. '
              'Toque em «Salvar» para aplicar e gravar neste dispositivo.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text('Pontos / marcadores', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Menor', style: theme.textTheme.labelSmall),
                Expanded(
                  child: Slider(
                    value: d.escalaPontos.clamp(kMapaVisualEscalaMin, kMapaVisualEscalaMax),
                    min: kMapaVisualEscalaMin,
                    max: kMapaVisualEscalaMax,
                    divisions: 15,
                    label: '${(d.escalaPontos * 100).round()}%',
                    onChanged: (v) {
                      setState(() {
                        _draft = d.copyWith(escalaPontos: v);
                        _dirty = true;
                      });
                    },
                  ),
                ),
                Text('Maior', style: theme.textTheme.labelSmall),
              ],
            ),
            Text(
              '${(d.escalaPontos * 100).round()}% do tamanho padrão',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text('Linhas de contorno', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Mais fino', style: theme.textTheme.labelSmall),
                Expanded(
                  child: Slider(
                    value: d.escalaContorno.clamp(kMapaVisualEscalaMin, kMapaVisualEscalaMax),
                    min: kMapaVisualEscalaMin,
                    max: kMapaVisualEscalaMax,
                    divisions: 15,
                    label: '${(d.escalaContorno * 100).round()}%',
                    onChanged: (v) {
                      setState(() {
                        _draft = d.copyWith(escalaContorno: v);
                        _dirty = true;
                      });
                    },
                  ),
                ),
                Text('Mais grosso', style: theme.textTheme.labelSmall),
              ],
            ),
            Text(
              '${(d.escalaContorno * 100).round()}% da espessura padrão',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 12),
            if (_dirty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Alterações por salvar.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(
                  onPressed: _dirty ? salvar : null,
                  child: const Text('Salvar'),
                ),
                if (_dirty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _draft = committed;
                        _dirty = false;
                      });
                    },
                    child: const Text('Descartar'),
                  ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _draft = const MapaVisualPrefs(
                        escalaPontos: kMapaVisualEscalaDefault,
                        escalaContorno: kMapaVisualEscalaDefault,
                      );
                      _dirty = true;
                    });
                  },
                  child: const Text('Restaurar padrão (100%)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          if (log.actorProfileId != null && log.actorProfileId!.isNotEmpty)
            Text(
              'Por: ${log.actorProfileId}',
              style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11),
            ),
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

