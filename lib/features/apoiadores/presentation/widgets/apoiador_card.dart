import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/convite_link_dialog.dart';
import '../../../../models/apoiador.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/apoiadores_provider.dart' show convidarApoiadorPorEmail, reenviarConviteApoiador;
import '../dialogs/editar_apoiador_dialog.dart';
import '../../../mapa/data/mt_municipios_coords.dart' show displayNomeCidadeMT;
import '../utils/apoiadores_form_utils.dart';

class ApoiadorCard extends ConsumerWidget {
  const ApoiadorCard({
    super.key,
    required this.apoiador,
    required this.podeEditar,
    required this.onRefresh,
  });

  final Apoiador apoiador;
  final bool podeEditar;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width > 800 ? 380.0 : double.infinity;
    final cidadeDisplay = apoiador.cidadeNome != null ? displayNomeCidadeMT(apoiador.cidadeNome!) : null;
    final profile = ref.watch(profileProvider).valueOrNull;
    final podeConvidarEquipe = profile?.role == 'candidato' || profile?.role == 'assessor';
    final emailConvite = emailParaConviteApoiador(apoiador);
    final mostrarConvite = podeConvidarEquipe && apoiador.profileId == null && emailConvite != null;

    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  if (mostrarConvite) ...[
                    IconButton(
                      icon: const Icon(Icons.mark_email_read_outlined),
                      tooltip: 'Convidar por e-mail (acesso ao app)',
                      onPressed: () async {
                        try {
                          final link = await convidarApoiadorPorEmail(apoiadorId: apoiador.id);
                          onRefresh();
                          if (!context.mounted) return;
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
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceFirst('Exception: ', '')),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.forward_to_inbox_outlined),
                      tooltip: 'Reenviar convite',
                      onPressed: () async {
                        try {
                          final link = await reenviarConviteApoiador(apoiadorId: apoiador.id);
                          if (!context.mounted) return;
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
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceFirst('Exception: ', '')),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                  if (podeEditar)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _abrirEditar(context),
                      tooltip: 'Editar apoiador',
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

  Future<void> _abrirEditar(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => EditarApoiadorDialog(apoiador: apoiador, onSaved: onRefresh),
    );
  }
}
