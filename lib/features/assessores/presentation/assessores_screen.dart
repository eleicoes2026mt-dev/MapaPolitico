import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/confirmar_senha_deputado_dialog.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/assessor.dart';
import '../providers/assessores_provider.dart'
    show assessoresListProvider, convidarAssessor, ConvidarAssessorResult, reenviarConviteAssessor, removerAssessor, promoverACandidato, messageFromException, setAssessorAtivo;
import '../../configuracoes/providers/menu_access_provider.dart';

/// Link de convite para enviar por WhatsApp se o e-mail do Supabase não chegar.
Future<void> showLinkConviteAssessorDialog(BuildContext context, String link) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.link),
          SizedBox(width: 8),
          Expanded(child: Text('Link de acesso do assessor')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Copie e envie pelo WhatsApp (ou outro canal). O e-mail automático às vezes cai em spam ou demora — com o link a pessoa define a senha e entra no time.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            SelectableText(link, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Fechar'),
        ),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: link));
            if (ctx.mounted) {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copiado. Cole no WhatsApp e envie ao assessor.')),
              );
            }
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copiar link'),
        ),
      ],
    ),
  );
}

class AssessoresScreen extends ConsumerStatefulWidget {
  const AssessoresScreen({super.key});

  @override
  ConsumerState<AssessoresScreen> createState() => _AssessoresScreenState();
}

class _AssessoresScreenState extends ConsumerState<AssessoresScreen> {
  String _query = '';
  bool _promovendo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(registerMenuAccessProvider)('assessores');
    });
  }

  void _openNovoAssessorDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _NovoAssessorDialog(
        onSuccess: () {
          ref.invalidate(assessoresListProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final isCandidato = profile?.isCandidato ?? false;
    final list = ref.watch(assessoresListProvider);
    final filtered = list.valueOrNull?.where((a) => a.nome.toLowerCase().contains(_query.toLowerCase())).toList() ?? [];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(assessoresListProvider);
        await ref.read(assessoresListProvider.future).then((_) {}).onError((_, __) {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Assessores', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const EstadoMTBadge(compact: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar assessor...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              if (isCandidato) ...[
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () => _openNovoAssessorDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Assessor'),
                ),
              ],
            ],
          ),
          if (isCandidato)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Nível 2: convide assessores por e-mail. Eles poderão gerir dados e convidar apoiadores.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          if (!isCandidato) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'O botão "Novo Assessor" só aparece para o Candidato (Nível 1 – Admin Master).',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Se você é o candidato da campanha, ative seu acesso para poder convidar assessores:',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _promovendo
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _promovendo = true);
                              try {
                                await promoverACandidato();
                                ref.invalidate(profileProvider);
                                await ref.read(profileProvider.future);
                                ref.invalidate(assessoresListProvider);
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Acesso Candidato ativado. Você já pode convidar assessores.')),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text(e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString())),
                                );
                              } finally {
                                if (mounted) setState(() => _promovendo = false);
                              }
                            },
                      icon: _promovendo ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.admin_panel_settings_outlined),
                      label: Text(_promovendo ? 'Ativando...' : 'Sou o Candidato – Ativar acesso'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          list.when(
            data: (_) => LayoutBuilder(
              builder: (_, c) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: filtered.map((a) => _AssessorCard(
                    assessor: a,
                    isCandidato: isCandidato,
                    onRefresh: () => ref.invalidate(assessoresListProvider),
                  )).toList(),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Erro: $e'),
          ),
        ],
      ),
    ),
    );
  }
}

/// Dialog para convidar novo assessor (nome, e-mail, telefone). Só candidato vê o botão que abre este dialog.
class _NovoAssessorDialog extends ConsumerStatefulWidget {
  const _NovoAssessorDialog({required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  ConsumerState<_NovoAssessorDialog> createState() => _NovoAssessorDialogState();
}

class _NovoAssessorDialogState extends ConsumerState<_NovoAssessorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefoneController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _telefoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    if (!_formKey.currentState!.validate()) {
      setState(() => _loading = false);
      return;
    }
    try {
      final ConvidarAssessorResult out = await convidarAssessor(
        nome: _nomeController.text,
        email: _emailController.text,
        telefone: _telefoneController.text.isEmpty ? null : _telefoneController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess();
      if (out.linkCopia != null && out.linkCopia!.isNotEmpty) {
        await showLinkConviteAssessorDialog(context, out.linkCopia!);
      } else if (mounted) {
        final text = out.serverMessage ??
            (out.existingUser
                ? 'Vínculo atualizado. A lista será atualizada.'
                : 'Convite enviado por e-mail. Se não chegar, confira spam ou use Reenviar convite e configure SMTP no Supabase (docs).');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(text),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Convidar assessor'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'O assessor receberá um e-mail para criar a senha e acessar o sistema (nível 2: gerir dados e convidar apoiadores).',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                  if (!v.contains('@')) return 'E-mail inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefoneController,
                decoration: const InputDecoration(
                  labelText: 'Telefone (opcional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enviar convite'),
        ),
      ],
    );
  }
}

class _AssessorCard extends ConsumerStatefulWidget {
  const _AssessorCard({
    required this.assessor,
    required this.isCandidato,
    required this.onRefresh,
  });

  final Assessor assessor;
  final bool isCandidato;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_AssessorCard> createState() => _AssessorCardState();
}

class _AssessorCardState extends ConsumerState<_AssessorCard> {
  bool _reenviando = false;
  bool _removendo = false;
  bool _toggleAtivo = false;

  Future<void> _reenviarConvite() async {
    setState(() => _reenviando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final linkCopia = await reenviarConviteAssessor(widget.assessor);
      if (!mounted) return;
      widget.onRefresh();
      if (linkCopia != null && linkCopia.isNotEmpty) {
        await showLinkConviteAssessorDialog(context, linkCopia);
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Convite reenviado por e-mail. Se não chegar, confira spam ou configure SMTP no Supabase.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(messageFromException(e))),
      );
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  Future<void> _confirmarRemover() async {
    final senhaOk = await confirmarSenhaDeputado(context);
    if (!senhaOk || !mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover assessor'),
        content: Text(
          'Remover ${widget.assessor.nome}? O assessor perderá o acesso ao sistema.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _removendo = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await removerAssessor(widget.assessor.id);
      if (!mounted) return;
      widget.onRefresh();
      messenger.showSnackBar(const SnackBar(content: Text('Assessor removido.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(messageFromException(e))),
      );
    } finally {
      if (mounted) setState(() => _removendo = false);
    }
  }

  Future<void> _alternarAtivo() async {
    final a = widget.assessor;
    final desativar = a.ativo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(desativar ? 'Desativar assessor' : 'Reativar assessor'),
        content: Text(
          desativar
              ? '${a.nome} não poderá mais acessar o app nem ver dados da campanha até ser reativado.'
              : 'Restaurar acesso de ${a.nome} ao aplicativo?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(desativar ? 'Desativar' : 'Reativar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _toggleAtivo = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await setAssessorAtivo(assessorId: a.id, ativo: !desativar);
      if (!mounted) return;
      widget.onRefresh();
      messenger.showSnackBar(
        SnackBar(content: Text(!desativar ? 'Assessor reativado.' : 'Assessor desativado.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(messageFromException(e))));
    } finally {
      if (mounted) setState(() => _toggleAtivo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assessor = widget.assessor;
    final width = MediaQuery.sizeOf(context).width > 700 ? 320.0 : (MediaQuery.sizeOf(context).width > 500 ? 260.0 : double.infinity);
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cabeçalho: avatar + nome + status
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    radius: 24,
                    child: Text(
                      assessor.initial,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          assessor.nome,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Chip(
                          label: Text(
                            assessor.ativo ? 'Ativo' : 'Inativo',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: assessor.ativo ? Colors.green.shade800 : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          backgroundColor: assessor.ativo ? Colors.green.shade100 : theme.colorScheme.surfaceContainerHighest,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Contato
              if (assessor.email != null || assessor.telefone != null) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                if (assessor.email != null)
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          assessor.email!,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (assessor.email != null && assessor.telefone != null) const SizedBox(height: 6),
                if (assessor.telefone != null)
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Text(assessor.telefone!, style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
              // Ações (candidato)
              if (widget.isCandidato) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _toggleAtivo ? null : _alternarAtivo,
                      icon: _toggleAtivo
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(assessor.ativo ? Icons.person_off_outlined : Icons.check_circle_outline, size: 18),
                      label: Text(assessor.ativo ? 'Desativar' : 'Reativar'),
                      style: TextButton.styleFrom(
                        foregroundColor: assessor.ativo ? theme.colorScheme.error : Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: (_reenviando || !assessor.ativo) ? null : _reenviarConvite,
                      icon: _reenviando
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.email_outlined, size: 18),
                      label: const Text('Reenviar convite'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _removendo ? null : _confirmarRemover,
                      icon: _removendo
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remover'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

