import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/candidato_raiz_provider.dart';
import '../../../core/utils/candidato_campanha.dart';
import '../../../core/widgets/estado_mt_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dados_tse/providers/dados_tse_provider.dart';
import '../../estrategia/providers/regioes_fundidas_provider.dart';
import '../data/mt_municipios_coords.dart';
import '../providers/mapa_camadas_filtradas_provider.dart';
import '../providers/mapa_filtros_provider.dart';
import '../providers/benfeitorias_mapa_provider.dart';
import '../providers/metas_regiao_provider.dart';
import '../providers/mapa_visual_prefs_provider.dart';
import 'widgets/benfeitorias_municipio_panel.dart';
import 'widgets/mapa_benfeitorias_legenda.dart';
import 'widgets/mapa_kpis_regiao_panel.dart';
import 'widgets/mapa_regional_widget.dart';
import 'widgets/mapa_tse_legenda.dart';

/// Modo de exibição: tela cheia (menu Mapa) ou embutido no Dashboard (altura fixa).
enum MapaPanelMode {
  /// Ocupa o espaço vertical restante (`Expanded`).
  fullScreen,

  /// Dentro de scroll: mapa com altura responsiva fixa.
  embedded,
}

class LocaisVotacaoPanel extends StatelessWidget {
  const LocaisVotacaoPanel({
    super.key,
    required this.nomeMunicipio,
    required this.onClose,
    required this.estimativaPorCidade,
  });

  final String nomeMunicipio;
  final VoidCallback onClose;
  final Map<String, int> estimativaPorCidade;

  @override
  Widget build(BuildContext context) {
    final displayNome = displayNomeCidadeMT(nomeMunicipio);
    final theme = Theme.of(context);
    return Consumer(
      builder: (context, ref, _) {
        final async = ref.watch(locaisVotacaoPorMunicipioProvider(nomeMunicipio));
        final votosPorMunicipio = ref.watch(votosPorMunicipioTseProvider).valueOrNull ?? {};
        final votosTseCidade = votosPorMunicipio[nomeMunicipio] ?? 0;
        final estimativaCidade = estimativaPorCidade[normalizarNomeMunicipioMT(nomeMunicipio)] ?? 0;
        return Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.place, color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Locais de votação — $displayNome',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onClose,
                    tooltip: 'Fechar',
                  ),
                ],
              ),
            ),
            if (estimativaCidade > 0 || votosTseCidade > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Estimativa (campanha): $estimativaCidade  •  Votos 2022 (TSE): $votosTseCidade',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: async.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Nenhum local de votação encontrado para esta cidade na base TSE (2022).',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final totalCidade = list.fold<int>(0, (s, e) => s + e.votos);
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final loc = list[i];
                      final pct = totalCidade > 0 ? (loc.votos / totalCidade * 100) : 0.0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(Icons.location_on_outlined, color: theme.colorScheme.onPrimaryContainer, size: 20),
                          ),
                          title: Text(
                            loc.nome,
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (loc.endereco != null && loc.endereco!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    loc.endereco!,
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${loc.votos} votos${totalCidade > 0 ? ' (${pct.toStringAsFixed(1)}% do total da cidade)' : ''}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Erro ao carregar locais: $e',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Conjunto completo: filtros, legenda TSE, KPIs, mapa interativo e rodapé.
class MapaRegionalPanel extends ConsumerStatefulWidget {
  const MapaRegionalPanel({
    super.key,
    this.mode = MapaPanelMode.fullScreen,
    this.showTitleRow = true,
  });

  final MapaPanelMode mode;
  final bool showTitleRow;

  @override
  ConsumerState<MapaRegionalPanel> createState() => _MapaRegionalPanelState();
}

class _MapaRegionalPanelState extends ConsumerState<MapaRegionalPanel> {
  String? _selectedMunicipio;
  /// Fonte de verdade **síncrona** do modo (o [MapaRegionalWidget] lê antes do próximo rebuild com a prop antiga).
  final ValueNotifier<String> _painelModoNv = ValueNotifier('nenhum');

  static const _modosValidos = {'nenhum', 'tse', 'rede', 'comparativo', 'metas', 'benfeitorias'};

  static String _normalizarModoPainel(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty || !_modosValidos.contains(t)) return 'nenhum';
    return t;
  }

  /// Altura do cartão do mapa no Dashboard (embutido no scroll).
  /// Em desktop, aproxima um **quadrado** e usa um teto alto no viewport para aproveitar bem o ecrã.
  static double _embeddedMapHeight(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h = MediaQuery.sizeOf(context).height;
    // Cartão mais alto no telemóvel: mapa + ranking em coluna precisam de altura total generosa.
    if (w < 720) {
      return (h * 0.92).clamp(720.0, 1100.0);
    }
    if (w < 1100) {
      return (h * 0.64).clamp(580.0, 860.0);
    }
    // Largura útil aproximada (menu lateral + margens do dashboard)
    final contentW = math.max(420.0, w - 260.0);
    final quadrado = contentW * 0.96;
    final tetoViewport = h * 0.84;
    final raw = math.min(quadrado, tetoViewport);
    return raw.clamp(400.0, 1020.0);
  }

  @override
  void dispose() {
    _painelModoNv.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final votosAjustados = ref.watch(mapaVotosTseAjustadosProvider);
    // Dados brutos para o ranking (independentes dos toggles de visibilidade)
    final votosTseRaw = ref.watch(votosPorMunicipioTseProvider).valueOrNull ?? {};
    final estimativaRaw = ref.watch(mapaEstimativaRawProvider);
    final estimativaPorCidade = ref.watch(mapaEstimativaFiltradaProvider);
    final marcadores = ref.watch(mapaMarcadoresFiltradosProvider);
    final filtros = ref.watch(mapaFiltrosProvider);
    final regioesFundidas = ref.watch(regioesFundidasParaMapaProvider);
    final nomesCustomizados = ref.watch(nomesCustomizadosProvider).valueOrNull ?? {};
    final coresCustomizadas = ref.watch(coresCustomizadasProvider).valueOrNull ?? {};
    final isAdmin = ref.watch(isAdminProvider);
    final benfeitoriasRanking = ref.watch(benfeitoriasRankingRegioesProvider).valueOrNull;
    final profile = ref.watch(profileProvider).valueOrNull;
    final metasCampanha = ref.watch(metasRegiaoCampanhaProvider).valueOrNull ?? {};
    final candidatoRaizAsync = ref.watch(candidatoRaizCampanhaProfileIdProvider);
    final podeMetasRegiao = candidatoRaizAsync.maybeWhen(
      data: (id) => id != null && id.isNotEmpty,
      orElse: () => candidatoCampanhaProfileId(profile) != null,
    );
    final mapaVisual = ref.watch(mapaVisualPrefsProvider);

    final width = MediaQuery.sizeOf(context).width;
    final padding = width < 600 ? 12.0 : 16.0;
    final embedded = widget.mode == MapaPanelMode.embedded;
    final viewportH = MediaQuery.sizeOf(context).height;
    /// Só em viewports muito baixos o Column+Expanded pode estourar; em telemóvel com altura normal
    /// usamos o mesmo mapa em [Expanded] que no desktop (comportamento alinhado ao PC).
    final useScrollableFullScreen = !embedded && viewportH < 640;
    final scrollMapHeight = math.max(360.0, math.min(720.0, viewportH * 0.68));
    final mapH = embedded ? _embeddedMapHeight(context) : (useScrollableFullScreen ? scrollMapHeight : double.infinity);

    final mapCard = Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: MapaRegionalWidget(
        height: mapH,
        pontosMapaEscala: mapaVisual.escalaPontos,
        contornoMapaEscala: mapaVisual.escalaContorno,
        // TSE: para ranking usa dados brutos; para círculos no mapa usa dados ajustados pelo toggle
        votosPorMunicipio: votosTseRaw.isNotEmpty ? votosTseRaw : (votosAjustados.isEmpty ? null : votosAjustados),
        // Estimativa: para ranking usa dados brutos; para marcadores no mapa usa dados filtrados
        estimativaPorCidade: estimativaRaw.isNotEmpty ? estimativaRaw : (estimativaPorCidade.isEmpty ? null : estimativaPorCidade),
        cidadesMarcadoresMapa: marcadores.isEmpty ? null : marcadores,
        regioesFundidas: regioesFundidas.isEmpty ? null : regioesFundidas,
        nomesCustomizados: nomesCustomizados.isEmpty ? null : nomesCustomizados,
        coresCustomizadas: coresCustomizadas.isEmpty ? null : coresCustomizadas,
        onSaveNomeRegiao: isAdmin
            ? (cdRgint, nome) {
                ref.read(nomesCustomizadosProvider.notifier).setNome(cdRgint, nome);
              }
            : null,
        onRemoverDaFusao: isAdmin
            ? (cdRgint) {
                ref.read(regioesFundidasProvider.notifier).removeCdRgintFromFusion(cdRgint);
              }
            : null,
        onSaveCorRegiao: isAdmin
            ? (cdRgint, hexCor) {
                ref.read(coresCustomizadasProvider.notifier).setCor(cdRgint, hexCor);
              }
            : null,
        onCityTap: (nome) => setState(() => _selectedMunicipio = nome),
        onMostrarTSE: (v) {
          if (v != filtros.mostrarTSE) ref.read(mapaFiltrosProvider.notifier).toggleTSE();
        },
        onMostrarMarcadores: (v) {
          if (v != filtros.mostrarMarcadores) ref.read(mapaFiltrosProvider.notifier).toggleMarcadores();
        },
        onComparativoColors: (_, {Map<String, double>? ratios, bool incluirLabelsZero = false}) {},
        benfeitoriasRanking: benfeitoriasRanking,
        painelRankingModo: _painelModoNv.value,
        painelRankingModoNotifier: _painelModoNv,
        metasPorRegiao: podeMetasRegiao ? metasCampanha : null,
        onSalvarMetas: podeMetasRegiao
            ? (m) => ref.read(metasRegiaoCampanhaProvider.notifier).save(m)
            : null,
        onPainelRankingModoChanged: (m) {
          final prev = _painelModoNv.value;
          final next = _normalizarModoPainel(m);
          if (prev == next) return;
          // Modo no notifier tem de ser síncrono com o onTap do painel (senão o mapa aplica Metas e o tab
          // ainda mostra Comparativo um frame — pisca vermelho/âmbar). O setState do pai só limpa município.
          _painelModoNv.value = next;
          Future.microtask(() {
            if (!mounted) return;
            setState(() {
              if (prev == 'benfeitorias' && next != 'benfeitorias') _selectedMunicipio = null;
            });
          });
        },
        mostrarTSE: filtros.mostrarTSE,
        mostrarMarcadores: filtros.mostrarMarcadores,
        locaisVotacaoContent: _selectedMunicipio != null
            ? (_painelModoNv.value == 'benfeitorias'
                ? BenfeitoriasMunicipioPanel(
                    municipioChaveOuNome: _selectedMunicipio!,
                    onClose: () => setState(() => _selectedMunicipio = null),
                  )
                : LocaisVotacaoPanel(
                    nomeMunicipio: _selectedMunicipio!,
                    estimativaPorCidade: estimativaPorCidade,
                    onClose: () => setState(() => _selectedMunicipio = null),
                  ))
            : null,
        selectedMunicipioKey: _selectedMunicipio,
        // Ecrã estreito: ranking sempre abaixo do mapa (sem overlay). Larguras ≥720 usam painel lateral.
        embedRankingBelowMap: width < 720,
      ),
    );

    final children = <Widget>[
      if (widget.showTitleRow) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                embedded ? 'Mapa regional da campanha' : 'Mapa Regional',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const EstadoMTBadge(compact: true),
          ],
        ),
        SizedBox(height: padding * 0.5),
      ],
      // Legenda TSE (oculta no modo benfeitorias) ou legenda em R$ para benfeitorias por região
      if (votosTseRaw.isNotEmpty && _painelModoNv.value != 'benfeitorias') ...[
        MapaTseLegenda(votosPorCidade: votosTseRaw),
        SizedBox(height: padding * 0.5),
      ],
      if (_painelModoNv.value == 'benfeitorias') ...[
        const MapaBenfeitoriasLegenda(),
        SizedBox(height: padding * 0.5),
      ],
      const MapaKpisRegiaoPanel(),
      SizedBox(height: padding * 0.5),
      if (embedded)
        SizedBox(height: mapH, child: mapCard)
      else if (useScrollableFullScreen)
        SizedBox(height: mapH, child: mapCard)
      else
        Expanded(child: mapCard),
      const SizedBox(height: 8),
      Text(
        _painelModoNv.value == 'benfeitorias'
            ? (votosAjustados.isEmpty && marcadores.isEmpty
                ? 'No modo Benfeitorias, toque numa cidade na lista do painel para ver os registos, valores e dados do apoiador vinculado.'
                : 'Modo Benfeitorias ativo: na lista ao lado, toque na cidade para ver cada benfeitoria e o apoiador do cadastro. Noutros modos, o toque na cidade abre locais de votação (TSE).')
            : _painelModoNv.value == 'metas'
                ? 'Modo Metas: defina e acompanhe metas por região na lista ao lado. O mapa mantém-se como nas outras visualizações (sem camada extra de metas).'
            : (votosAjustados.isEmpty && marcadores.isEmpty
                ? 'Mapa interativo MT com regiões e cidades. Selecione seu candidato 2022 em Meu perfil para ver votos por cidade. Cadastre apoiadores e votantes (com município) para marcar cidades no mapa.'
                : 'Mapa com ${votosAjustados.length} cidade(s) com votos (TSE) e ${marcadores.length} cidade(s) com apoiadores ou votantes. Toque numa cidade (mapa ou lista) para ver locais de votação e endereços.'),
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    ];

    if (useScrollableFullScreen) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: embedded ? MainAxisSize.min : MainAxisSize.max,
      children: children,
    );
  }
}
