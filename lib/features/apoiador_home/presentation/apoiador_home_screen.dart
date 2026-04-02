import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/estado_mt_badge.dart';
import '../../../models/mensagem.dart';
import '../../../models/visita.dart';
import '../../agenda/providers/agenda_provider.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../mensagens/providers/mensagens_provider.dart';
import '../../votantes/providers/votantes_provider.dart';

class ApoiadorHomeScreen extends ConsumerWidget {
  const ApoiadorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final apoiadorAsync = ref.watch(meuApoiadorProvider);
    final votantesAsync = ref.watch(votantesListProvider);
    final visitaAsync = ref.watch(proximaVisitaMinhaCidadeProvider);
    final mensagensAsync = ref.watch(mensagensListProvider);

    final apoiador = apoiadorAsync.valueOrNull;
    final votantes = votantesAsync.valueOrNull ?? [];
    final totalVotos = votantes.fold<int>(0, (a, v) => a + v.qtdVotosFamilia);
    final mensagens = mensagensAsync.valueOrNull ?? [];

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(meuApoiadorProvider);
        ref.invalidate(votantesListProvider);
        ref.invalidate(proximaVisitaMinhaCidadeProvider);
        ref.invalidate(mensagensListProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabeçalho ───────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olá, ${profile?.fullName?.split(' ').first ?? 'Apoiador'}! 👋',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        apoiador?.cidadeNome ?? apoiador?.nome ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const EstadoMTBadge(compact: true),
              ],
            ),
            const SizedBox(height: 20),

            // ── Banner: próxima visita ────────────────────────────────────
            visitaAsync.when(
              data: (v) => v != null ? _VisitaBanner(visita: v) : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── KPIs ─────────────────────────────────────────────────────
            const SizedBox(height: 16),
            Text('Minha Rede', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    icon: Icons.how_to_reg_outlined,
                    label: 'Votantes',
                    valor: '${votantes.length}',
                    sub: 'cadastrados',
                    color: theme.colorScheme.primary,
                    loading: votantesAsync.isLoading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.groups_outlined,
                    label: 'Votos na rede',
                    valor: '$totalVotos',
                    sub: 'estimados',
                    color: theme.colorScheme.secondary,
                    loading: votantesAsync.isLoading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _KpiCard(
                    icon: Icons.trending_up_outlined,
                    label: 'Estimativa',
                    valor: '${apoiador?.estimativaVotos ?? 0}',
                    sub: 'meta apoiador',
                    color: theme.colorScheme.tertiary,
                    loading: apoiadorAsync.isLoading,
                  ),
                ),
              ],
            ),

            // ── Últimos votantes ──────────────────────────────────────────
            if (votantes.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Meus Votantes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    '${votantes.length} no total',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...votantes.take(5).map((v) => _VotanteItem(
                    nome: v.nome,
                    cidade: v.cidadeDisplay,
                    votos: v.qtdVotosFamilia,
                    abrangencia: v.abrangencia,
                  )),
              if (votantes.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+ ${votantes.length - 5} votantes — veja em Votantes',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],

            // ── Notificações / Mensagens da campanha ──────────────────────
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.notifications_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Notificações da Campanha',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),

            if (mensagensAsync.isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (mensagens.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.notifications_none, size: 36, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    const SizedBox(height: 8),
                    Text(
                      'Nenhuma notificação ainda.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            else
              ...mensagens.map((m) => _MensagemCard(mensagem: m)),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _VisitaBanner extends StatelessWidget {
  const _VisitaBanner({required this.visita});
  final Visita visita;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('📅', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visita.isHoje ? '🎉 O deputado está na sua cidade HOJE!' : 'Próxima visita do deputado',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  visita.dataHoraFormatada,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                ),
                if (visita.localTexto != null && visita.localTexto!.isNotEmpty)
                  Text(
                    'Local: ${visita.localTexto}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.valor,
    required this.sub,
    required this.color,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final String valor;
  final String sub;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            loading
                ? const SizedBox(height: 28, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
                : Text(
                    valor,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: color),
                  ),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
            Text(sub, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _VotanteItem extends StatelessWidget {
  const _VotanteItem({
    required this.nome,
    required this.cidade,
    required this.votos,
    required this.abrangencia,
  });

  final String nome;
  final String cidade;
  final int votos;
  final String abrangencia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              nome.isNotEmpty ? nome[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 13, color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (cidade.isNotEmpty)
                  Text(cidade, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Chip(
            label: Text('$votos voto${votos != 1 ? "s" : ""}', style: theme.textTheme.labelSmall),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: abrangencia == 'Familiar'
                ? theme.colorScheme.secondaryContainer
                : theme.colorScheme.surfaceContainerHighest,
          ),
        ],
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
