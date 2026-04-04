import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/navigation_keys.dart';
import '../../../../core/widgets/convite_link_dialog.dart';
import '../../../../models/apoiador.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../assessores/providers/assessores_provider.dart' show messageFromException;
import '../../providers/apoiadores_provider.dart'
    show convidarApoiadorPorEmail, excluirApoiador, reenviarConviteApoiador, revogarAcessoApoiador;
import '../dialogs/editar_apoiador_dialog.dart';
import '../../../mapa/data/mt_municipios_coords.dart' show displayNomeCidadeMT;
import '../utils/apoiadores_form_utils.dart';

class ApoiadorCard extends ConsumerStatefulWidget {
  const ApoiadorCard({
    super.key,
    required this.apoiador,
    required this.podeEditar,
    this.podeRevogarAcesso = false,
    this.podeExcluir = false,
    required this.onRefresh,
    this.compact = false,
  });

  final Apoiador apoiador;
  final bool podeEditar;
  final bool podeRevogarAcesso;
  final bool podeExcluir;
  final VoidCallback onRefresh;
  /// Linha densa (lista paginada); mantém as mesmas ações do cartão.
  final bool compact;

  @override
  ConsumerState<ApoiadorCard> createState() => _ApoiadorCardState();
}

class _ApoiadorCardState extends ConsumerState<ApoiadorCard> {
  /// Com [ShellRoute] + GoRouter na web, `useRootNavigator: true` pode abrir o diálogo por baixo do menu.
  BuildContext get _dialogContext => shellNavigatorKey.currentContext ?? context;

  Future<void> _abrirEditar() async {
    if (!mounted) return;
    await showDialog<void>(
      context: _dialogContext,
      useRootNavigator: false,
      builder: (ctx) => EditarApoiadorDialog(apoiador: widget.apoiador, onSaved: widget.onRefresh),
    );
  }

  Future<void> _confirmarExcluir() async {
    if (!mounted) return;
    final nome = widget.apoiador.nome;
    final ok = await showDialog<bool>(
      context: _dialogContext,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir apoiador da campanha?'),
        content: Text(
          '"$nome" deixa de aparecer na lista. '
          'Se tinha login no app, a conta fica desativada e ele não entra mais. '
          'Votantes e benfeitorias ligados a este apoiador permanecem no sistema; o cadastro deixa de aparecer na campanha até restaurar. '
          'Em Configurações → Registro de alterações você pode restaurar o apoiador.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    try {
      await excluirApoiador(widget.apoiador.id);
      widget.onRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Apoiador excluído. O acesso ao app foi desativado. Restaure em Configurações → Registro de alterações, se precisar.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messageFromException(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _confirmarRevogar() async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: _dialogContext,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Revogar acesso ao app'),
        content: Text(
          'O apoiador "${widget.apoiador.nome}" não poderá mais entrar com a conta atual. '
          'Nome, cidade, votantes e demais dados cadastrais permanecem na campanha. '
          'É possível enviar novo convite depois, se desejar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Revogar acesso'),
          ),
        ],
      ),
    );
    if (!mounted || ok != true) return;
    try {
      await revogarAcessoApoiador(widget.apoiador.id);
      widget.onRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acesso revogado. Os dados do apoiador foram mantidos.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messageFromException(e)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  static const _compactIconConstraints = BoxConstraints(minWidth: 36, minHeight: 36);

  Future<void> _convidarPorEmail() async {
    final theme = Theme.of(context);
    final apoiador = widget.apoiador;
    try {
      final link = await convidarApoiadorPorEmail(apoiadorId: apoiador.id);
      widget.onRefresh();
      if (!mounted) return;
      if (link != null && link.isNotEmpty) {
        await showConviteLinkDialog(
          context,
          link: link,
          title: 'Link de acesso do apoiador',
          description:
              'O convite também foi enviado por e-mail. Copie o link e envie pelo WhatsApp se a mensagem não chegar. Com o acesso, o apoiador cadastra votantes que aparecem no mapa.',
          snackbarMessage: 'Link copiado.',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Convite enviado por e-mail. Se não chegar, confira spam ou reenvie e use o link copiável quando aparecer.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  Future<void> _reenviarConvite() async {
    final theme = Theme.of(context);
    final apoiador = widget.apoiador;
    try {
      final link = await reenviarConviteApoiador(apoiadorId: apoiador.id);
      if (!mounted) return;
      if (link != null && link.isNotEmpty) {
        await showConviteLinkDialog(
          context,
          link: link,
          title: 'Link de convite (reenvio)',
          description: 'Copie e envie pelo WhatsApp se o e-mail não chegar.',
          snackbarMessage: 'Link copiado.',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Convite reenviado por e-mail.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  Widget _compactTrailing(ThemeData theme, Apoiador apoiador, bool mostrarConvite) {
    return SizedBox(
      height: 42,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mostrarConvite) ...[
              IconButton(
                icon: const Icon(Icons.mark_email_read_outlined, size: 20),
                tooltip: 'Convidar por e-mail (acesso ao app)',
                constraints: _compactIconConstraints,
                padding: EdgeInsets.zero,
                onPressed: _convidarPorEmail,
              ),
              IconButton(
                icon: const Icon(Icons.forward_to_inbox_outlined, size: 20),
                tooltip: 'Reenviar convite',
                constraints: _compactIconConstraints,
                padding: EdgeInsets.zero,
                onPressed: _reenviarConvite,
              ),
            ],
            if (widget.podeRevogarAcesso && apoiador.profileId != null)
              IconButton(
                icon: const Icon(Icons.link_off_outlined, size: 20),
                tooltip: 'Revogar acesso ao app (dados permanecem)',
                constraints: _compactIconConstraints,
                padding: EdgeInsets.zero,
                onPressed: _confirmarRevogar,
              ),
            if (widget.podeExcluir)
              IconButton(
                icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                tooltip: 'Excluir apoiador da campanha (restaurar em Configurações)',
                constraints: _compactIconConstraints,
                padding: EdgeInsets.zero,
                onPressed: _confirmarExcluir,
              ),
            if (widget.podeEditar)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: _abrirEditar,
                tooltip: 'Editar apoiador',
                constraints: _compactIconConstraints,
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  Widget _compactSubtitle(ThemeData theme, String? cidadeDisplay) {
    final a = widget.apoiador;
    final parts = <String>[
      if (cidadeDisplay != null) cidadeDisplay,
      '~${a.estimativaVotos} votos',
      if (a.telefone != null && a.telefone!.trim().isNotEmpty) a.telefone!.trim(),
    ];
    return Text(
      parts.join(' · '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width > 800 ? 380.0 : double.infinity;
    final apoiador = widget.apoiador;
    final cidadeDisplay = apoiador.cidadeNome != null ? displayNomeCidadeMT(apoiador.cidadeNome!) : null;
    final profile = ref.watch(profileProvider).valueOrNull;
    final podeConvidarEquipe = profile?.role == 'candidato' || profile?.role == 'assessor';
    final emailConvite = emailParaConviteApoiador(apoiador);
    final mostrarConvite = podeConvidarEquipe && apoiador.profileId == null && emailConvite != null;

    if (widget.compact) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: CircleAvatar(
            radius: 18,
            backgroundColor: apoiador.isPJ ? Colors.purple.shade100 : Colors.green.shade100,
            child: apoiador.isPJ
                ? Icon(Icons.business, size: 18, color: Colors.purple.shade700)
                : Text(apoiador.initial, style: TextStyle(fontSize: 13, color: Colors.green.shade800, fontWeight: FontWeight.w600)),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  apoiador.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (apoiador.perfil != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    apoiador.perfil!,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _compactSubtitle(theme, cidadeDisplay),
          ),
          trailing: _compactTrailing(theme, apoiador, mostrarConvite),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: apoiador.isPJ ? Colors.purple.shade100 : Colors.green.shade100,
                    child: apoiador.isPJ
                        ? Icon(Icons.business, color: Colors.purple.shade700)
                        : Text(apoiador.initial, style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(apoiador.nome, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        if (apoiador.perfil != null)
                          Chip(
                            label: Text(apoiador.perfil!, style: theme.textTheme.labelSmall),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        if (cidadeDisplay != null)
                          Text(cidadeDisplay, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (mostrarConvite) ...[
                    IconButton(
                      icon: const Icon(Icons.mark_email_read_outlined),
                      tooltip: 'Convidar por e-mail (acesso ao app)',
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      padding: EdgeInsets.zero,
                      onPressed: _convidarPorEmail,
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_to_inbox_outlined),
                      tooltip: 'Reenviar convite',
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      padding: EdgeInsets.zero,
                      onPressed: _reenviarConvite,
                    ),
                  ],
                  if (widget.podeRevogarAcesso && apoiador.profileId != null)
                    IconButton(
                      icon: const Icon(Icons.link_off_outlined),
                      tooltip: 'Revogar acesso ao app (dados permanecem)',
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      padding: EdgeInsets.zero,
                      onPressed: _confirmarRevogar,
                    ),
                  if (widget.podeExcluir)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      tooltip: 'Excluir apoiador da campanha (restaurar em Configurações)',
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      padding: EdgeInsets.zero,
                      onPressed: _confirmarExcluir,
                    ),
                  if (widget.podeEditar)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _abrirEditar,
                      tooltip: 'Editar apoiador',
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      padding: EdgeInsets.zero,
                    ),
                ],
              ),
              if (apoiador.telefone != null) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.phone, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(apoiador.telefone!, style: theme.textTheme.bodySmall),
                ]),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.people, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    '~${apoiador.estimativaVotos} votos estimados',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (apoiador.votosPrometidosUltimaEleicao != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.history, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Legado: ${apoiador.votosPrometidosUltimaEleicao} votos prometidos (última eleição)',
                      style: theme.textTheme.bodySmall,
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
