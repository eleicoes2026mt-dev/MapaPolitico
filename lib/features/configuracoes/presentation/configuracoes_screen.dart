import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/pwa_install_banner.dart';
import '../../auth/providers/auth_provider.dart';
import '../../assessores/providers/gestao_campanha_provider.dart';
import '../../mapa/providers/mapa_visual_prefs_provider.dart';
import '../providers/movimentacao_logs_provider.dart';
import '../providers/admin_usuarios_provider.dart';

/// Configurações da campanha: preferências e utilitários (ex.: movimentação Supabase para o candidato).
class ConfiguracoesScreen extends ConsumerWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final mostrarRegistoMovimentacao = profile?.role == 'candidato';
    final gestaoCompleta = ref.watch(podeGestaoCampanhaCompletaProvider);

    return RefreshIndicator(
      onRefresh: () async {
        if (ref.read(profileProvider).valueOrNull?.role == 'candidato') {
          ref.invalidate(movimentacaoLogsListProvider);
          await ref.read(movimentacaoLogsListProvider.future).then((_) {}).onError((_, __) {});
        }
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
          if (gestaoCompleta) ...[
            const SizedBox(height: 24),
            const _GerenciarUsuariosCard(),
          ],
          if (mostrarRegistoMovimentacao) ...[
            const SizedBox(height: 24),
            const _RegistroMovimentacaoSupabaseCard(),
          ],
        ],
      ),
    ),
    );
  }
}

// ── Gerenciar Usuários (candidato + assessor grau 1) ─────────────────────────

class _GerenciarUsuariosCard extends ConsumerStatefulWidget {
  const _GerenciarUsuariosCard();

  @override
  ConsumerState<_GerenciarUsuariosCard> createState() =>
      _GerenciarUsuariosCardState();
}

class _GerenciarUsuariosCardState
    extends ConsumerState<_GerenciarUsuariosCard> {
  final _buscaCtrl = TextEditingController();
  List<AdminUsuario>? _resultados;
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final fn = ref.read(adminBuscarUsuariosProvider);
      final lista = await fn(_buscaCtrl.text.trim());
      if (mounted) setState(() => _resultados = lista);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _confirmarExclusao(BuildContext ctx, AdminUsuario u) async {
    final confirma = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Excluir usuário'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tem certeza que deseja excluir este usuário do sistema?'),
            const SizedBox(height: 12),
            Text('Nome: ${u.nome}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            if (u.email != null) Text('E-mail: ${u.email}'),
            Text('Função: ${u.papelLabel}'),
            const SizedBox(height: 12),
            Text(
              'Esta ação é irreversível. Todos os dados do usuário serão removidos.',
              style: TextStyle(
                color: Theme.of(dialogCtx).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogCtx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirma != true || !mounted) return;

    setState(() => _carregando = true);
    try {
      final fn = ref.read(adminDeletarUsuarioProvider);
      await fn(u.uid);
      if (mounted) {
        setState(() {
          _resultados?.removeWhere((x) => x.uid == u.uid);
          _carregando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuário "${u.nome}" excluído com sucesso.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _carregando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header
            Row(
              children: [
                Icon(Icons.manage_accounts_outlined,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gerenciar usuários (autenticação)',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Busque por nome ou e-mail para localizar um cadastro e excluí-lo do sistema. '
              'A exclusão remove o acesso à plataforma de forma permanente.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // ── Campo de busca
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _buscaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nome ou e-mail',
                      hintText: 'Deixe em branco para listar todos',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _buscar(),
                    textInputAction: TextInputAction.search,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _carregando ? null : _buscar,
                  icon: _carregando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search, size: 18),
                  label: const Text('Buscar'),
                ),
              ],
            ),

            // ── Erro
            if (_erro != null) ...[
              const SizedBox(height: 10),
              Text(_erro!,
                  style: TextStyle(
                      color: theme.colorScheme.error, fontSize: 12)),
            ],

            // ── Resultados
            if (_resultados != null) ...[
              const SizedBox(height: 16),
              Text(
                '${_resultados!.length} resultado(s)',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              if (_resultados!.isEmpty)
                Text(
                  'Nenhum usuário encontrado.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _resultados!.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final u = _resultados![i];
                      return ListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: u.ativo
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.errorContainer,
                          child: Text(
                            u.nome.isNotEmpty ? u.nome[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 13,
                              color: u.ativo
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                        title: Text(
                          u.nome,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${u.email ?? 'sem e-mail'}  •  ${u.papelLabel}'
                          '${u.ativo ? '' : '  •  inativo'}'
                          '\nCadastro: ${fmt.format(u.criadoEm)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: theme.colorScheme.error),
                          tooltip: 'Excluir usuário',
                          onPressed: () => _confirmarExclusao(ctx, u),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RegistroMovimentacaoSupabaseCard extends ConsumerStatefulWidget {
  const _RegistroMovimentacaoSupabaseCard();

  @override
  ConsumerState<_RegistroMovimentacaoSupabaseCard> createState() =>
      _RegistroMovimentacaoSupabaseCardState();
}

class _RegistroMovimentacaoSupabaseCardState extends ConsumerState<_RegistroMovimentacaoSupabaseCard> {
  static final _fmt = DateFormat('dd/MM/yyyy HH:mm');
  bool _rodouAuto = false;
  bool _manualLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _rodouAuto) return;
      _rodouAuto = true;
      try {
        await tryRegisterAutoMovimentacaoIfDue(ref);
      } catch (_) {
        // falha silenciosa (rede/RLS); lista mostrará erro ao atualizar
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _manual() async {
    setState(() => _manualLoading = true);
    try {
      await insertMovimentacaoLog(ref, origem: 'manual');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro manual gravado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _manualLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(movimentacaoLogsListProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_sync_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Registro de movimentação (Supabase)',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Até dois registros automáticos por dia, com pelo menos 12 horas entre o primeiro e o segundo, '
              'quando você abre esta página. Você também pode registrar manualmente. Uso opcional para gerar atividade no projeto. '
              'A lista abaixo mostra só os registros dos últimos 5 dias.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: _manualLoading ? null : _manual,
                  icon: _manualLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.touch_app_outlined, size: 18),
                  label: const Text('Registrar agora (manual)'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Atualizar lista',
                  onPressed: () => ref.invalidate(movimentacaoLogsListProvider),
                  icon: const Icon(Icons.refresh_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Últimos registros (5 dias)', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Text(
                    'Ainda sem registros.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  );
                }
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final l = logs[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.origemLabelPt, style: theme.textTheme.bodyMedium),
                        trailing: Text(
                          _fmt.format(l.createdAt.toLocal()),
                          style: theme.textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Text(
                '$e',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
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
