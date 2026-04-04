import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/mensagem.dart';
import '../../../models/visita.dart';
import '../../agenda/providers/agenda_provider.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../mensagens/providers/mensagens_provider.dart';

class ApoiadorHomeScreen extends ConsumerWidget {
  const ApoiadorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final apoiadorAsync = ref.watch(meuApoiadorProvider);
    final visitasAsync = ref.watch(visitasProvider);
    final mensagensAsync = ref.watch(mensagensListProvider);

    final apoiador = apoiadorAsync.valueOrNull;
    final mensagens = mensagensAsync.valueOrNull ?? [];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(meuApoiadorProvider);
        ref.invalidate(visitasProvider);
        ref.invalidate(mensagensListProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olá, ${profile?.fullName?.split(' ').first ?? (profile?.role == 'votante' ? 'Amigo' : 'Apoiador')}! 👋',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        profile?.role == 'votante'
                            ? (profile?.email ?? '')
                            : (apoiador?.cidadeNome ?? apoiador?.nome ?? ''),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const EstadoMTBadge(compact: true),
              ],
            ),
            const SizedBox(height: 20),

            // ── Agenda ─────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Agenda',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                TextButton(
                  onPressed: () => context.go('/agenda'),
                  child: const Text('Ver completa'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            visitasAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text(
                'Não foi possível carregar a agenda: $e',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
              data: (visitas) {
                if (visitas.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'Nenhum evento futuro na agenda por enquanto.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                final slice = visitas.length > 8 ? visitas.sublist(0, 8) : visitas;
                return Column(
                  children: [
                    ...slice.map((v) => _VisitaHomeTile(visita: v)),
                    if (visitas.length > 8)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+ ${visitas.length - 8} na agenda completa',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // ── Mensagens da campanha ─────────────────────────────────────
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                    theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 22, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mensagens da campanha',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Avisos e comunicados enviados pela equipe aparecem aqui.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (mensagensAsync.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (mensagens.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.mark_chat_unread_outlined,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Nenhuma mensagem por enquanto.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quando houver novidades, você verá aqui e pode receber notificação no celular.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...mensagens.map((m) => _MensagemCard(mensagem: m)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitaHomeTile extends StatelessWidget {
  const _VisitaHomeTile({required this.visita});

  final Visita visita;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = visita;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
          child: Icon(Icons.event_outlined, color: theme.colorScheme.primary, size: 22),
        ),
        title: Text(v.titulo, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            v.dataHoraFormatada,
            if (v.municipioNome != null && v.municipioNome!.trim().isNotEmpty) v.municipioNome!,
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _MensagemCard extends StatelessWidget {
  const _MensagemCard({required this.mensagem});
  final Mensagem mensagem;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = mensagem;
    final enviada = m.enviadaEm != null;
    final fmtData = m.enviadaEm != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(m.enviadaEm!.toLocal())
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.campaign_outlined, size: 16, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m.titulo,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (enviada)
                  Text(
                    fmtData,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
            if (m.corpo != null && m.corpo!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(m.corpo!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}
