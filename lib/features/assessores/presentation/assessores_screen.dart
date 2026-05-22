import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/amigos_gilberto.dart';
import '../../../core/router/navigation_keys.dart';
import '../../../core/router/profile_role_cache.dart';
import '../../../core/widgets/confirmar_senha_deputado_dialog.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../models/assessor.dart';
import '../../apoiadores/providers/apoiadores_provider.dart'
    show apoiadoresListProvider;
import '../../mapa/providers/benfeitorias_agg_provider.dart'
    show benfeitoriasAggPorMunicipioProvider;
import '../../votantes/providers/votantes_provider.dart'
    show votantesIndicacaoRedeListProvider, votantesListProvider;
import '../providers/assessores_provider.dart'
    show
        assessoresListProvider,
        meuAssessorRegistroProvider,
        convidarAssessor,
        ConvidarAssessorResult,
        reenviarConviteAssessor,
        removerAssessor,
        promoverACandidato,
        messageFromException,
        setAssessorAtivo,
        setAssessorGrauAcesso,
        atualizarAssessorLinkInstagram,
        rebaixarAssessorParaPapel;
import '../providers/gestao_campanha_provider.dart';
import '../../configuracoes/providers/menu_access_provider.dart';

/// Link de convite para enviar por WhatsApp se o e-mail do Supabase não chegar.
Future<void> showLinkConviteAssessorDialog(BuildContext context, String link) async {
  final dlgContext = shellNavigatorKey.currentContext ?? context;
  if (!dlgContext.mounted) return;
  final messengerCtx = shellNavigatorKey.currentContext ?? context;
  await showDialog<void>(
    context: dlgContext,
    useRootNavigator: false,
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
              if (messengerCtx.mounted) {
                ScaffoldMessenger.of(messengerCtx).showSnackBar(
                  const SnackBar(content: Text('Link copiado. Cole no WhatsApp e envie ao assessor.')),
                );
              }
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

  /// ShellRoute na web: `useRootNavigator: true` põe diálogo atrás do menu lateral.
  BuildContext get _dialogContext => shellNavigatorKey.currentContext ?? context;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(registerMenuAccessProvider)('assessores');
    });
  }

  void _openNovoAssessorDialog(BuildContext context) {
    showDialog<void>(
      context: _dialogContext,
      useRootNavigator: false,
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
    final podeGestao = ref.watch(podeGestaoCampanhaCompletaProvider);
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
              if (podeGestao) ...[
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () => _openNovoAssessorDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Assessor'),
                ),
              ],
            ],
          ),
          if (podeGestao)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Grau 1: mesmo nível de gestão do candidato. Grau 2: gestão atual (dados e convites de apoiadores). Defina o grau ao convidar ou no cartão.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          if (!podeGestao) ...[
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
                    podeGestao: podeGestao,
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
  final _instagramController = TextEditingController();
  final _telefoneController = TextEditingController();
  bool _loading = false;
  String? _error;
  int _grauAcesso = 2;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _instagramController.dispose();
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
        grauAcesso: _grauAcesso,
        linkInstagram: _instagramController.text.trim().isEmpty ? null : _instagramController.text.trim(),
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
                'Grau 1: acesso equivalente ao do candidato. Grau 2: gestão padrão (dados e convites). O assessor receberá e-mail para criar a senha.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: DropdownButton<int>(
                  value: _grauAcesso,
                  isExpanded: true,
                  hint: const Text('Grau de acesso'),
                  onChanged: _loading
                      ? null
                      : (v) {
                          if (v != null) setState(() => _grauAcesso = v);
                        },
                  items: const [
                    DropdownMenuItem(value: 2, child: Text('Grau 2 — padrão')),
                    DropdownMenuItem(value: 1, child: Text('Grau 1 — como o candidato')),
                  ],
                ),
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
                controller: _instagramController,
                decoration: const InputDecoration(
                  labelText: 'Instagram (opcional)',
                  hintText: 'https://instagram.com/… ou @usuario',
                  prefixIcon: Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
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
    required this.podeGestao,
    required this.onRefresh,
  });

  final Assessor assessor;
  final bool podeGestao;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_AssessorCard> createState() => _AssessorCardState();
}

class _AssessorCardState extends ConsumerState<_AssessorCard> {
  bool _reenviando = false;
  bool _removendo = false;
  bool _rebaixando = false;
  bool _toggleAtivo = false;
  bool _grauUpdating = false;

  BuildContext get _dialogContext => shellNavigatorKey.currentContext ?? context;

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
    final senhaOk = await confirmarSenhaDeputado(_dialogContext);
    if (!senhaOk || !mounted) return;
    final confirm = await showDialog<bool>(
      context: _dialogContext,
      useRootNavigator: false,
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

  Future<void> _rebaixarAssessorFluxo() async {
    final destinoRaw = await showDialog<String>(
      context: _dialogContext,
      useRootNavigator: false,
      builder: (ctx) {
        final t = Theme.of(ctx);
        return AlertDialog(
        title: const Text('Rebaixar papel'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'A conta de ${widget.assessor.nome} mantém-se (mesmo e-mail/login). '
                'Só muda o menu e as permissões na app.',
                style: t.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'apoiador'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(14),
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.how_to_vote_outlined, color: t.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tornar apoiador',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Painel de apoiadores: convida votantes/regiões, sem o menu completo da equipa.',
                            style: t.textTheme.bodySmall?.copyWith(
                              color: t.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, 'votante_amigos'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(14),
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.diversity_2_outlined, color: t.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tornar $kAmigosGilbertoLabel',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Volta ao cadastro público (rede/indicações de $kAmigosGilbertoLabel), '
                            'sem papel de equipa técnica.',
                            style: t.textTheme.bodySmall?.copyWith(
                              color: t.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ],
      );
      },
    );

    final destino = destinoRaw?.trim();
    if (destino == null || destino.isEmpty || !mounted) return;

    final labelAlvo =
        destino == 'apoiador' ? 'apoiador' : '$kAmigosGilbertoLabel (votação/indicações)';
    final ok = await showDialog<bool>(
      context: _dialogContext,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(
          'Rebaixar ${widget.assessor.nome} para $labelAlvo? '
          'O cadastro do assessor precisa ter e-mail e município preenchidos neste cartão. '
          'A pessoa deve sair da app e voltar a entrar para ver as novas opções.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rebaixar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!context.mounted) return;

    setState(() => _rebaixando = true);
    final scaffoldCtx =
        shellNavigatorKey.currentContext ?? context;
    final messenger = ScaffoldMessenger.of(scaffoldCtx);
    try {
      await rebaixarAssessorParaPapel(
        assessorId: widget.assessor.id,
        destino: destino,
      );
      if (!mounted) return;
      clearProfileRoleCache();
      ref.invalidate(assessoresListProvider);
      await ref.read(assessoresListProvider.future);
      ref.invalidate(apoiadoresListProvider);
      ref.invalidate(votantesListProvider);
      ref.invalidate(votantesIndicacaoRedeListProvider);
      ref.invalidate(benfeitoriasAggPorMunicipioProvider);
      ref.invalidate(meuAssessorRegistroProvider);
      final meUid = ref.read(currentUserProvider)?.id;
      if (meUid != null && meUid == widget.assessor.profileId) {
        ref.invalidate(profileProvider);
      }
      widget.onRefresh();
      messenger.showSnackBar(
        SnackBar(content: Text('Rebaixado para ${destino == 'apoiador' ? 'apoiador' : kAmigosGilbertoLabel}.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(messageFromException(e)),
          duration: const Duration(seconds: 10),
        ),
      );
    } finally {
      if (mounted) setState(() => _rebaixando = false);
    }
  }

  Future<void> _alterarGrau(int novo) async {
    if (novo == widget.assessor.grauAcesso) return;
    setState(() => _grauUpdating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await setAssessorGrauAcesso(assessorId: widget.assessor.id, grauAcesso: novo);
      if (!mounted) return;
      clearProfileRoleCache();
      widget.onRefresh();
      ref.invalidate(meuAssessorRegistroProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Grau de acesso atualizado.')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(messageFromException(e))));
    } finally {
      if (mounted) setState(() => _grauUpdating = false);
    }
  }

  Future<void> _editarLinkInstagram() async {
    final ctrl = TextEditingController(text: widget.assessor.linkInstagram ?? '');
    final ok = await showDialog<bool>(
      context: _dialogContext,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Instagram do assessor'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'https://instagram.com/… ou @usuario',
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      ctrl.dispose();
      return;
    }
    try {
      await atualizarAssessorLinkInstagram(
        assessorId: widget.assessor.id,
        linkInstagram: ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
      );
      ctrl.dispose();
      if (!mounted) return;
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Instagram atualizado.')));
    } catch (e) {
      ctrl.dispose();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageFromException(e))));
    }
  }

  Future<void> _alternarAtivo() async {
    final a = widget.assessor;
    final desativar = a.ativo;
    final ok = await showDialog<bool>(
      context: _dialogContext,
      useRootNavigator: false,
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
    final uid = ref.watch(currentUserProvider)?.id;
    final podeEditarInstagram = widget.podeGestao || (uid != null && uid == assessor.profileId);
    final igTxt = assessor.linkInstagram?.trim() ?? '';
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
                        if (!widget.podeGestao) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Chip(
                              label: Text(
                                assessor.grauAcesso == 1 ? 'Grau 1 — gestão completa' : 'Grau 2 — padrão',
                                style: theme.textTheme.labelSmall,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // Contato
              if (assessor.email != null ||
                  assessor.telefone != null ||
                  igTxt.isNotEmpty ||
                  podeEditarInstagram) ...[
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
                if ((assessor.email != null || assessor.telefone != null) &&
                    (igTxt.isNotEmpty || podeEditarInstagram))
                  const SizedBox(height: 6),
                if (igTxt.isNotEmpty || podeEditarInstagram)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.link, size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          igTxt.isNotEmpty ? igTxt : 'Instagram não informado',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: igTxt.isEmpty ? FontStyle.italic : null,
                            color: igTxt.isEmpty ? theme.colorScheme.onSurfaceVariant : null,
                          ),
                        ),
                      ),
                      if (podeEditarInstagram)
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Editar Instagram',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => _editarLinkInstagram(),
                        ),
                    ],
                  ),
              ],
              // Ações (candidato ou assessor grau 1)
              if (widget.podeGestao) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Grau: '),
                    if (_grauUpdating)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      DropdownButton<int>(
                        value: assessor.grauAcesso == 1 ? 1 : 2,
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        onChanged: (v) {
                          if (v != null) _alterarGrau(v);
                        },
                        items: const [
                          DropdownMenuItem(value: 2, child: Text('Grau 2 — padrão')),
                          DropdownMenuItem(value: 1, child: Text('Grau 1 — como candidato')),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (_) {
                    final bloqueadoCandidato =
                        widget.assessor.profilesRole?.toLowerCase() == 'candidato';

                    Widget rebaixarBtn = TextButton.icon(
                      onPressed: (_rebaixando || _removendo || bloqueadoCandidato)
                          ? null
                          : _rebaixarAssessorFluxo,
                      icon: _rebaixando
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.arrow_downward_rounded, size: 18),
                      label: const Text('Rebaixar papel'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    );
                    if (bloqueadoCandidato) {
                      rebaixarBtn = Tooltip(
                        message:
                            'Esta linha está ligada ao perfil «candidato» do deputado; não pode ser rebaixada por aqui.',
                        child: rebaixarBtn,
                      );
                    }

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: _toggleAtivo ? null : _alternarAtivo,
                          icon: _toggleAtivo
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(
                                  assessor.ativo ? Icons.person_off_outlined : Icons.check_circle_outline,
                                  size: 18,
                                ),
                          label: Text(assessor.ativo ? 'Desativar' : 'Reativar'),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                assessor.ativo ? theme.colorScheme.error : Colors.green.shade700,
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
                        rebaixarBtn,
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
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

