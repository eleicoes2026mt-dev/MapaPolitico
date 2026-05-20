import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/amigos_gilberto.dart';
import '../../../core/utils/formato_pt_br.dart';
import '../../../core/widgets/estado_mt_badge.dart';

import '../../assessores/providers/gestao_campanha_provider.dart';
import '../providers/painel_indicacoes_provider.dart';

enum _OrdenacaoAssessor {
  porEstimativaApoiadores,
  porTotalApoiadores,
  porVotantesRede,
  porVotosFamiliaRede,
  porNome,
}

class PainelIndicacoesScreen extends ConsumerStatefulWidget {
  const PainelIndicacoesScreen({super.key});

  @override
  ConsumerState<PainelIndicacoesScreen> createState() =>
      _PainelIndicacoesScreenState();
}

class _PainelIndicacoesScreenState extends ConsumerState<PainelIndicacoesScreen> {
  _OrdenacaoAssessor _ordem = _OrdenacaoAssessor.porEstimativaApoiadores;

  List<PainelIndicacaoPorAssessor> _ordenar(
    List<PainelIndicacaoPorAssessor> raw,
    _OrdenacaoAssessor o,
  ) {
    final copy = List<PainelIndicacaoPorAssessor>.from(raw);
    int cmp(PainelIndicacaoPorAssessor a, PainelIndicacaoPorAssessor b) {
      switch (o) {
        case _OrdenacaoAssessor.porEstimativaApoiadores:
          final d = b.estimativaVotosApoiadores.compareTo(a.estimativaVotosApoiadores);
          return d != 0 ? d : a.assessorNome.compareTo(b.assessorNome);
        case _OrdenacaoAssessor.porTotalApoiadores:
          final d = b.totalApoiadoresAtivos.compareTo(a.totalApoiadoresAtivos);
          return d != 0 ? d : a.assessorNome.compareTo(b.assessorNome);
        case _OrdenacaoAssessor.porVotantesRede:
          final d = b.totalVotantesRede.compareTo(a.totalVotantesRede);
          return d != 0 ? d : a.assessorNome.compareTo(b.assessorNome);
        case _OrdenacaoAssessor.porVotosFamiliaRede:
          final d = b.somaVotosFamiliaRede.compareTo(a.somaVotosFamiliaRede);
          return d != 0 ? d : a.assessorNome.compareTo(b.assessorNome);
        case _OrdenacaoAssessor.porNome:
          return a.assessorNome.toLowerCase().compareTo(b.assessorNome.toLowerCase());
      }
    }

    copy.sort(cmp);
    return copy;
  }

  String _rotuloOrdem(_OrdenacaoAssessor o) {
    switch (o) {
      case _OrdenacaoAssessor.porEstimativaApoiadores:
        return 'Estimativa dos apoiadores';
      case _OrdenacaoAssessor.porTotalApoiadores:
        return 'Qtd. apoiadores';
      case _OrdenacaoAssessor.porVotantesRede:
        return 'Total de votantes (rede)';
      case _OrdenacaoAssessor.porVotosFamiliaRede:
        return 'Votos (família) na rede';
      case _OrdenacaoAssessor.porNome:
        return 'Nome do assessor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final podePainel = ref.watch(podeGestaoCampanhaCompletaProvider);

    if (!podePainel) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Este painel é exclusivo do candidato ou de assessores de grau 1.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final aggAsync = ref.watch(painelIndicacoesProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(painelIndicacoesProvider);
        await ref.read(painelIndicacoesProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Rede de indicações',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const EstadoMTBadge(compact: true),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ranking por assessor (quem cadastrou os apoiadores). Em cada um, '
              'veja quantos ${kAmigosGilbertoLabel.toLowerCase()} cada apoiador trouxe '
              'e as somas de estimativa de votos e votos em família.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            aggAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'Erro: $e',
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
              data: (agg) {
                if (agg == null) return const SizedBox.shrink();

                final linhasOrd = _ordenar(agg.porAssessor, _ordem);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PainelTopoTotaisTermometro(
                      theme: theme,
                      agg: agg,
                      labelAmigosGilberto: kAmigosGilbertoLabel,
                    ),
                    if (agg.totalVotantesSomadosFamiliaViaRede > 0 &&
                        agg.porAssessor.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _DistribuicaoVotosAssessoresCampanha(
                          theme: theme,
                          porAssessor: agg.porAssessor,
                          totalFamiliaCampanha:
                              agg.totalVotantesSomadosFamiliaViaRede,
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      'Ordenação do ranking',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<_OrdenacaoAssessor>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: _OrdenacaoAssessor.porEstimativaApoiadores,
                          label: Text(
                            _rotuloOrdem(_OrdenacaoAssessor.porEstimativaApoiadores),
                          ),
                          icon: const Icon(Icons.show_chart, size: 18),
                        ),
                        ButtonSegment(
                          value: _OrdenacaoAssessor.porTotalApoiadores,
                          label:
                              Text(_rotuloOrdem(_OrdenacaoAssessor.porTotalApoiadores)),
                          icon: const Icon(Icons.people_outline, size: 18),
                        ),
                        ButtonSegment(
                          value: _OrdenacaoAssessor.porVotantesRede,
                          label:
                              Text(_rotuloOrdem(_OrdenacaoAssessor.porVotantesRede)),
                          icon: const Icon(Icons.checklist_rounded, size: 18),
                        ),
                      ],
                      selected: {_ordem},
                      onSelectionChanged: (s) {
                        setState(() => _ordem = s.first);
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(_rotuloOrdem(_OrdenacaoAssessor.porVotosFamiliaRede)),
                          selected:
                              _ordem == _OrdenacaoAssessor.porVotosFamiliaRede,
                          onSelected: (_) => setState(
                            () =>
                                _ordem = _OrdenacaoAssessor.porVotosFamiliaRede,
                          ),
                        ),
                        ChoiceChip(
                          label: Text(_rotuloOrdem(_OrdenacaoAssessor.porNome)),
                          selected: _ordem == _OrdenacaoAssessor.porNome,
                          onSelected: (_) =>
                              setState(() => _ordem = _OrdenacaoAssessor.porNome),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Por assessor',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(linhasOrd.length, (index) {
                      final row = linhasOrd[index];
                      return _ExpansionAssessor(
                        rank: index + 1,
                        data: row,
                        theme: theme,
                        aggCampanha: agg,
                      );
                    }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartão combinado: totais agregados + termómetro (estimativa da rede × referência oficial TSE 2022).
class _PainelTopoTotaisTermometro extends StatelessWidget {
  const _PainelTopoTotaisTermometro({
    required this.theme,
    required this.agg,
    required this.labelAmigosGilberto,
  });

  final ThemeData theme;
  final PainelIndicacoesAgg agg;
  final String labelAmigosGilberto;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final mediaFamAp = agg.totalApoiadoresNaBase > 0
        ? agg.subtotalVotosFamiliaTodosVotantes / agg.totalApoiadoresNaBase
        : null;
    final tseRef = agg.votosOficiaisTseUltimaCorridaCampanha;
    final est = agg.totalEstimativaAlinhadoDashboard;
    final ratioVsTse = tseRef > 0 ? est / tseRef : null;
    /// Barra e líquido do termômetro: 100% visual = igualou a marca TSE (≥ referência → cheio).
    double barraVsUltimaCorrida(double? ratio) {
      if (ratio == null || !ratio.isFinite) return 0.0;
      if (ratio >= 1.0) return 1.0;
      return ratio.clamp(0.0, 1.0);
    }

    final barFracUltimaCorrida =
        ratioVsTse != null ? barraVsUltimaCorrida(ratioVsTse) : 0.0;

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 780;
        final totaisCard = Card(
          elevation: 0,
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Totais consolidados da rede',
                  style:
                      theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Est. votos (Σ) usa o mesmo critério do dashboard: Σ estimativa em todos os apoiadores + Σ votos em família em todos os votantes.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  children: [
                    _KvpTotal(
                      theme: theme,
                      icon: Icons.groups_2_outlined,
                      label: 'Apoiadores ativos',
                      valor: formatarInteiroPtBr(agg.totalApoiadoresCampanhaAtivos),
                    ),
                    _KvpTotal(
                      theme: theme,
                      icon: Icons.show_chart_rounded,
                      label: 'Est. votos (Σ) · dashboard',
                      valor: formatarInteiroPtBr(est),
                    ),
                    _KvpTotal(
                      theme: theme,
                      icon: Icons.hub_outlined,
                      label: 'Cadastros $labelAmigosGilberto',
                      valor:
                          formatarInteiroPtBr(agg.totalCadastrosVotantesNaRede),
                    ),
                    _KvpTotal(
                      theme: theme,
                      icon: Icons.how_to_vote_outlined,
                      label: 'Votos (família) Σ · dashboard',
                      valor: formatarInteiroPtBr(
                          agg.subtotalVotosFamiliaTodosVotantes),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Composição: ${formatarInteiroPtBr(agg.subtotalEstimativaTodosApoiadores)} (Σ estimativa apoiadores) '
                  '+ ${formatarInteiroPtBr(agg.subtotalVotosFamiliaTodosVotantes)} (Σ família nos votantes) '
                  '= ${formatarInteiroPtBr(est)}.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.95),
                    height: 1.4,
                  ),
                ),
                if (mediaFamAp != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '~${formatarInteiroPtBr(mediaFamAp.round())} votos em família por linha de apoiador '
                    '(Σ família nos votantes / linhas em apoiadores)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.8),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

        final termoCard = Card(
          elevation: 0,
          color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          clipBehavior: Clip.hardEdge,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.device_thermostat_rounded,
                        color: cs.tertiary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Engajamento vs última corrida oficial (TSE)',
                        style:
                            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (agg.campanhaTseVinculada &&
                    agg.votosOficiaisTseUltimaCorridaCampanha > 0) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _DestaqueCorridaOfficial(
                          theme: theme,
                          rotuloCurto: 'Última corrida oficial (TSE)',
                          rotuloRodape: 'MT · eleição 2022',
                          valor: formatarInteiroPtBr(tseRef),
                          sufixo: 'votos válidos declarados pelo TSE',
                          esquema: DestaqueCorridaEsquema.referencia,
                        ),
                        _DestaqueCorridaOfficial(
                          theme: theme,
                          rotuloCurto: 'Estimativa (igual «Est. Votos» do dashboard)',
                          rotuloRodape: 'Painel atual',
                          valor: formatarInteiroPtBr(est),
                          sufixo: ratioVsTse != null && ratioVsTse.isFinite
                              ? '${(ratioVsTse * 100).round()}% dessa marca'
                              : '—',
                          esquema: DestaqueCorridaEsquema.atual,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Comparativo: uso a votação recebida em 2022 como referência objetiva '
                    '(não é meta eleitoral de 2026).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (!agg.campanhaTseVinculada ||
                    agg.votosOficiaisTseUltimaCorridaCampanha <= 0)
                  Row(
                    children: [
                      Icon(Icons.link_off_rounded,
                          color: cs.error.withValues(alpha: 0.9), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Associe o candidato ao arquivo TSE 2022 em «Meu perfil» '
                          'para carregar esta referência e ligar o termómetro.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.error,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: _TermometroVertical(
                          fillFrac: barFracUltimaCorrida,
                          aquecimento: ratioVsTse != null && ratioVsTse.isFinite
                              ? ratioVsTse.clamp(0.0, 2.5)
                              : 0.0,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (ratioVsTse != null && ratioVsTse.isFinite) ...[
                              Text(
                                '${((ratioVsTse * 100).round()).clamp(0, 999999)}% '
                                'em relação à última eleição (referência TSE)',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${formatarInteiroPtBr(est)} declarados nesta métrica de estimativa · '
                                'marca oficial 2022: ${formatarInteiroPtBr(tseRef)} votos.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Barra: 100% = igualou aos ${formatarInteiroPtBr(tseRef)} votos '
                                'da última corrida oficial.',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color:
                                      cs.onSurfaceVariant.withValues(alpha: 0.9),
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _BarrinhaProgresso(
                                frac: barFracUltimaCorrida,
                                trackColor: cs.surfaceContainerHighest
                                    .withValues(alpha: 0.92),
                                barColor: ratioVsTse >= 1.0
                                    ? Colors.lightGreenAccent
                                    : cs.primary,
                                height: 8,
                                semanticsLabel:
                                    'Percentual vs última eleição TSE',
                              ),
                              if (ratioVsTse >= 1.0) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Estimativa agregada igual ou acima dos votos oficiais '
                                  'registrados em 2022 (declarações da rede podem ser otimistas).',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.lightGreenAccent
                                        .withValues(alpha: 0.95),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              if (ratioVsTse < 1.0) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Para igualar só o resultado 2022, faltariam pelo menos '
                                  '${formatarInteiroPtBr(max(0, tseRef - est))} votos nesta métrica de estimativa '
                                  '(não projeta cenário nem quociente eleitoral).',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.85),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );

        return wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 55, child: totaisCard),
                  const SizedBox(width: 14),
                  Expanded(flex: 45, child: termoCard),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  totaisCard,
                  const SizedBox(height: 14),
                  termoCard,
                ],
              );
      },
    );
  }
}

enum DestaqueCorridaEsquema { referencia, atual }

class _DestaqueCorridaOfficial extends StatelessWidget {
  const _DestaqueCorridaOfficial({
    required this.theme,
    required this.rotuloCurto,
    required this.rotuloRodape,
    required this.valor,
    required this.sufixo,
    required this.esquema,
  });

  final ThemeData theme;
  final String rotuloCurto;
  final String rotuloRodape;
  final String valor;
  final String sufixo;
  final DestaqueCorridaEsquema esquema;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final ref = esquema == DestaqueCorridaEsquema.referencia;
    final bg = ref
        ? cs.secondaryContainer.withValues(alpha: 0.45)
        : cs.primaryContainer.withValues(alpha: 0.45);
    final border = ref ? cs.secondary : cs.primary;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 168, maxWidth: 308),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border.withValues(alpha: 0.42)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rotuloCurto.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0.55,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                valor,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                  height: 1.08,
                  letterSpacing: -0.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                sufixo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.32,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                rotuloRodape,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: border.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KvpTotal extends StatelessWidget {
  const _KvpTotal({
    required this.theme,
    required this.icon,
    required this.label,
    required this.valor,
  });

  final ThemeData theme;
  final IconData icon;
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 148, maxWidth: 220),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Termômetro visual (tubo + bulbo).
class _TermometroVertical extends StatelessWidget {
  const _TermometroVertical({
    required this.fillFrac,
    required this.aquecimento,
  });

  final double fillFrac;
  final double aquecimento;

  @override
  Widget build(BuildContext context) {
    const tubeH = 106.0;
    const bulbR = 17.5;
    final frac = fillFrac.clamp(0.0, 1.0);
    final aq = aquecimento.clamp(0.0, 2.5);
    final liq =
        Color.lerp(
              const Color(0xFF1565C0),
              const Color(0xFFFF6E40),
              aq > 1 ? 1.0 : aq,
            ) ??
            const Color(0xFF1565C0);

    return SizedBox(
      width: bulbR * 2 + 8,
      height: tubeH + bulbR * 2 + 10,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: tubeH,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Colors.white.withValues(alpha: 0.08)),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: 0.74,
                      heightFactor: frac,
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              liq,
                              liq.withValues(alpha: 0.85),
                              liq.withValues(alpha: 0.5),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: bulbR * 2,
            height: bulbR * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: liq.withValues(alpha: 0.95),
              boxShadow: [
                BoxShadow(
                  color: liq.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Percentual inteiro tipo `42%`, evitando `intl` para Web.
String _pctInt(int numerador, int denominador) {
  if (denominador <= 0) return '0%';
  final p = (numerador * 100 / denominador).floor().clamp(0, 100);
  return '$p%';
}

class _BarrinhaProgresso extends StatelessWidget {
  const _BarrinhaProgresso({
    required this.frac,
    required this.trackColor,
    required this.barColor,
    this.height = 7,
    this.semanticsLabel,
  });

  /// 0.0 … 1.0
  final double frac;
  final Color trackColor;
  final Color barColor;
  final double height;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final clamped = frac.isNaN ? 0.0 : frac.clamp(0.0, 1.0);
    return Semantics(
      label: semanticsLabel,
      value: _pctInt((clamped * 100).round(), 100),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: LinearProgressIndicator(
          value: clamped,
          minHeight: height,
          backgroundColor: trackColor,
          valueColor: AlwaysStoppedAnimation<Color>(barColor),
        ),
      ),
    );
  }
}

/// Barra única sobre a linha inteira para ver o peso de cada assessor no total da campanha.
class _DistribuicaoVotosAssessoresCampanha extends StatelessWidget {
  const _DistribuicaoVotosAssessoresCampanha({
    required this.theme,
    required this.porAssessor,
    required this.totalFamiliaCampanha,
  });

  final ThemeData theme;
  final List<PainelIndicacaoPorAssessor> porAssessor;
  final int totalFamiliaCampanha;

  static List<Color> _cores(ThemeData t, int n) {
    final bases = [
      t.colorScheme.primary,
      t.colorScheme.secondary,
      t.colorScheme.tertiary,
      t.colorScheme.error,
      t.colorScheme.primaryFixed,
      t.colorScheme.secondaryFixed,
    ];
    if (bases.isEmpty) return List.filled(max(1, n), Colors.blueGrey);
    return List.generate(n, (i) => bases[i % bases.length]);
  }

  @override
  Widget build(BuildContext context) {
    if (totalFamiliaCampanha <= 0) return const SizedBox.shrink();
    final ord = [...porAssessor]
      ..sort(
        (a, b) => b.somaVotosFamiliaRede.compareTo(a.somaVotosFamiliaRede),
      );
    final comPeso = ord.where((a) => a.somaVotosFamiliaRede > 0).toList();
    if (comPeso.isEmpty) return const SizedBox.shrink();

    final cores = _cores(theme, comPeso.length);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Peso dos assessores nos votos (família) da rede',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'A barra mostra cada fatia relativamente aos ${formatarInteiroPtBr(totalFamiliaCampanha)} votos somados na campanha.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final w = max(8.0, c.maxWidth);
                var leftPx = 0.0;
                final children = <Widget>[];
                for (var i = 0; i < comPeso.length; i++) {
                  final ass = comPeso[i];
                  final part = ass.somaVotosFamiliaRede;
                  double segPx = w * part / totalFamiliaCampanha;
                  if (segPx > 0 && segPx < 3) segPx = 3;
                  if (segPx <= 0) continue;
                  if (leftPx + segPx > w + 1) segPx = w - leftPx;
                  children.add(
                    Positioned(
                      left: leftPx,
                      width: segPx,
                      height: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: cores[i]),
                      ),
                    ),
                  );
                  leftPx += segPx;
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 12,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        ColoredBox(
                          color: theme.colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.75),
                          child: const SizedBox.expand(),
                        ),
                        ...children,
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var i = 0;
                    i < comPeso.length && i < 10;
                    i++)
                  Tooltip(
                    message:
                        '${comPeso[i].assessorNome}\n${_pctInt(comPeso[i].somaVotosFamiliaRede, totalFamiliaCampanha)} da rede • ${formatarInteiroPtBr(comPeso[i].somaVotosFamiliaRede)} votos',
                    child: Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cores[i],
                              borderRadius:
                                  BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxWidth: 160),
                            child: Text(
                              '${_pctInt(comPeso[i].somaVotosFamiliaRede, totalFamiliaCampanha)} • '
                              '${comPeso[i].assessorNome}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color:
                                    theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricaComValorEBarra extends StatelessWidget {
  const _MetricaComValorEBarra({
    required this.label,
    required this.linhaValor,
    required this.progresso,
    this.barColor,
    this.spacingAfter = 12,
  });

  final String label;
  /// Texto destacado ao lado direito da primeira linha (ex.: número • percentual).
  final String linhaValor;
  final double progresso;
  final Color? barColor;
  final double spacingAfter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tc = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9);
    final bc = barColor ?? theme.colorScheme.primary;
    return Padding(
      padding: EdgeInsets.only(bottom: spacingAfter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  linhaValor,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _BarrinhaProgresso(
            frac: progresso,
            trackColor: tc,
            barColor: bc,
            semanticsLabel: label,
          ),
        ],
      ),
    );
  }
}

class _ChipMetricaCompacta extends StatelessWidget {
  const _ChipMetricaCompacta({
    required this.icone,
    required this.rotuloCurto,
    required this.valor,
    required this.theme,
    this.cor,
  });

  final IconData icone;
  final String rotuloCurto;
  final String valor;
  final ThemeData theme;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    final c = cor ?? theme.colorScheme.primary;
    final bg =
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: c.withValues(alpha: 0.26),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 17, color: c),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rotuloCurto,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
              Text(
                valor,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinhaApoiadorBarrasLocais extends StatelessWidget {
  const _LinhaApoiadorBarrasLocais({
    required this.linha,
    required this.theme,
    required this.fracEst,
    required this.fracVt,
    required this.fracFamilia,
    this.dense = false,
  });

  final PainelIndicacaoPorApoiador linha;
  final ThemeData theme;
  final double fracEst;
  final double fracVt;
  final double fracFamilia;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92);
    return Padding(
      padding: dense
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            linha.apoiadorNome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _MetricMiniBar(
            label: 'Est. votos',
            valorFmt: formatarInteiroPtBr(linha.estimativaVotos),
            frac: fracEst,
            theme: theme,
            trackColor: t,
            barColor: theme.colorScheme.secondary,
          ),
          const SizedBox(height: 6),
          _MetricMiniBar(
            label: kAmigosGilbertoLabel,
            valorFmt:
                '${formatarInteiroPtBr(linha.totalVotantes)} cadastro(s)',
            frac: fracVt,
            theme: theme,
            trackColor: t,
            barColor: theme.colorScheme.primary,
          ),
          const SizedBox(height: 6),
          _MetricMiniBar(
            label: 'Votos (família)',
            valorFmt: formatarInteiroPtBr(linha.somaVotosFamilia),
            frac: fracFamilia,
            theme: theme,
            trackColor: t,
            barColor: theme.colorScheme.tertiary,
          ),
        ],
      ),
    );
  }
}

class _MetricMiniBar extends StatelessWidget {
  const _MetricMiniBar({
    required this.label,
    required this.valorFmt,
    required this.frac,
    required this.theme,
    required this.trackColor,
    required this.barColor,
  });

  final String label;
  final String valorFmt;
  final double frac;
  final ThemeData theme;
  final Color trackColor;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              valorFmt,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _BarrinhaProgresso(
          frac: frac,
          trackColor: trackColor,
          barColor: barColor,
          height: 6,
          semanticsLabel: label,
        ),
      ],
    );
  }
}

class _ExpansionAssessor extends StatelessWidget {
  const _ExpansionAssessor({
    required this.rank,
    required this.data,
    required this.theme,
    required this.aggCampanha,
  });

  final int rank;
  final PainelIndicacaoPorAssessor data;
  final ThemeData theme;
  final PainelIndicacoesAgg aggCampanha;

  @override
  Widget build(BuildContext context) {
    final denomAp = max(1, data.totalApoiadoresAtivos);
    final fracCobreApoiadores =
        (data.apoiadoresComVotantes / denomAp).clamp(0.0, 1.0);
    final pctCobre =
        '${_pctInt(data.apoiadoresComVotantes, data.totalApoiadoresAtivos)} com votantes';

    final totalFamCamp = aggCampanha.totalVotantesSomadosFamiliaViaRede;
    final fracCampanha = totalFamCamp > 0
        ? (data.somaVotosFamiliaRede / totalFamCamp).clamp(0.0, 1.0)
        : 0.0;
    final txtCampanha = totalFamCamp > 0
        ? '${_pctInt(data.somaVotosFamiliaRede, totalFamCamp)} da rede • ${formatarInteiroPtBr(data.somaVotosFamiliaRede)}'
        : formatarInteiroPtBr(data.somaVotosFamiliaRede);

    final maxEst =
        data.linhasPorApoiador.fold<int>(0, (m, x) => max(m, x.estimativaVotos));
    final maxVt = data.linhasPorApoiador
        .fold<int>(0, (m, x) => max(m, x.totalVotantes));
    final maxFam = data.linhasPorApoiador
        .fold<int>(0, (m, x) => max(m, x.somaVotosFamilia));

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          child: Text('$rank'),
        ),
        title: Text(
          data.assessorNome,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChipMetricaCompacta(
                  theme: theme,
                  icone: Icons.person_outline,
                  rotuloCurto: 'Apoiadores',
                  valor: '${data.totalApoiadoresAtivos}',
                ),
                _ChipMetricaCompacta(
                  theme: theme,
                  icone: Icons.show_chart,
                  rotuloCurto: 'Est. votos',
                  valor: formatarInteiroPtBr(data.estimativaVotosApoiadores),
                  cor: theme.colorScheme.secondary,
                ),
                _ChipMetricaCompacta(
                  theme: theme,
                  icone: Icons.hub_outlined,
                  rotuloCurto: kAmigosGilbertoLabel,
                  valor: '${data.totalVotantesViaApoiadores}',
                  cor: theme.colorScheme.primary,
                ),
                _ChipMetricaCompacta(
                  theme: theme,
                  icone: Icons.groups_2_outlined,
                  rotuloCurto: 'Votos (família) rede',
                  valor: formatarInteiroPtBr(data.somaVotosFamiliaViaApoiadores),
                  cor: theme.colorScheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (data.totalApoiadoresAtivos > 0) ...[
              Text(
                'Cobertura da rede (apoiadores com ao menos um $kAmigosGilbertoLabel)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              _BarrinhaProgresso(
                frac: fracCobreApoiadores,
                trackColor:
                    theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.92,
                ),
                barColor: theme.colorScheme.primary,
                semanticsLabel: 'Cobertura',
              ),
              const SizedBox(height: 4),
              Text(
                '$pctCobre • ${formatarInteiroPtBr(data.apoiadoresComVotantes)} de ${formatarInteiroPtBr(data.totalApoiadoresAtivos)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Peso nos votos (família) de toda a campanha',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            _BarrinhaProgresso(
              frac: fracCampanha,
              trackColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.92,
              ),
              barColor: theme.colorScheme.tertiary,
              semanticsLabel: 'Peso na campanha',
            ),
            const SizedBox(height: 4),
            Text(
              txtCampanha,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Indicadores do assessor',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _MetricaComValorEBarra(
                  label:
                      'Apoiadores da rede que já conseguiram $kAmigosGilbertoLabel',
                  linhaValor:
                      '${formatarInteiroPtBr(data.apoiadoresComVotantes)} de ${formatarInteiroPtBr(data.totalApoiadoresAtivos)} (${_pctInt(data.apoiadoresComVotantes, data.totalApoiadoresAtivos)})',
                  progresso: fracCobreApoiadores,
                  barColor: theme.colorScheme.primary,
                ),
                _MetricaComValorEBarra(
                  label: 'Peso deste assessor na soma da campanha (votos família rede)',
                  linhaValor: txtCampanha,
                  progresso: fracCampanha,
                  barColor: theme.colorScheme.tertiary,
                  spacingAfter: 16,
                ),
                _MetricRow(
                  label:
                      '$kAmigosGilbertoLabel cadastrados por apoiadores deste assessor',
                  valor: '${data.totalVotantesViaApoiadores} cadastro(s) • '
                      '${formatarInteiroPtBr(data.somaVotosFamiliaViaApoiadores)} votos (família)',
                ),
                const SizedBox(height: 6),
                if (data.totalVotantesViaApoiadores > 0 ||
                    data.somaVotosFamiliaViaApoiadores > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Estes valores somam apenas o que veio através de apoiadores; '
                      'cadastro direto do assessor aparece logo abaixo (se houver).',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                if (data.votantesDiretosSemApoiador > 0) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading:
                        Icon(Icons.person_pin_circle_outlined, color: theme.colorScheme.tertiary),
                    title: const Text(
                      'Cadastros diretos pelo assessor (sem apoiador)',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${data.votantesDiretosSemApoiador} $kAmigosGilbertoLabel • '
                      '${formatarInteiroPtBr(data.somaVotosFamiliaDiretos)} votos (família)',
                    ),
                  ),
                ],
                const Divider(height: 24),
                Text(
                  'Apoiadores (detalhe)',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'As barras de cada métrica comparam esse apoiador ao maior valor dentro deste assessor ($kAmigosGilbertoLabel maior vê barra cheia).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                ...data.linhasPorApoiador.asMap().entries.map((e) {
                  final i = e.key;
                  final a = e.value;
                  final isLast = i == data.linhasPorApoiador.length - 1;
                  final fEst =
                      maxEst > 0 ? (a.estimativaVotos / maxEst).clamp(0.0, 1.0) : 0.0;
                  final fVt =
                      maxVt > 0 ? (a.totalVotantes / maxVt).clamp(0.0, 1.0) : 0.0;
                  final fFam =
                      maxFam > 0 ? (a.somaVotosFamilia / maxFam).clamp(0.0, 1.0) : 0.0;
                  return Column(
                    children: [
                      _LinhaApoiadorBarrasLocais(
                        linha: a,
                        theme: theme,
                        fracEst: fEst,
                        fracVt: fVt,
                        fracFamilia: fFam,
                        dense: isLast,
                      ),
                      if (!isLast)
                        Divider(
                          height: 24,
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.55),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.valor});

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
