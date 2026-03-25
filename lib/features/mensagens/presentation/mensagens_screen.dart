import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/visita.dart';
import '../../agenda/providers/agenda_provider.dart';
import '../providers/mensagens_provider.dart';

class MensagensScreen extends ConsumerWidget {
  const MensagensScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _Header(),
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Mensagens'),
              Tab(icon: Icon(Icons.cake_outlined), text: 'Aniversariantes'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _MensagensTab(),
                _AniversariantesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Mensagens', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const EstadoMTBadge(compact: true),
        ],
      ),
    );
  }
}

// ── Tab Mensagens ─────────────────────────────────────────────────────────────

class _MensagensTab extends ConsumerWidget {
  const _MensagensTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final count = ref.watch(mensagensCountProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(mensagensCountProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                label: Text('${count.valueOrNull ?? 0} mensagens'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Nova Mensagem'),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Center(
            child: Column(
              children: [
                Icon(Icons.send, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text('Nenhuma mensagem', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Crie mensagens globais, regionais ou de reunião',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// ── Tab Aniversariantes ───────────────────────────────────────────────────────

class _AniversariantesTab extends ConsumerWidget {
  const _AniversariantesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hojeAsync = ref.watch(aniversariantesHojeProvider);
    final proximosAsync = ref.watch(aniversariantesProximos30Provider);
    final allAsync = ref.watch(aniversariantesProvider);

    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
      data: (_) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(aniversariantesProvider);
          await ref.read(aniversariantesProvider.future).then((_) {}).onError((_, __) {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hoje ──────────────────────────────────────────────────────
            hojeAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (hoje) {
                if (hoje.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text('🎂', style: TextStyle(fontSize: 28)),
                          const SizedBox(width: 12),
                          Text(
                            hoje.length == 1
                                ? '${hoje.first.nome} faz aniversário HOJE!'
                                : '${hoje.length} pessoas fazem aniversário HOJE!',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...hoje.map((a) => _AniversarianteCard(aniversariante: a, destaque: true)),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),

            // ── Próximos 30 dias ───────────────────────────────────────────
            proximosAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (proximos) {
                if (proximos.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.cake_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('Nenhum aniversário nos próximos 30 dias.',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text(
                            'Cadastre datas de nascimento nos apoiadores e assessores para aparecerem aqui.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Próximos 30 dias', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    ...proximos.map((a) => _AniversarianteCard(aniversariante: a)),
                  ],
                );
              },
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AniversarianteCard extends StatelessWidget {
  const _AniversarianteCard({required this.aniversariante, this.destaque = false});
  final Aniversariante aniversariante;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = aniversariante;

    String tipoLabel;
    Color tipoColor;
    switch (a.tipo) {
      case 'apoiador':
        tipoLabel = 'Apoiador';
        tipoColor = theme.colorScheme.primary;
        break;
      case 'assessor':
        tipoLabel = 'Assessor';
        tipoColor = theme.colorScheme.secondary;
        break;
      default:
        tipoLabel = 'Votante';
        tipoColor = theme.colorScheme.tertiary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: destaque
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.primary, width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(destaque ? '🎂' : '🎁', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(a.nome, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tipoColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tipoLabel, style: theme.textTheme.labelSmall?.copyWith(color: tipoColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destaque
                        ? '${a.idadeAnos} anos hoje! — ${DateFormat('dd/MM').format(a.dataNascimento)}'
                        : '${a.diasParaAniversario} dias — ${DateFormat('dd/MM').format(a.dataNascimento)} (${a.idadeAnos + 1} anos)',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Botão WhatsApp
            if (a.whatsappUrl.isNotEmpty)
              Tooltip(
                message: 'Enviar felicitação pelo WhatsApp',
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () async {
                    final uri = Uri.parse(a.whatsappUrl);
                    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

