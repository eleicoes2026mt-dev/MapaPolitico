import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../core/constants/regioes_fundidas.dart';
import '../../../../core/router/navigation_keys.dart';
import '../../../../core/utils/formato_pt_br.dart';
import '../../../../core/geo/lat_lng.dart';
import '../../data/geo_loader.dart';
import '../../data/mt_municipios_coords.dart';
import '../../data/tse_votos_escala.dart';
import '../../models/mapa_marcador_cidade.dart';
import '../../providers/benfeitorias_mapa_provider.dart';
import 'bandeira_marcador_widget.dart';

/// [ShellRoute] + GoRouter (web): `context` do mapa pode não ser descendente do overlay
/// correto — usar o [Navigator] do shell evita assert em `InheritedWidget` ao abrir diálogo.
BuildContext _dialogContextForShell(BuildContext context) =>
    shellNavigatorKey.currentContext ?? context;

/// Mapa para **web**: OpenStreetMap + regiões de MT (flutter_map).
/// Mesma funcionalidade de regiões, toque e tooltip que no app mobile.
class MapaRegionalWidget extends StatefulWidget {
  const MapaRegionalWidget({
    super.key,
    this.height = 400,
    this.votosPorMunicipio,
    this.estimativaPorCidade,
    this.cidadesMarcadoresMapa,
    this.regioesFundidas,
    this.nomesCustomizados,
    this.coresCustomizadas,
    this.onSaveNomeRegiao,
    this.onRemoverDaFusao = null,
    this.onSaveCorRegiao,
    this.onRegionTap,
    this.onCityTap,
    this.locaisVotacaoContent,
    this.selectedMunicipioKey,
    this.embedRankingBelowMap = false,
    this.onMostrarTSE,
    this.onMostrarMarcadores,
    this.mostrarTSE = false,
    this.mostrarMarcadores = false,
    this.onComparativoColors,
    this.benfeitoriasRanking,
    this.onBenfeitoriasMapa,
    this.onPainelRankingModoChanged,
    this.metasPorRegiao,
    this.onSalvarMetas,
    this.painelRankingModo = 'nenhum',
    this.painelRankingModoNotifier,
  });

  final double height;
  final Map<String, int>? votosPorMunicipio;
  final Map<String, int>? estimativaPorCidade;
  final Map<String, MapaMarcadorCidade>? cidadesMarcadoresMapa;
  final List<RegiaoFundida>? regioesFundidas;
  final Map<String, String>? nomesCustomizados;
  final Map<String, String>? coresCustomizadas;
  final void Function(String cdRgint, String nome)? onSaveNomeRegiao;
  final void Function(String cdRgint)? onRemoverDaFusao;
  final void Function(String cdRgint, String hexCor)? onSaveCorRegiao;
  final bool Function(String id, String nome, String? cdRgint)? onRegionTap;
  final void Function(String nomeMunicipio)? onCityTap;
  final Widget? locaisVotacaoContent;
  final String? selectedMunicipioKey;
  final bool embedRankingBelowMap;
  /// Callbacks chamados pelo ranking quando o usuário troca de tab (TSE / Minha Rede / Comparativo).
  final void Function(bool)? onMostrarTSE;
  final void Function(bool)? onMostrarMarcadores;
  final bool mostrarTSE;
  final bool mostrarMarcadores;
  final void Function(
    Map<String, String>? cores, {
    Map<String, double>? ratios,
    bool incluirLabelsZero,
  })? onComparativoColors;
  /// Quando não nulo, o painel de ranking pode ativar a camada “Benfeitorias” no mapa.
  final List<BenfeitoriaRegiaoRanking>? benfeitoriasRanking;
  /// Igual a [onComparativoColors], para a camada de benfeitorias (só web).
  final void Function(BenfeitoriasMapaPayload? payload)? onBenfeitoriasMapa;
  /// Só web: `nenhum` | `tse` | `rede` | `comparativo` | `metas` | `benfeitorias` — para legenda no painel pai.
  final ValueChanged<String>? onPainelRankingModoChanged;
  /// Metas de votos por `cd_rgint` (região intermediária), por campanha.
  final Map<String, int>? metasPorRegiao;
  /// Persiste metas; se null, o painel não mostra o modo «Metas».
  final Future<void> Function(Map<String, int> metas)? onSalvarMetas;
  /// `nenhum` | `tse` | `rede` | `comparativo` | `metas` | `benfeitorias` — fonte de verdade no [MapaRegionalPanel].
  final String painelRankingModo;
  /// Quando não nulo (painel da campanha), o ranking lê o modo aqui para não ficar desfasado da prop num frame.
  final ValueNotifier<String>? painelRankingModoNotifier;

  @override
  State<MapaRegionalWidget> createState() => _MapaRegionalWidgetWebState();
}

/// Limites do Brasil (delimitação do território nacional).
/// Restringe a câmera para não mostrar nada além do Brasil; ver assets/geo/delimitacao_brasil.json.
final _brasilBounds = LatLngBounds(
  ll.LatLng(-33.75, -73.99),  // sudoeste Brasil
  ll.LatLng(5.27, -34.79),    // nordeste Brasil
);

/// Destaque da camada Benfeitorias (âmbar: legível em fundo escuro; evita roxo baixo contraste).
const kBenfeitoriasMapaAccent = Color(0xFFFFB300);

/// Cores padrão por cdRgint (hex).
const _coresPadrao = <String, String>{
  '5101': '#2196F3',
  '5102': '#4CAF50',
  '5103': '#FF9800',
  '5104': '#9C27B0',
  '5105': '#F44336',
};

Color _colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return Colors.grey;
  final h = hex.replaceFirst('#', '');
  if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
  return Colors.grey;
}

Color _colorForRegiao(
  String? cdRgint,
  String id,
  Map<String, String>? coresCustomizadas, {
  String? partKey,
  Map<String, String>? comparativoColors,
  Map<String, String>? benfeitoriasColors,
}) {
  // Modo comparativo: cor de atingimento sobrescreve tudo
  if (comparativoColors != null) {
    final cComp = comparativoColors[id] ?? comparativoColors[cdRgint ?? id];
    if (cComp != null) return _colorFromHex(cComp);
  }
  if (benfeitoriasColors != null) {
    final cB = benfeitoriasColors[id] ?? benfeitoriasColors[cdRgint ?? id];
    if (cB != null) return _colorFromHex(cB);
  }
  if (partKey != null) {
    final customPart = coresCustomizadas?[partKey];
    if (customPart != null && customPart.isNotEmpty) return _colorFromHex(customPart);
  }
  final key = cdRgint ?? id;
  final custom = coresCustomizadas?[key];
  if (custom != null && custom.isNotEmpty) return _colorFromHex(custom);
  return _colorFromHex(_coresPadrao[key] ?? '#9E9E9E');
}

/// Prefixo para hitValue dos polígonos de estado (não editáveis).
const String _kEstadoHitPrefix = 'e:';

/// Separa id da região do índice do polígono no hitValue (ex.: "510009#2" -> regiao 510009, polígono 2).
/// Rótulo do ranking: deixa claro que é região intermediária (IBGE), não só o município homônimo.
String _tituloRegiaoRanking(String nome) {
  final t = nome.trim();
  if (t.isEmpty) return 'Região';
  final lower = t.toLowerCase();
  if (lower.startsWith('região de ') || lower.startsWith('regiao de ')) return t;
  return 'Região de $t';
}

String _regiaoIdFromHitValue(String hitValue) {
  final i = hitValue.indexOf('#');
  return i >= 0 ? hitValue.substring(0, i) : hitValue;
}

class _MapaRegionalWidgetWebState extends State<MapaRegionalWidget> {
  final MapController _mapController = MapController();
  final LayerHitNotifier<String> _hitNotifier = ValueNotifier<LayerHitResult<String>?>(null);
  List<RegiaoIntermediariaMT>? _regioes;
  List<RegiaoIntermediariaMT>? _regioesMT;
  String? _hoveredRegionName;
  Offset? _hoverPosition;
  String? _editingRegionId;
  int? _editingPolygonIndex;
  /// Drill-down: só esta região imediata (polígonos + bolhas + marcadores).
  String? _regiaoDrillDownId;
  bool _loading = true;
  String? _error;
  bool _rankingVisivel = false; // começa fechado — usuário abre quando quiser
  /// Cores de atingimento por região (modo Comparativo). null = desativado.
  Map<String, String>? _comparativoColors;
  /// Ratio de atingimento por região (estimativa/TSE ou estimativa/meta). Para exibir % no mapa.
  Map<String, double>? _comparativoRatios;
  /// Comparativo: mostra rótulo «0%» em regiões sem dados quando [incluirLabelsZero].
  bool _comparativoLabelsIncluirZero = false;
  Map<String, String>? _benfeitoriasColors;
  Map<String, double>? _benfeitoriasRatios;
  Map<String, double>? _benfeitoriasValores;

  void _onComparativoCoresFromPanel(
    Map<String, String>? cores, {
    Map<String, double>? ratios,
    bool incluirLabelsZero = false,
  }) {
    setState(() {
      _comparativoLabelsIncluirZero = cores == null ? false : incluirLabelsZero;
      _comparativoColors = cores;
      if (cores != null) {
        _benfeitoriasColors = null;
        _benfeitoriasRatios = null;
        _benfeitoriasValores = null;
      }
      if (cores == null) {
        _comparativoRatios = null;
      } else if (ratios != null) {
        _comparativoRatios = ratios.isEmpty ? null : ratios;
      } else {
        final r = _rankingRegioes();
        final ratioMap = <String, double>{};
        for (final reg in r) {
          if (reg.total > 0) ratioMap[reg.id] = reg.totalEstimativa / reg.total;
        }
        _comparativoRatios = ratioMap.isEmpty ? null : ratioMap;
      }
    });
  }

  void _onBenfeitoriasFromPanel(BenfeitoriasMapaPayload? p) {
    setState(() {
      if (p == null) {
        _benfeitoriasColors = null;
        _benfeitoriasRatios = null;
        _benfeitoriasValores = null;
      } else {
        _comparativoColors = null;
        _comparativoRatios = null;
        _benfeitoriasColors = p.cores;
        _benfeitoriasRatios = p.ratios;
        _benfeitoriasValores = p.valores;
      }
    });
    widget.onBenfeitoriasMapa?.call(p);
  }

  RegiaoIntermediariaMT? get _regiaoDrillDown {
    final id = _regiaoDrillDownId;
    if (id == null) return null;
    return _regioesMT?.where((r) => r.id == id).firstOrNull;
  }

  /// Votos TSE a mostrar nas bolhas — respeitando o toggle mostrarTSE.
  Map<String, int>? get _votosParaBolhas {
    // Se TSE está desligado, não desenha nenhuma bolha
    if (!widget.mostrarTSE) return null;
    final v = widget.votosPorMunicipio;
    if (v == null) return null;
    final reg = _regiaoDrillDown;
    if (reg == null) return v;
    final out = <String, int>{};
    for (final e in v.entries) {
      if (_municipioPertenceRegiao(e.key, reg)) out[e.key] = e.value;
    }
    return out;
  }

  Map<String, MapaMarcadorCidade>? get _marcadoresParaMapa {
    if (!widget.mostrarMarcadores) return null;
    final m = widget.cidadesMarcadoresMapa;
    if (m == null) return null;
    final reg = _regiaoDrillDown;
    if (reg == null) return m;
    final out = <String, MapaMarcadorCidade>{};
    for (final e in m.entries) {
      if (_municipioPertenceRegiao(e.key, reg)) out[e.key] = e.value;
    }
    return out;
  }

  bool _municipioPertenceRegiao(String municipioKey, RegiaoIntermediariaMT reg) {
    final coords = getCoordsMunicipioMT(municipioKey);
    if (coords == null) return false;
    final pt = LatLng(coords.latitude, coords.longitude);
    return pointInRegion(pt, reg.polygons);
  }

  void _setDrillDownRegiao(String? id) {
    setState(() => _regiaoDrillDownId = id);
    if (id == null) {
      _fitCameraTodoEstado();
    } else {
      final reg = _regioesMT?.where((r) => r.id == id).firstOrNull;
      if (reg != null) _fitCameraToRegiao(reg);
    }
  }

  void _fitCameraTodoEstado() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: _brasilBounds,
          padding: const EdgeInsets.all(32),
          maxZoom: 9,
          minZoom: 4,
        ),
      );
    });
  }

  void _fitCameraToRegiao(RegiaoIntermediariaMT regiao) {
    final polys = regiao.polygons;
    if (polys.isEmpty) return;
    var minLat = 90.0;
    var maxLat = -90.0;
    var minLng = 180.0;
    var maxLng = -180.0;
    for (final g in polys) {
      for (final p in g.points) {
        minLat = math.min(minLat, p.latitude);
        maxLat = math.max(maxLat, p.latitude);
        minLng = math.min(minLng, p.longitude);
        maxLng = math.max(maxLng, p.longitude);
      }
    }
    if (minLat >= maxLat || minLng >= maxLng) return;
    final bounds = LatLngBounds(ll.LatLng(minLat, minLng), ll.LatLng(maxLat, maxLng));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
          maxZoom: 12,
          minZoom: 4,
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _loadGeo();
    _hitNotifier.addListener(_onHitChange);
  }

  @override
  void dispose() {
    _hitNotifier.removeListener(_onHitChange);
    super.dispose();
  }

  void _onHitChange() {
    if (!mounted) return;
    final result = _hitNotifier.value;
    if (result == null || result.hitValues.isEmpty) {
      setState(() {
        _hoveredRegionName = null;
        _hoverPosition = null;
      });
      return;
    }
    final firstId = result.hitValues.first;
    String displayName;
    if (firstId.startsWith(_kEstadoHitPrefix)) {
      final id = firstId.substring(_kEstadoHitPrefix.length);
      final regiao = _regioes?.where((r) => r.id == id).firstOrNull;
      displayName = regiao?.nome ?? id;
    } else {
      final regiaoId = _regiaoIdFromHitValue(firstId);
      final regiao = _regioesMT?.where((r) => r.id == regiaoId).firstOrNull;
      if (regiao == null) return;
      // Sempre nome oficial do GeoJSON no mapa (não exibe nomes customizados como "Vale de Peixoto").
      displayName = regiao.nome;
    }
    final pt = result.point;
    setState(() {
      _hoveredRegionName = displayName;
      _hoverPosition = Offset(pt.x, pt.y);
    });
  }

  Future<void> _loadGeo() async {
    try {
      final estados = await loadDelimitacaoEstadosFromAsset();
      final mtRegioes = await loadRegioesImediatasMTFromAsset(kMTRegioesImediatas2024Asset);
      if (!mounted) return;
      setState(() {
        _regioes = estados;
        _regioesMT = mtRegioes;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _regioes = null;
        _regioesMT = null;
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<Polygon<String>> _buildPolygons() {
    final polygons = <Polygon<String>>[];
    final theme = Theme.of(context);

    // 1) Apenas MT: desenha só a delimitação de Mato Grosso (não desenha os outros estados).
    final estados = _regioes;
    if (estados != null) {
      for (final regiao in estados) {
        if (regiao.nome != 'Mato Grosso') continue;
        final borderColor = theme.colorScheme.primary.withValues(alpha: 0.85);
        const strokeWidth = 2.0;
        for (final geo in regiao.polygons) {
          final points = geo.points.map((p) => ll.LatLng(p.latitude, p.longitude)).toList();
          final holes = geo.holes
              .map((hole) => hole.map((p) => ll.LatLng(p.latitude, p.longitude)).toList())
              .toList();
          polygons.add(Polygon<String>(
            points: points,
            holePointsList: holes.isEmpty ? null : holes,
            color: Colors.transparent,
            borderColor: borderColor,
            borderStrokeWidth: strokeWidth,
            hitValue: '$_kEstadoHitPrefix${regiao.id}',
          ));
        }
      }
    }

    // 2) Regiões de MT: comparativo preenche todas; fora disso, borda neutra e destaque leve na região selecionada.
    final mtList = _regioesMT;
    if (mtList != null) {
      const neutralBorder = Color(0xFF757575);
      final inComparativo = _comparativoColors != null && _comparativoColors!.isNotEmpty;
      final inBenfeitorias = _benfeitoriasColors != null && _benfeitoriasColors!.isNotEmpty;
      for (final regiao in mtList) {
        var polygonIndex = 0;
        for (final geo in regiao.polygons) {
          final isEditing = regiao.id == _editingRegionId && polygonIndex == _editingPolygonIndex;
          final partKey = '${regiao.id}#$polygonIndex';
          final color = _colorForRegiao(
            regiao.cdRgint,
            regiao.id,
            widget.coresCustomizadas,
            partKey: partKey,
            comparativoColors: _comparativoColors,
            benfeitoriasColors: _benfeitoriasColors,
          );
          final points = geo.points.map((p) => ll.LatLng(p.latitude, p.longitude)).toList();
          final holes = geo.holes
              .map((hole) => hole.map((p) => ll.LatLng(p.latitude, p.longitude)).toList())
              .toList();
          final isFocused = _regiaoDrillDownId != null && regiao.id == _regiaoDrillDownId;
          final hasComparativoFill = inComparativo && _comparativoColors!.containsKey(regiao.id);
          final hasBenfeitoriasFill = inBenfeitorias && _benfeitoriasColors!.containsKey(regiao.id);

          late final Color fillColor;
          late final Color borderColor;
          late final double borderStrokeWidth;

          if (isEditing) {
            fillColor = color.withValues(alpha: 0.3);
            borderColor = Colors.white;
            borderStrokeWidth = 5;
          } else if (hasComparativoFill || hasBenfeitoriasFill) {
            fillColor = color.withValues(alpha: 0.72);
            borderColor = isFocused ? Colors.white.withValues(alpha: 0.92) : color.withValues(alpha: 0.9);
            borderStrokeWidth = isFocused ? 3.2 : 2;
          } else if (isFocused) {
            fillColor = theme.colorScheme.primary.withValues(alpha: 0.16);
            borderColor = theme.colorScheme.primary.withValues(alpha: 0.82);
            borderStrokeWidth = 2.5;
          } else {
            fillColor = Colors.transparent;
            borderColor = neutralBorder.withValues(alpha: (inComparativo || inBenfeitorias) ? 0.45 : 1);
            borderStrokeWidth = 1;
          }

          polygons.add(Polygon<String>(
            points: points,
            holePointsList: holes.isEmpty ? null : holes,
            color: fillColor,
            borderColor: borderColor,
            borderStrokeWidth: borderStrokeWidth,
            hitValue: '${regiao.id}#$polygonIndex',
          ));
          polygonIndex++;
        }
      }
    }
    return polygons;
  }

  /// Labels de percentual de atingimento por região (modo Comparativo).
  /// Oculta regiões sem dado (ratio = 0) e evita sobreposição por distância mínima.
  List<Marker> _buildComparativoLabels() {
    final ratios = _comparativoRatios;
    final cores = _comparativoColors;
    if (ratios == null || ratios.isEmpty || _regioesMT == null) return [];

    // 1ª passagem: coleta centróides apenas onde há dado real (ratio > 0)
    final candidatos = <({ll.LatLng pos, Color cor, String pct, double ratio})>[];
    for (final regiao in _regioesMT!) {
      final ratio = ratios[regiao.id];
      if (ratio == null) continue;
      if (ratio <= 0.0 && !_comparativoLabelsIncluirZero) continue;

      final hexCor = cores?[regiao.id] ?? '#78909C';
      final cor = _colorFromHex(hexCor);
      final pct = '${(ratio * 100).toStringAsFixed(1)}%';

      if (regiao.polygons.isEmpty) continue;
      final geoPoly = regiao.polygons.reduce((a, b) => a.points.length >= b.points.length ? a : b);
      final pts = geoPoly.points;
      if (pts.isEmpty) continue;
      final lat = pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
      final lng = pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length;
      candidatos.add((pos: ll.LatLng(lat, lng), cor: cor, pct: pct, ratio: ratio));
    }

    // 2ª passagem: anti-sobreposição — mantém o badge mais relevante por célula de grade
    // Ordena pelo maior ratio primeiro (mais importante = fica visível)
    candidatos.sort((a, b) => b.ratio.compareTo(a.ratio));
    const minDist = 1.4; // graus (≈ 155 km em MT) — ajustar conforme zoom desejado
    final aceitos = <({ll.LatLng pos, Color cor, String pct})>[];
    for (final c in candidatos) {
      final proximo = aceitos.any((a) =>
        (a.pos.latitude - c.pos.latitude).abs() < minDist &&
        (a.pos.longitude - c.pos.longitude).abs() < minDist);
      if (!proximo) aceitos.add((pos: c.pos, cor: c.cor, pct: c.pct));
    }

    return aceitos.map((c) => Marker(
      point: c.pos,
      width: 64,
      height: 32,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.cor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          c.pct,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    )).toList();
  }

  /// Rótulos com valor (R$) por região no modo benfeitorias.
  List<Marker> _buildBenfeitoriasLabels() {
    final valores = _benfeitoriasValores;
    final ratios = _benfeitoriasRatios;
    final cores = _benfeitoriasColors;
    if (valores == null || valores.isEmpty || _regioesMT == null) return [];

    final candidatos = <({ll.LatLng pos, Color cor, String txt, double ratio})>[];
    for (final regiao in _regioesMT!) {
      final v = valores[regiao.id];
      if (v == null || v <= 0) continue;
      final ratio = ratios?[regiao.id] ?? 0.5;
      final hexCor = cores?[regiao.id] ?? '#78909C';
      final cor = _colorFromHex(hexCor);
      if (regiao.polygons.isEmpty) continue;
      final geoPoly = regiao.polygons.reduce((a, b) => a.points.length >= b.points.length ? a : b);
      final pts = geoPoly.points;
      if (pts.isEmpty) continue;
      final lat = pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
      final lng = pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length;
      candidatos.add((pos: ll.LatLng(lat, lng), cor: cor, txt: formatarMoedaCompactaPtBr(v), ratio: ratio));
    }

    candidatos.sort((a, b) => b.ratio.compareTo(a.ratio));
    const minDist = 1.4;
    final aceitos = <({ll.LatLng pos, Color cor, String txt})>[];
    for (final c in candidatos) {
      final proximo = aceitos.any((a) =>
          (a.pos.latitude - c.pos.latitude).abs() < minDist &&
          (a.pos.longitude - c.pos.longitude).abs() < minDist);
      if (!proximo) aceitos.add((pos: c.pos, cor: c.cor, txt: c.txt));
    }

    return aceitos.map((c) => Marker(
          point: c.pos,
          width: 88,
          height: 34,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: c.cor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Text(
              c.txt,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )).toList();
  }

  /// Votos TSE: círculos com degradê (centro → transparente) e cor por faixa (vermelho … verde).
  List<Marker> _buildHeatMarkers() {
    final votos = _votosParaBolhas;
    if (votos == null || votos.isEmpty) return [];

    final entries = votos.entries
        .map((e) => (nome: e.key, votos: e.value, coords: getCoordsMunicipioMT(e.key)))
        .where((e) => e.coords != null)
        .toList();
    if (entries.isEmpty) return [];

    final mm = minMaxVotos(votos);
    final minV = mm.minV;
    final maxV = mm.maxV;

    /// Intervalo completo (menor = bolha menor; maior = maior e mais “verde”).
    const sizeMin = 18.0;
    const sizeMax = 72.0;

    return entries.map((e) {
      final tVis = proporcaoVisualVotos(e.votos, minV, maxV);
      final size = sizeMin + (sizeMax - sizeMin) * tVis;
      final tier = tierParaVotos(e.votos, minV, maxV);
      final core = corHeatmapVotos(e.votos, minV, maxV);
      final center = core.withValues(alpha: 0.92);
      final mid = core.withValues(alpha: 0.44);
      final edge = core.withValues(alpha: 0.0);
      return Marker(
        point: ll.LatLng(e.coords!.latitude, e.coords!.longitude),
        width: size,
        height: size,
        child: Tooltip(
          message:
              '${displayNomeCidadeMT(e.nome)}: ${e.votos} votos (TSE) — ${tier.tituloCurto}. Toque para locais de votação.',
          child: GestureDetector(
            onTap: () => widget.onCityTap?.call(e.nome),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [center, mid, edge],
                  stops: const [0.0, 0.55, 1.0],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.95), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 4,
                    spreadRadius: 0,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Marcadores de apoiadores/votantes (camada acima dos círculos TSE).
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    final porCidade = _marcadoresParaMapa;
    if (porCidade != null && porCidade.isNotEmpty) {
      for (final e in porCidade.entries) {
        final coords = getCoordsMunicipioMT(e.key);
        if (coords != null) {
          final nome = displayNomeCidadeMT(e.key);
          final m = e.value;
          final cor = m.bandeiraCorPrimariaHex != null && m.bandeiraCorPrimariaHex!.isNotEmpty
              ? _colorFromHex(m.bandeiraCorPrimariaHex)
              : Colors.green.shade700;
          final label = m.bandeiraEmoji != null && m.bandeiraEmoji!.trim().isNotEmpty
              ? m.bandeiraEmoji!.trim()
              : (m.bandeiraIniciais != null && m.bandeiraIniciais!.trim().isNotEmpty
                  ? m.bandeiraIniciais!.trim()
                  : '${m.quantidade}');
          final Widget marcadorChild = m.bandeiraVisual != null
              ? BandeiraMarcadorWidget(
                  visual: m.bandeiraVisual!,
                  tamanho: 30,
                  fallbackIniciais: m.quantidade > 0 ? '${m.quantidade}' : '?',
                )
              : (m.bandeiraEmoji != null && m.bandeiraEmoji!.trim().isNotEmpty
                  ? Text(label, style: const TextStyle(fontSize: 22))
                  : (m.bandeiraIniciais != null && m.bandeiraIniciais!.trim().isNotEmpty
                      ? CircleAvatar(
                          radius: 14,
                          backgroundColor: cor,
                          child: Text(
                            label.length > 3 ? label.substring(0, 3) : label,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        )
                      : Icon(Icons.people, color: cor, size: 26)));
          markers.add(
            Marker(
              point: ll.LatLng(coords.latitude, coords.longitude),
              width: 32,
              height: 32,
              child: Tooltip(
                message: '$nome: ${m.quantidade} na rede (apoiadores/votantes)',
                child: GestureDetector(
                  onTap: () => widget.onCityTap?.call(e.key),
                  child: marcadorChild,
                ),
              ),
            ),
          );
        }
      }
    }
    return markers;
  }

  int _estimativaCidade(String keyMunicipio) =>
      widget.estimativaPorCidade?[normalizarNomeMunicipioMT(keyMunicipio)] ?? 0;

  /// Total TSE = soma de [votosPorMunicipio] (bate com o resultado oficial), não com a soma das regiões do mapa.
  int _totalVotosTseSomados() {
    final v = widget.votosPorMunicipio;
    if (v == null || v.isEmpty) return 0;
    return v.values.fold<int>(0, (a, b) => a + b);
  }

  /// Estimativa da campanha em todos os municípios que têm voto TSE no mapa.
  int _totalEstimativaSomada() {
    final v = widget.votosPorMunicipio;
    if (v == null || v.isEmpty) return 0;
    return v.keys.fold<int>(0, (s, k) => s + _estimativaCidade(k));
  }

  /// Agrega votos por região (região imediata) usando point-in-polygon. Ordenado por total decrescente.
  /// Inclui percentual da região sobre o total geral, estimativa por cidade e por região.
  List<({String id, String nome, int total, int totalEstimativa, double pct, List<({String cidade, String key, int votos, double pct, int estimativa})> cidades})> _rankingRegioes() {
    final votos = widget.votosPorMunicipio;
    final regioes = _regioesMT;
    if (votos == null || votos.isEmpty || regioes == null) return [];

    final totalGeral = votos.values.fold<int>(0, (a, b) => a + b);
    if (totalGeral == 0) return [];

    final porRegiao = <String, ({String nome, int total, int totalEstimativa, Map<String, int> cidades})>{};
    for (final e in votos.entries) {
      final coords = getCoordsMunicipioMT(e.key);
      if (coords == null) continue;
      final pt = LatLng(coords.latitude, coords.longitude);
      for (final reg in regioes) {
        if (pointInRegion(pt, reg.polygons)) {
          final key = reg.id;
          if (!porRegiao.containsKey(key)) {
            porRegiao[key] = (nome: reg.nome, total: 0, totalEstimativa: 0, cidades: <String, int>{});
          }
          final r = porRegiao[key]!;
          r.cidades[e.key] = (r.cidades[e.key] ?? 0) + e.value;
          final est = _estimativaCidade(e.key);
          porRegiao[key] = (nome: r.nome, total: r.total + e.value, totalEstimativa: r.totalEstimativa + est, cidades: r.cidades);
          break;
        }
      }
    }

    final list = porRegiao.entries.map((entry) {
      final id = entry.key;
      final nome = entry.value.nome;
      final total = entry.value.total;
      final totalEstimativa = entry.value.totalEstimativa;
      final pct = totalGeral > 0 ? (total / totalGeral * 100) : 0.0;
      final cidades = entry.value.cidades.entries
          .map((c) => (
                cidade: displayNomeCidadeMT(c.key),
                key: c.key,
                votos: c.value,
                pct: totalGeral > 0 ? (c.value / totalGeral * 100) : 0.0,
                estimativa: _estimativaCidade(c.key),
              ))
          .toList()
        ..sort((a, b) => b.votos.compareTo(a.votos));
      return (id: id, nome: nome, total: total, totalEstimativa: totalEstimativa, pct: pct, cidades: cidades);
    }).toList();
    list.sort((a, b) => b.total.compareTo(a.total));

    // Drill-down: só o ranking da região focada; % das cidades relativas ao total da região.
    final drillId = _regiaoDrillDownId;
    if (drillId != null) {
      final filtrada = list.where((r) => r.id == drillId).toList();
      if (filtrada.isEmpty) return [];
      final rr = filtrada.first;
      final totalReg = rr.total;
      final cidadesRel = rr.cidades
          .map(
            (c) => (
                  cidade: c.cidade,
                  key: c.key,
                  votos: c.votos,
                  pct: totalReg > 0 ? (c.votos / totalReg * 100) : 0.0,
                  estimativa: c.estimativa,
                ),
          )
          .toList();
      return [
        (
          id: rr.id,
          nome: rr.nome,
          total: rr.total,
          totalEstimativa: rr.totalEstimativa,
          pct: rr.pct,
          cidades: cidadesRel,
        ),
      ];
    }
    return list;
  }

  /// Agrega votos TSE e estimativa por região (união de municípios), para metas sem depender só do TSE.
  List<({String id, String nome, int total, int totalEstimativa, double pct, List<({String cidade, String key, int votos, double pct, int estimativa})> cidades})>
      _rankingRegioesParaMetas() {
    final regioes = _regioesMT;
    if (regioes == null) return [];

    final votos = widget.votosPorMunicipio ?? {};
    final est = widget.estimativaPorCidade ?? {};
    final keys = {...votos.keys, ...est.keys};
    if (keys.isEmpty) {
      // Lista todas as regiões com zero (para definir metas antes de haver cadastro).
      return regioes
          .map(
            (reg) => (
              id: reg.id,
              nome: reg.nome,
              total: 0,
              totalEstimativa: 0,
              pct: 0.0,
              cidades: <({String cidade, String key, int votos, double pct, int estimativa})>[],
            ),
          )
          .toList();
    }

    final totalGeralVotos = votos.values.fold<int>(0, (a, b) => a + b);
    final totalGeral = totalGeralVotos > 0 ? totalGeralVotos : 1;

    final porRegiao = <String, ({String nome, int total, int totalEstimativa, Map<String, ({int votos, int estimativa})> cidades})>{};
    for (final reg in regioes) {
      porRegiao[reg.id] = (nome: reg.nome, total: 0, totalEstimativa: 0, cidades: {});
    }
    for (final key in keys) {
      final coords = getCoordsMunicipioMT(key);
      if (coords == null) continue;
      final pt = LatLng(coords.latitude, coords.longitude);
      for (final reg in regioes) {
        if (pointInRegion(pt, reg.polygons)) {
          final v = votos[key] ?? 0;
          final e = _estimativaCidade(key);
          final cur = porRegiao[reg.id]!;
          final prev = cur.cidades[key] ?? (votos: 0, estimativa: 0);
          cur.cidades[key] = (votos: prev.votos + v, estimativa: prev.estimativa + e);
          porRegiao[reg.id] = (
            nome: cur.nome,
            total: cur.total + v,
            totalEstimativa: cur.totalEstimativa + e,
            cidades: cur.cidades,
          );
          break;
        }
      }
    }

    final list = porRegiao.entries.map((entry) {
      final id = entry.key;
      final nome = entry.value.nome;
      final total = entry.value.total;
      final totalEstimativa = entry.value.totalEstimativa;
      final pct = totalGeral > 0 ? (total / totalGeral * 100) : 0.0;
      final cidades = entry.value.cidades.entries
          .map((c) => (
                cidade: displayNomeCidadeMT(c.key),
                key: c.key,
                votos: c.value.votos,
                pct: totalGeral > 0 ? (c.value.votos / totalGeral * 100) : 0.0,
                estimativa: c.value.estimativa,
              ))
          .toList()
        ..sort((a, b) => b.votos.compareTo(a.votos));
      return (id: id, nome: nome, total: total, totalEstimativa: totalEstimativa, pct: pct, cidades: cidades);
    }).toList();
    list.sort((a, b) => b.totalEstimativa.compareTo(a.totalEstimativa));

    final drillId = _regiaoDrillDownId;
    if (drillId != null) {
      final filtrada = list.where((r) => r.id == drillId).toList();
      if (filtrada.isEmpty) return [];
      final rr = filtrada.first;
      final totalReg = rr.total;
      final cidadesRel = rr.cidades
          .map(
            (c) => (
                  cidade: c.cidade,
                  key: c.key,
                  votos: c.votos,
                  pct: totalReg > 0 ? (c.votos / totalReg * 100) : 0.0,
                  estimativa: c.estimativa,
                ),
          )
          .toList();
      return [
        (
          id: rr.id,
          nome: rr.nome,
          total: rr.total,
          totalEstimativa: rr.totalEstimativa,
          pct: rr.pct,
          cidades: cidadesRel,
        ),
      ];
    }
    return list;
  }

  /// Mapa + faixa drill-down + tooltip (sem ranking sobreposto).
  Widget _buildMapStackContent(
    BuildContext context,
    List<Polygon<String>> polygons,
    List<Marker> heatMarkers,
    List<Marker> markers,
    List<Marker> comparativoLabels,
    List<Marker> benfeitoriasLabels,
  ) {
    final drillNome = _regiaoDrillDown?.nome;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    // WebKit móvel: useAltRendering:true costuma falhar (mapa “em branco”); simplificar polígonos alivia a GPU.
    final polySimple = narrow ? 1.8 : 0.5;
    final useAltPoly = !narrow;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Sem Positioned.fill o FlutterMap pode ficar com altura 0 dentro do Stack (Safari / Chrome Android).
        Positioned.fill(
          child: MouseRegion(
            hitTestBehavior: HitTestBehavior.deferToChild,
            cursor: SystemMouseCursors.click,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: _brasilBounds,
                  padding: const EdgeInsets.all(32),
                  maxZoom: 9,
                  minZoom: 4,
                ),
                minZoom: 4,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                onTap: (_, __) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _onMapTap();
                  });
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'campanha_mt',
                ),
                PolygonLayer<String>(
                  hitNotifier: _hitNotifier,
                  polygons: polygons,
                  polygonCulling: true,
                  simplificationTolerance: polySimple,
                  useAltRendering: useAltPoly,
                ),
                if (heatMarkers.isNotEmpty) MarkerLayer(markers: heatMarkers),
                if (markers.isNotEmpty) MarkerLayer(markers: markers),
                if (comparativoLabels.isNotEmpty) MarkerLayer(markers: comparativoLabels),
                if (benfeitoriasLabels.isNotEmpty) MarkerLayer(markers: benfeitoriasLabels),
              ],
            ),
          ),
        ),
        if (_regiaoDrillDownId != null && drillNome != null)
          Positioned(
            left: 8,
            right: 8,
            top: 8,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.filter_alt, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Em destaque: ${_tituloRegiaoRanking(drillNome)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _setDrillDownRegiao(null),
                      child: const Text('Todo o estado'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_hoveredRegionName != null && _hoverPosition != null)
          Positioned(
            left: _hoverPosition!.dx + 12,
            top: _hoverPosition!.dy + 8,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  _hoveredRegionName!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _onMapTap() {
    final result = _hitNotifier.value;
    if (result == null || result.hitValues.isEmpty) return;
    final firstId = result.hitValues.first;
    if (firstId.startsWith(_kEstadoHitPrefix)) return; // Estados não são editáveis.
    final regiaoId = _regiaoIdFromHitValue(firstId);
    final regiao = _regioesMT?.where((r) => r.id == regiaoId).firstOrNull;
    if (regiao == null) return;
    if (widget.onSaveNomeRegiao == null) return; // Edição desabilitada (apenas administrador).
    final polygonIndex = firstId.contains('#')
        ? int.tryParse(firstId.split('#').last) ?? 0
        : 0;
    final partKey = '${regiao.id}#$polygonIndex';
    // No mapa só o nome oficial do GeoJSON (padronizado).
    final displayName = regiao.nome;
    // Candidato / sem edição de regiões: toque alterna drill-down nesta região.
    if (widget.onSaveNomeRegiao == null) {
      if (_regiaoDrillDownId == regiao.id) {
        _setDrillDownRegiao(null);
      } else {
        _setDrillDownRegiao(regiao.id);
      }
      return;
    }
    if (widget.onRegionTap != null) {
      final handled = widget.onRegionTap!(regiao.id, regiao.nome, regiao.cdRgint);
      if (handled) return;
    }
    _showRegionInfo(context, regiao, displayName, polygonIndex, partKey);
  }

  void _showRegionInfo(BuildContext context, RegiaoIntermediariaMT regiao, String displayName, int polygonIndex, String partKey) {
    final cdRgint = regiao.cdRgint ?? regiao.id;
    setState(() {
      _editingRegionId = regiao.id;
      _editingPolygonIndex = polygonIndex;
    });
    // Campo de edição inicia com o nome oficial; admin pode alterar (salva em nomesCustomizados para outras telas).
    final nomeController = TextEditingController(text: displayName);
    final coresOpcoes = [
      '#2196F3', '#4CAF50', '#FF9800', '#9C27B0', '#F44336', '#009688', '#FFC107', '#3F51B5', '#FF5722', '#9E9E9E',
      '#E91E63', '#00BCD4', '#8BC34A', '#795548', '#607D8B', '#673AB7', '#CDDC39', '#FF4081', '#FF6F00', '#00695C',
      '#37474F', '#7B1FA2', '#C2185B', '#1976D2', '#388E3C', '#F9A825', '#D32F2F', '#5D4037',
    ];
    String? corSelecionada = widget.coresCustomizadas?[partKey] ?? widget.coresCustomizadas?[cdRgint] ?? _coresPadrao[cdRgint];
    if (corSelecionada == null || !coresOpcoes.contains(corSelecionada)) corSelecionada = coresOpcoes.first;

    final fundidas = widget.regioesFundidas ?? [];
    final estaEmFusao = fundidas.any((f) => f.ids.contains(cdRgint) && f.ids.length > 1);
    bool aplicarSoNestaRegiao = false;

    showDialog<bool?>(
      context: _dialogContextForShell(context),
      useRootNavigator: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Editar delimitação'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome desta delimitação',
                    hintText: 'Ex.: Alto Tapajós - Norte',
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  onSubmitted: (_) => Navigator.of(ctx2).pop(true),
                ),
                if (estaEmFusao) ...[
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: aplicarSoNestaRegiao,
                    onChanged: (v) => setDialogState(() => aplicarSoNestaRegiao = v ?? false),
                    title: Text(
                      'Aplicar nome e cor só nesta região (remover da fusão)',
                      style: Theme.of(ctx2).textTheme.bodySmall,
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  Text(
                    'Esta região faz parte de uma fusão; todas mostram o mesmo nome. Marque acima para que só esta região receba o novo nome.',
                    style: Theme.of(ctx2).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx2).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Cor desta delimitação', style: Theme.of(ctx2).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: coresOpcoes.map((hex) {
                    final cor = _colorFromHex(hex);
                    final selected = corSelecionada == hex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => corSelecionada = hex),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: cor,
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: selected ? 4 : 1)],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx2).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx2).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    ).then((saved) {
      if (mounted) {
        setState(() {
          _editingRegionId = null;
          _editingPolygonIndex = null;
        });
      }
      if (saved == true) {
        if (aplicarSoNestaRegiao && widget.onRemoverDaFusao != null) {
          widget.onRemoverDaFusao!(cdRgint);
        }
        final nome = nomeController.text.trim();
        if (nome.isNotEmpty && widget.onSaveNomeRegiao != null) {
          widget.onSaveNomeRegiao!(partKey, nome);
        }
        if (widget.onSaveCorRegiao != null && corSelecionada != null) {
          widget.onSaveCorRegiao!(partKey, corSelecionada!);
        }
      }
    });
  }

  /// Painel de ranking: com [painelRankingModoNotifier] usa [ValueListenableBuilder] para o modo
  /// ficar sempre alinhado ao toque (evita lista «nenhum» com rodapé em Metas).
  Widget _rankingPanelWidget({
    required bool compact,
    required List<({String id, String nome, int total, int totalEstimativa, double pct, List<({String cidade, String key, int votos, double pct, int estimativa})> cidades})> ranking,
    required List<({String id, String nome, int total, int totalEstimativa, double pct, List<({String cidade, String key, int votos, double pct, int estimativa})> cidades})> rankingMetas,
    required Map<String, int> metasMap,
    required int totalVotosTseGeral,
    required int totalEstimativaGeral,
  }) {
    Widget buildPanel(String modo) {
      return _RankingPanel(
        ranking: ranking,
        rankingMetas: rankingMetas,
        metasPorRegiao: metasMap,
        painelRankingModo: modo,
        onSalvarMetas: widget.onSalvarMetas,
        totalVotosTseGeral: totalVotosTseGeral,
        totalEstimativaGeral: totalEstimativaGeral,
        benfeitoriasRanking: widget.benfeitoriasRanking,
        onCityTap: widget.onCityTap,
        locaisVotacaoContent: widget.locaisVotacaoContent,
        selectedMunicipioKey: widget.selectedMunicipioKey,
        layoutCompact: compact,
        focusedRegiaoId: _regiaoDrillDownId,
        onMostrarTSE: widget.onMostrarTSE,
        onMostrarMarcadores: widget.onMostrarMarcadores,
        mostrarTSE: widget.mostrarTSE,
        mostrarMarcadores: widget.mostrarMarcadores,
        onComparativoColors: _onComparativoCoresFromPanel,
        onBenfeitoriasMapa: _onBenfeitoriasFromPanel,
        onPainelRankingModoChanged: widget.onPainelRankingModoChanged,
        onToggleFocusRegiao: (id) {
          final modoNv = widget.painelRankingModoNotifier?.value ?? widget.painelRankingModo;
          if (_normalizePainelModoStr(modoNv) == 'metas') {
            return;
          }
          if (_regiaoDrillDownId == id) {
            _setDrillDownRegiao(null);
          } else {
            _setDrillDownRegiao(id);
          }
        },
        nomesCustomizados: widget.nomesCustomizados,
      );
    }

    final nv = widget.painelRankingModoNotifier;
    if (nv != null) {
      return ValueListenableBuilder<String>(
        valueListenable: nv,
        builder: (context, modo, _) => buildPanel(modo),
      );
    }
    return buildPanel(widget.painelRankingModo);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text('Erro ao carregar o mapa', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(_error!, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    final polygons = _buildPolygons();
    final heatMarkers = _buildHeatMarkers();
    final markers = _buildMarkers();
    final comparativoLabels = _buildComparativoLabels();
    final benfeitoriasLabels = _buildBenfeitoriasLabels();
    final ranking = _rankingRegioes();
    final rankingMetas = _rankingRegioesParaMetas();
    final totalVotosTseGeral = _totalVotosTseSomados();
    final totalEstimativaGeral = _totalEstimativaSomada();
    final metasMap = widget.metasPorRegiao ?? const <String, int>{};

    // Dashboard/mobile embutido: mapa e ranking em coluna — o mapa deixa de ser tapado pelo painel.
    if (widget.embedRankingBelowMap) {
      if (ranking.isEmpty && rankingMetas.isEmpty) {
        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: _buildMapStackContent(context, polygons, heatMarkers, markers, comparativoLabels, benfeitoriasLabels),
        );
      }
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mapa um pouco menor — mais espaço para ranking + locais de votação (lista scrollável).
            Expanded(
              flex: 8,
              child: _buildMapStackContent(context, polygons, heatMarkers, markers, comparativoLabels, benfeitoriasLabels),
            ),
            Expanded(
              flex: 16,
              child: _rankingPanelWidget(
                compact: true,
                ranking: ranking,
                rankingMetas: rankingMetas,
                metasMap: metasMap,
                totalVotosTseGeral: totalVotosTseGeral,
                totalEstimativaGeral: totalEstimativaGeral,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 560;
          // Painel inferior: com «Locais de votação» abertos precisa de mais altura para a lista scrollável.
          final temLocais = widget.locaisVotacaoContent != null;
          final bottomPanelH = math.max(
            temLocais ? 280.0 : 168.0,
            math.min(
              temLocais ? 520.0 : 300.0,
              constraints.maxHeight * (temLocais ? 0.58 : 0.36),
            ),
          );
          Widget buildRankingPanel({required bool compact}) => _rankingPanelWidget(
            compact: compact,
            ranking: ranking,
            rankingMetas: rankingMetas,
            metasMap: metasMap,
            totalVotosTseGeral: totalVotosTseGeral,
            totalEstimativaGeral: totalEstimativaGeral,
          );

          // Botão flutuante para mostrar/ocultar o ranking
          Widget buildToggleBtn() => Positioned(
            right: 8,
            top: 8,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(24),
              color: Theme.of(context).colorScheme.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  setState(() => _rankingVisivel = !_rankingVisivel);
                  // Ao abrir, ativa a camada correta conforme o tab padrão (TSE)
                  // O _RankingPanel cuida de acionar onMostrarTSE quando o usuário clica nos tabs
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _rankingVisivel ? Icons.leaderboard : Icons.leaderboard_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _rankingVisivel ? 'Ocultar ranking' : 'Ver ranking',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: _buildMapStackContent(context, polygons, heatMarkers, markers, comparativoLabels, benfeitoriasLabels),
              ),
              // Botão toggle sempre visível (independente de haver dados)
              buildToggleBtn(),
              // Painel ranking — visível conforme toggle
              if (_rankingVisivel)
                narrow
                    ? Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        height: bottomPanelH,
                        child: Material(
                          elevation: 12,
                          shadowColor: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: buildRankingPanel(compact: true),
                        ),
                      )
                    : Positioned(
                        right: 8,
                        top: 44,
                        bottom: 8,
                        child: Material(
                          elevation: 12,
                          shadowColor: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: buildRankingPanel(compact: false),
                        ),
                      ),
            ],
          );
        },
      ),
    );
  }
}

/// Painel lateral analítico — redesenhado com barras, medalhas e filtragem por clique.
class _RankingPanel extends StatefulWidget {
  const _RankingPanel({
    required this.ranking,
    required this.rankingMetas,
    required this.metasPorRegiao,
    required this.painelRankingModo,
    this.onSalvarMetas,
    required this.totalVotosTseGeral,
    required this.totalEstimativaGeral,
    this.benfeitoriasRanking,
    this.onCityTap,
    this.locaisVotacaoContent,
    this.selectedMunicipioKey,
    this.layoutCompact = false,
    this.focusedRegiaoId,
    required this.onToggleFocusRegiao,
    this.onMostrarTSE,
    this.onMostrarMarcadores,
    this.mostrarTSE = false,
    this.mostrarMarcadores = false,
    this.onComparativoColors,
    this.onBenfeitoriasMapa,
    this.onPainelRankingModoChanged,
    this.nomesCustomizados,
  });

  final List<({String id, String nome, int total, int totalEstimativa, double pct, List<({String cidade, String key, int votos, double pct, int estimativa})> cidades})> ranking;
  final List<({String id, String nome, int total, int totalEstimativa, double pct, List<({String cidade, String key, int votos, double pct, int estimativa})> cidades})> rankingMetas;
  final Map<String, int> metasPorRegiao;
  /// Sincronizado com [MapaRegionalPanel] — evita dessincronizar após rebuild do pai.
  final String painelRankingModo;
  final Future<void> Function(Map<String, int> metas)? onSalvarMetas;
  final int totalVotosTseGeral;
  final int totalEstimativaGeral;
  final List<BenfeitoriaRegiaoRanking>? benfeitoriasRanking;
  final void Function(String nomeMunicipio)? onCityTap;
  final Widget? locaisVotacaoContent;
  final String? selectedMunicipioKey;
  final bool layoutCompact;
  final String? focusedRegiaoId;
  final void Function(String regiaoId) onToggleFocusRegiao;
  final void Function(bool)? onMostrarTSE;
  final void Function(bool)? onMostrarMarcadores;
  final bool mostrarTSE;
  final bool mostrarMarcadores;
  /// Cores no mapa (Comparativo ou Metas). [ratios] opcional: se null, o mapa assume TSE vs estimativa.
  final void Function(
    Map<String, String>? cores, {
    Map<String, double>? ratios,
    bool incluirLabelsZero,
  })? onComparativoColors;
  final void Function(BenfeitoriasMapaPayload? payload)? onBenfeitoriasMapa;
  final ValueChanged<String>? onPainelRankingModoChanged;
  final Map<String, String>? nomesCustomizados;

  @override
  State<_RankingPanel> createState() => _RankingPanelState();
}

enum _ModoRanking { nenhum, tse, rede, comparativo, metas, benfeitorias }

/// Normaliza o modo vindo do [MapaRegionalPanel] (trim, minúsculas).
String _normalizePainelModoStr(String s) {
  final t = s.trim().toLowerCase();
  if (t.isEmpty) return 'nenhum';
  return t;
}

_ModoRanking _parsePainelModo(String s) {
  switch (_normalizePainelModoStr(s)) {
    case 'tse':
      return _ModoRanking.tse;
    case 'rede':
      return _ModoRanking.rede;
    case 'comparativo':
      return _ModoRanking.comparativo;
    case 'metas':
      return _ModoRanking.metas;
    case 'benfeitorias':
      return _ModoRanking.benfeitorias;
    default:
      return _ModoRanking.nenhum;
  }
}

// Cores de atingimento: ratio = estimativa / votos_tse
String _corAtingimento(double ratio) {
  if (ratio <= 0) return '#78909C';      // sem dados
  if (ratio < 0.10) return '#B71C1C';   // < 10% — crítico
  if (ratio < 0.25) return '#D32F2F';   // 10-25% — muito abaixo
  if (ratio < 0.40) return '#E64A19';   // 25-40% — abaixo
  if (ratio < 0.60) return '#F57C00';   // 40-60% — na metade
  if (ratio < 0.80) return '#F9A825';   // 60-80% — bom progresso
  if (ratio < 1.00) return '#558B2F';   // 80-99% — quase lá
  if (ratio < 1.50) return '#2E7D32';   // 100-150% — superado!
  return '#FFD700';                      // > 150% — excelência
}

String _labelAtingimento(double ratio) {
  if (ratio <= 0) return 'Sem dados';
  final pct = (ratio * 100).toStringAsFixed(1);
  if (ratio < 0.50) return '$pct% — abaixo da meta';
  if (ratio < 0.80) return '$pct% — em progresso';
  if (ratio < 1.00) return '$pct% — quase lá';
  if (ratio < 1.50) return '$pct% — meta atingida!';
  return '$pct% — superação! 🏆';
}

class _RankingPanelState extends State<_RankingPanel> {
  String _ultimaAssinaturaBenfeitoriasMapa = '';

  void _emitPainelModoStr(String s) {
    widget.onPainelRankingModoChanged?.call(_normalizePainelModoStr(s));
  }

  String _assinaturaBenfeitorias(List<BenfeitoriaRegiaoRanking> list) {
    if (list.isEmpty) return '';
    return list.map((r) => '${r.id}:${r.valorTotal.toStringAsFixed(2)}').join('|');
  }

  @override
  void didUpdateWidget(_RankingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final modoPai = _normalizePainelModoStr(widget.painelRankingModo);
    if (_parsePainelModo(modoPai) != _ModoRanking.benfeitorias) return;
    final list = widget.benfeitoriasRanking ?? [];
    if (list.isEmpty) {
      _ultimaAssinaturaBenfeitoriasMapa = '';
      return;
    }
    final sig = _assinaturaBenfeitorias(list);
    if (sig == _ultimaAssinaturaBenfeitoriasMapa) return;
    final oldList = oldWidget.benfeitoriasRanking ?? [];
    if (oldList.isNotEmpty && list.length == oldList.length) {
      var same = true;
      for (var i = 0; i < list.length; i++) {
        if (list[i].id != oldList[i].id || list[i].valorTotal != oldList[i].valorTotal) {
          same = false;
          break;
        }
      }
      if (same) return;
    }
    _ultimaAssinaturaBenfeitoriasMapa = sig;
    _aplicarCamadaBenfeitoriasNoMapa(list);
  }

  void _aplicarCamadaBenfeitoriasNoMapa(List<BenfeitoriaRegiaoRanking> list) {
    _ultimaAssinaturaBenfeitoriasMapa = _assinaturaBenfeitorias(list);
    widget.onComparativoColors?.call(null);
    widget.onMostrarTSE?.call(false);
    widget.onMostrarMarcadores?.call(false);
    var maxV = 0.0;
    for (final r in list) {
      if (r.valorTotal > maxV) maxV = r.valorTotal;
    }
    final cores = <String, String>{};
    final ratios = <String, double>{};
    final valores = <String, double>{};
    for (final r in list) {
      if (r.valorTotal <= 0) continue;
      valores[r.id] = r.valorTotal;
      final t = maxV > 0 ? r.valorTotal / maxV : 0.0;
      ratios[r.id] = t;
      cores[r.id] = _corAtingimento(t);
    }
    widget.onBenfeitoriasMapa?.call(
      cores.isEmpty ? null : BenfeitoriasMapaPayload(cores: cores, ratios: ratios, valores: valores),
    );
  }

  /// Metas só no painel: remove camadas coloridas (comparativo/benfeitorias), sem alterar TSE/rede.
  void _limparCoresAnaliticasNoMapa() {
    widget.onComparativoColors?.call(null);
    widget.onBenfeitoriasMapa?.call(null);
  }

  static const _medals = ['🥇', '🥈', '🥉'];

  // Cor da barra de progresso por posição (gradiente de intensidade)
  static Color _barColor(int rank, ColorScheme cs) {
    if (rank == 0) return const Color(0xFFFFB300); // ouro
    if (rank == 1) return const Color(0xFF78909C); // prata
    if (rank == 2) return const Color(0xFF8D6E63); // bronze
    return cs.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final showLocais = widget.locaisVotacaoContent != null;
    final screenW = MediaQuery.sizeOf(context).width;
    final panelWidth = widget.layoutCompact
        ? double.infinity
        : math.min(400.0, math.max(220.0, screenW * 0.42));

    final ranking = widget.ranking;
    final totalVotosTseGeral = widget.totalVotosTseGeral;
    final totalEstimativaGeral = widget.totalEstimativaGeral;
    final focusedRegiaoId = widget.focusedRegiaoId;
    final modo = _parsePainelModo(_normalizePainelModoStr(widget.painelRankingModo));

    // ── Ranking da rede: agrega estimativa por região (flat lista de cidades) ──
    // Ranking da rede: agrega estimativa por região
    final rankingRede = <({String id, String nome, int estimativaTotal, List<({String cidade, String key, int estimativa})> cidades})>[];
    if (totalEstimativaGeral > 0) {
      for (final r in ranking.where((r) => r.totalEstimativa > 0)) {
        final cidades = r.cidades
            .where((c) => c.estimativa > 0)
            .map((c) => (cidade: c.cidade, key: c.key, estimativa: c.estimativa))
            .toList()
          ..sort((a, b) => b.estimativa.compareTo(a.estimativa));
        rankingRede.add((id: r.id, nome: r.nome, estimativaTotal: r.totalEstimativa, cidades: cidades));
      }
      rankingRede.sort((a, b) => b.estimativaTotal.compareTo(a.estimativaTotal));
    }

    // Abas TSE / Rede / Comparativo: não exigir estimativa > 0 (campanhas só com benfeitorias ou TSE também usam o mapa).
    final mostrarAbasTseRedeComparativo =
        widget.onMostrarTSE != null && widget.onMostrarMarcadores != null;
    // O separador aparece sempre que o mapa suporta a camada (callback interno).
    // O ranking pode vir null (loading/erro do provider) — a lista trata vazio/loading.
    final temBenfeitorias = widget.onBenfeitoriasMapa != null;
    final temModoMetas = widget.onSalvarMetas != null;
    final modoRede = modo == _ModoRanking.rede;
    final modoComparativo = modo == _ModoRanking.comparativo;
    final modoMetas = modo == _ModoRanking.metas;
    final modoBenfeitorias = modo == _ModoRanking.benfeitorias;
    final modoNenhum = modo == _ModoRanking.nenhum;
    final totalValorBenf = widget.benfeitoriasRanking?.fold<double>(0, (s, r) => s + r.valorTotal) ?? 0.0;
    var totalMetaSoma = 0;
    var totalAtingidoSoma = 0;
    for (final r in widget.rankingMetas) {
      final m = widget.metasPorRegiao[r.id] ?? 0;
      if (m <= 0) continue;
      totalMetaSoma += m;
      totalAtingidoSoma += r.totalEstimativa;
    }

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: panelWidth,
          color: theme.colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Cabeçalho ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.35),
                  border: Border(bottom: BorderSide(color: cs.outlineVariant, width: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.leaderboard_outlined, size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Ranking por Região',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (focusedRegiaoId != null) ...[
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => widget.onToggleFocusRegiao(focusedRegiaoId),
                            icon: const Icon(Icons.zoom_out_map, size: 14),
                            label: const Text('Ver tudo', style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ── Tabs: clique ativa; clique duplo limpa o mapa ──
                    if (mostrarAbasTseRedeComparativo || temBenfeitorias || temModoMetas) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (mostrarAbasTseRedeComparativo) ...[
                            _TabBtn(
                              label: 'Eleição 2022',
                              icon: Icons.how_to_vote_outlined,
                              active: modo == _ModoRanking.tse,
                              color: const Color(0xFF1565C0),
                              onTap: () {
                                if (modo == _ModoRanking.tse) {
                                  _emitPainelModoStr('nenhum');
                                  widget.onMostrarTSE?.call(false);
                                  widget.onMostrarMarcadores?.call(false);
                                  widget.onComparativoColors?.call(null);
                                  widget.onBenfeitoriasMapa?.call(null);
                                } else {
                                  _emitPainelModoStr('tse');
                                  widget.onMostrarTSE?.call(true);
                                  widget.onMostrarMarcadores?.call(false);
                                  widget.onComparativoColors?.call(null);
                                  widget.onBenfeitoriasMapa?.call(null);
                                }
                              },
                            ),
                            _TabBtn(
                              label: 'Minha Rede',
                              icon: Icons.groups_outlined,
                              active: modo == _ModoRanking.rede,
                              color: cs.secondary,
                              onTap: () {
                                if (modo == _ModoRanking.rede) {
                                  _emitPainelModoStr('nenhum');
                                  widget.onMostrarTSE?.call(false);
                                  widget.onMostrarMarcadores?.call(false);
                                  widget.onComparativoColors?.call(null);
                                  widget.onBenfeitoriasMapa?.call(null);
                                } else {
                                  _emitPainelModoStr('rede');
                                  widget.onMostrarTSE?.call(false);
                                  widget.onMostrarMarcadores?.call(true);
                                  widget.onComparativoColors?.call(null);
                                  widget.onBenfeitoriasMapa?.call(null);
                                }
                              },
                            ),
                            _TabBtn(
                              label: 'Comparativo',
                              icon: Icons.compare_arrows,
                              active: modo == _ModoRanking.comparativo,
                              color: Colors.teal,
                              onTap: () {
                                if (modo == _ModoRanking.comparativo) {
                                  _emitPainelModoStr('nenhum');
                                  widget.onMostrarTSE?.call(false);
                                  widget.onMostrarMarcadores?.call(false);
                                  widget.onComparativoColors?.call(null);
                                  widget.onBenfeitoriasMapa?.call(null);
                                } else {
                                  final cores = <String, String>{};
                                  for (final r in ranking) {
                                    if (r.total > 0) {
                                      final ratio = r.totalEstimativa / r.total;
                                      cores[r.id] = _corAtingimento(ratio);
                                    }
                                  }
                                  _emitPainelModoStr('comparativo');
                                  widget.onMostrarTSE?.call(false);
                                  widget.onMostrarMarcadores?.call(false);
                                  widget.onBenfeitoriasMapa?.call(null);
                                  widget.onComparativoColors?.call(cores.isEmpty ? null : cores);
                                }
                              },
                            ),
                          ],
                          if (temModoMetas)
                            _TabBtn(
                              label: 'Metas',
                              icon: Icons.flag_outlined,
                              active: modoMetas,
                              color: const Color(0xFF7E57C2),
                              onTap: () {
                                if (modo == _ModoRanking.metas) {
                                  _emitPainelModoStr('nenhum');
                                } else {
                                  _emitPainelModoStr('metas');
                                }
                                _limparCoresAnaliticasNoMapa();
                              },
                            ),
                          if (temBenfeitorias)
                            _TabBtn(
                              label: 'Benfeitorias',
                              icon: Icons.volunteer_activism_outlined,
                              active: modoBenfeitorias,
                              color: kBenfeitoriasMapaAccent,
                              onTap: () {
                                final list = widget.benfeitoriasRanking ?? [];
                                if (modo == _ModoRanking.benfeitorias) {
                                  _emitPainelModoStr('nenhum');
                                  widget.onMostrarTSE?.call(false);
                                  widget.onMostrarMarcadores?.call(false);
                                  widget.onComparativoColors?.call(null);
                                  widget.onBenfeitoriasMapa?.call(null);
                                } else {
                                  _emitPainelModoStr('benfeitorias');
                                  _aplicarCamadaBenfeitoriasNoMapa(list);
                                }
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // KPIs: mostra apenas o que é relevante para o tab ativo
                    if (modoBenfeitorias)
                      Row(
                        children: [
                          Expanded(
                            child: _KpiChip(
                              icon: Icons.volunteer_activism_outlined,
                              label: 'Benfeitorias (soma)',
                              value: formatarMoedaPtBr(totalValorBenf),
                              color: kBenfeitoriasMapaAccent,
                              theme: theme,
                              readableTextOnDark: true,
                            ),
                          ),
                        ],
                      )
                    else if (modoMetas)
                      Row(
                        children: [
                          Expanded(
                            child: _KpiChip(
                              icon: Icons.flag_outlined,
                              label: 'Meta total',
                              value: formatarInteiroPtBr(totalMetaSoma),
                              color: const Color(0xFF7E57C2),
                              theme: theme,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _KpiChip(
                              icon: Icons.trending_up,
                              label: 'Atingido (est.)',
                              value: formatarInteiroPtBr(totalAtingidoSoma),
                              color: cs.secondary,
                              theme: theme,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          if (modo == _ModoRanking.tse || modo == _ModoRanking.comparativo)
                            Expanded(child: _KpiChip(
                              icon: Icons.how_to_vote_outlined,
                              label: 'TSE 2022',
                              value: formatarInteiroPtBr(totalVotosTseGeral),
                              color: const Color(0xFF1565C0),
                              theme: theme,
                            )),
                          if ((modo == _ModoRanking.tse || modo == _ModoRanking.comparativo) && totalEstimativaGeral > 0)
                            const SizedBox(width: 8),
                          if ((modo == _ModoRanking.rede || modo == _ModoRanking.comparativo) && totalEstimativaGeral > 0)
                            Expanded(child: _KpiChip(
                              icon: Icons.groups_outlined,
                              label: 'Campanha',
                              value: formatarInteiroPtBr(totalEstimativaGeral),
                              color: cs.secondary,
                              theme: theme,
                            )),
                        ],
                      ),
                    if (widget.onCityTap != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          modoBenfeitorias
                              ? 'Toque na região para filtrar o mapa • Valores por município cadastrado nas benfeitorias'
                              : modoMetas
                                  ? 'Toque na região para filtrar o mapa • Cores = estimativa da campanha ÷ meta por região'
                              : (modoRede || modoNenhum)
                                  ? 'Toque na região para filtrar o mapa'
                                  : 'Toque na região para filtrar o mapa • Toque na cidade para ver urnas',
                          style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Lista: nenhum / TSE / Rede / Comparativo / Metas / Benfeitorias ───────
              Expanded(
                flex: showLocais ? 2 : 1,
                child: modoNenhum
                    ? _buildListaNenhum(cs, theme)
                    : modoBenfeitorias
                    ? _buildListaBenfeitorias(widget.benfeitoriasRanking ?? const [], cs, theme)
                    : modoMetas
                    ? _buildListaMetas(cs, theme)
                    : modoComparativo
                    ? _buildListaComparativo(ranking, totalVotosTseGeral, totalEstimativaGeral, cs, theme)
                    : modoRede
                    ? _buildListaRede(rankingRede, totalEstimativaGeral, cs, theme)
                    : ListView.builder(
                  itemCount: ranking.length,
                  itemBuilder: (context, i) {
                    final r = ranking[i];
                    final isFocused = focusedRegiaoId == r.id;
                    final containsSelected = widget.selectedMunicipioKey != null &&
                        r.cidades.any((c) => c.key == widget.selectedMunicipioKey);
                    final barColor = _barColor(i, cs);
                    final medalLabel = i < 3 ? _medals[i] : '${i + 1}º';

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: isFocused
                            ? Border.all(color: cs.primary, width: 2)
                            : containsSelected
                                ? Border.all(color: cs.secondary, width: 1)
                                : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
                        color: isFocused
                            ? cs.primaryContainer.withValues(alpha: 0.32)
                            : containsSelected
                                ? cs.secondaryContainer.withValues(alpha: 0.15)
                                : null,
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: containsSelected || isFocused,
                        shape: const RoundedRectangleBorder(),
                        collapsedShape: const RoundedRectangleBorder(),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        title: InkWell(
                          onTap: () => widget.onToggleFocusRegiao(r.id),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Medal / rank
                                    Text(
                                      medalLabel,
                                      style: TextStyle(
                                        fontSize: i < 3 ? 18 : 13,
                                        fontWeight: FontWeight.bold,
                                        color: i >= 3 ? cs.onSurfaceVariant : null,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _tituloRegiaoRanking(r.nome),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // % badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: barColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${r.pct.toStringAsFixed(1)}%',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: barColor,
                                        ),
                                      ),
                                    ),
                                    if (isFocused)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Icon(Icons.map, size: 16, color: cs.primary),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                // Barra de progresso TSE
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: r.pct / 100,
                                    minHeight: 5,
                                    backgroundColor: barColor.withValues(alpha: 0.12),
                                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // Números TSE + estimativa (sem Spacer — usa Wrap para não transbordar)
                                Wrap(
                                  spacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.how_to_vote_outlined, size: 12, color: cs.onSurfaceVariant),
                                        const SizedBox(width: 3),
                                        Text(
                                          formatarInteiroPtBr(r.total),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          ' TSE',
                                          style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                    if (r.totalEstimativa > 0)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.groups_outlined, size: 12, color: cs.secondary),
                                          const SizedBox(width: 2),
                                          Text(
                                            formatarInteiroPtBr(r.totalEstimativa),
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: cs.secondary,
                                            ),
                                          ),
                                          Text(
                                            ' camp.',
                                            style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    // Botão filtrar — no Wrap não estoura
                                    GestureDetector(
                                      onTap: () => widget.onToggleFocusRegiao(r.id),
                                      child: Text(
                                        isFocused ? '✕ Ver tudo' : '🗺 Filtrar',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        children: [
                          const Divider(height: 1),
                          // Cabeçalho cidades — sem colunas fixas
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
                            child: Row(
                              children: [
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Text(
                                    'Cidade',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Text(
                                  'TSE   %',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...r.cidades.map((c) {
                            final isSelected = c.key == widget.selectedMunicipioKey;
                            return InkWell(
                              onTap: () => widget.onCityTap?.call(c.key),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                decoration: isSelected
                                    ? BoxDecoration(
                                        color: cs.primaryContainer.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: cs.primary, width: 1),
                                      )
                                    : null,
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected ? Icons.place : Icons.circle,
                                      size: isSelected ? 14 : 6,
                                      color: isSelected ? cs.primary : barColor.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 6),
                                    // Nome da cidade — ocupa o espaço disponível
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c.cidade,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              fontWeight: isSelected ? FontWeight.bold : null,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (c.estimativa > 0)
                                            Text(
                                              '${formatarInteiroPtBr(c.estimativa)} camp.',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: cs.secondary,
                                                fontSize: 9,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Votos + % em texto compacto sem SizedBox fixo
                                    Text(
                                      '${formatarInteiroPtBr(c.votos)}  ${c.pct.toStringAsFixed(1)}%',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontWeight: isSelected ? FontWeight.w600 : null,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 4),
                        ],
                      ),
                    );
                  },
                ),
              ),

              if (showLocais) ...[
                const Divider(height: 1),
                // Mais altura para a lista de locais (scroll) sem esmagar o ranking (proporção 2 : 3).
                Expanded(flex: 3, child: widget.locaisVotacaoContent!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _nomeRegiaoExibicao(String id, String nome) {
    final c = widget.nomesCustomizados;
    if (c != null) {
      final n = c[id];
      if (n != null && n.trim().isNotEmpty) return n.trim();
    }
    return nome;
  }

  /// Salva [metas] completas no servidor.
  Future<void> _abrirDialogMetas(BuildContext context) async {
    final ranking = widget.rankingMetas;
    final salvar = widget.onSalvarMetas;
    if (salvar == null) return;
    final controllers = <String, TextEditingController>{};
    for (final r in ranking) {
      final v = widget.metasPorRegiao[r.id] ?? 0;
      controllers[r.id] = TextEditingController(text: v > 0 ? '$v' : '');
    }
    try {
      final ok = await showDialog<bool>(
        context: _dialogContextForShell(context),
        useRootNavigator: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Todas as metas por região'),
          content: SizedBox(
            width: 420,
            height: math.min(440, MediaQuery.sizeOf(ctx).height * 0.55),
            child: ListView(
              children: [
                for (final r in ranking)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[r.id],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: _nomeRegiaoExibicao(r.id, r.nome),
                        border: const OutlineInputBorder(),
                        helperText: 'Estimativa atual: ${formatarInteiroPtBr(r.totalEstimativa)}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
          ],
        ),
      );
      if (ok == true) {
        final out = <String, int>{};
        for (final r in ranking) {
          final raw = controllers[r.id]?.text.trim() ?? '';
          final digits = raw.replaceAll(RegExp(r'\D'), '');
          if (digits.isEmpty) continue;
          final n = int.tryParse(digits);
          if (n != null && n > 0) out[r.id] = n;
        }
        await salvar(out);
      }
    } finally {
      for (final c in controllers.values) {
        c.dispose();
      }
    }
  }

  Future<void> _abrirDialogMetaUmaRegiao(BuildContext context, {required String regiaoId}) async {
    final salvar = widget.onSalvarMetas;
    if (salvar == null) return;
    final r = widget.rankingMetas.where((e) => e.id == regiaoId).firstOrNull;
    if (r == null) return;
    final atual = widget.metasPorRegiao[regiaoId] ?? 0;
    final controller = TextEditingController(text: atual > 0 ? '$atual' : '');
    try {
      await showDialog<void>(
        context: _dialogContextForShell(context),
        useRootNavigator: false,
        builder: (ctx) => AlertDialog(
          title: Text(_tituloRegiaoRanking(_nomeRegiaoExibicao(r.id, r.nome))),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Meta de votos',
              border: const OutlineInputBorder(),
              helperText: 'Estimativa atual da campanha: ${formatarInteiroPtBr(r.totalEstimativa)}',
            ),
          ),
          actions: [
            if (atual > 0)
              TextButton(
                onPressed: () async {
                  final merged = Map<String, int>.from(widget.metasPorRegiao);
                  merged.remove(regiaoId);
                  Navigator.pop(ctx);
                  await salvar(merged);
                },
                child: const Text('Remover meta'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final raw = controller.text.trim();
                final digits = raw.replaceAll(RegExp(r'\D'), '');
                final merged = Map<String, int>.from(widget.metasPorRegiao);
                if (digits.isEmpty) {
                  merged.remove(regiaoId);
                  Navigator.pop(ctx);
                  await salvar(merged);
                  return;
                }
                final n = int.tryParse(digits);
                if (n == null || n <= 0) return;
                merged[regiaoId] = n;
                Navigator.pop(ctx);
                await salvar(merged);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _buildListaMetas(
    ColorScheme cs,
    ThemeData theme,
  ) {
    final ranking = widget.rankingMetas;
    final metas = widget.metasPorRegiao;
    if (ranking.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Carregando regiões…',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: OutlinedButton.icon(
            onPressed: widget.onSalvarMetas == null ? null : () => _abrirDialogMetas(context),
            icon: const Icon(Icons.table_rows_outlined, size: 18),
            label: const Text('Editar todas as metas'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
          child: Text(
            'Em cada região use «Adicionar meta» ou «Editar meta». Valores da estimativa vêm da rede cadastrada.',
            style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: ranking.length,
            itemBuilder: (context, i) {
              final r = ranking[i];
              final m = metas[r.id] ?? 0;
              final ratio = m > 0 ? r.totalEstimativa / m : 0.0;
              final isFocused = widget.focusedRegiaoId == r.id;
              final medalLabel = i < 3 ? _medals[i] : '${i + 1}º';
              final corBarra = cs.primary;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isFocused ? cs.primary : cs.outlineVariant.withValues(alpha: 0.7),
                    width: isFocused ? 2 : 1,
                  ),
                  color: isFocused ? cs.primaryContainer.withValues(alpha: 0.22) : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(medalLabel, style: TextStyle(fontSize: i < 3 ? 18 : 13, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _tituloRegiaoRanking(_nomeRegiaoExibicao(r.id, r.nome)),
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (m > 0)
                            Text(
                              '${(ratio * 100).toStringAsFixed(1)}%',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (m > 0)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (ratio).clamp(0.0, 1.5) / 1.5,
                            minHeight: 6,
                            backgroundColor: cs.outlineVariant.withValues(alpha: 0.35),
                            valueColor: AlwaysStoppedAnimation<Color>(corBarra),
                          ),
                        )
                      else
                        const SizedBox(height: 6),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flag_outlined, size: 12, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                m > 0 ? '${formatarInteiroPtBr(m)} meta' : 'Sem meta',
                                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.groups_outlined, size: 12, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(
                                '${formatarInteiroPtBr(r.totalEstimativa)} est.',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: widget.onSalvarMetas == null
                                ? null
                                : () => _abrirDialogMetaUmaRegiao(context, regiaoId: r.id),
                            icon: Icon(m > 0 ? Icons.edit_outlined : Icons.add_circle_outline, size: 18),
                            label: Text(m > 0 ? 'Editar meta' : 'Adicionar meta'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
            },
          ),
        ),
      ],
    );
  }

  // ── Estado vazio: nenhuma camada selecionada ──────────────────────────────

  Widget _buildListaNenhum(ColorScheme cs, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, size: 40, color: cs.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'Selecione uma visualização',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Toque em "Eleição 2022", "Minha Rede", "Comparativo", "Metas" ou "Benfeitorias" (quando disponível) para carregar os dados no mapa.',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Lista benfeitorias (valor por região e cidade) ────────────────────────

  Widget _buildListaBenfeitorias(
    List<BenfeitoriaRegiaoRanking> rankingBenf,
    ColorScheme cs,
    ThemeData theme,
  ) {
    if (rankingBenf.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volunteer_activism_outlined, size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.45)),
              const SizedBox(height: 12),
              Text(
                'Nenhum dado no mapa por município',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'O mapa usa o município da benfeitoria ou, se estiver vazio, o município do apoiador. Confira se o apoiador tem cidade (MT) e, nas benfeitorias, o município quando for diferente.',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    var maxV = 0.0;
    for (final r in rankingBenf) {
      if (r.valorTotal > maxV) maxV = r.valorTotal;
    }

    return ListView.builder(
      itemCount: rankingBenf.length,
      itemBuilder: (context, i) {
        final r = rankingBenf[i];
        final isFocused = widget.focusedRegiaoId == r.id;
        final pct = maxV > 0 ? r.valorTotal / maxV * 100 : 0.0;
        final medalLabel = i < 3 ? _medals[i] : '${i + 1}º';
        final t = maxV > 0 ? r.valorTotal / maxV : 0.0;
        final hexCor = _corAtingimento(t);
        final barCor = Color(int.parse(hexCor.replaceFirst('#', 'FF'), radix: 16));

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isFocused
                ? Border.all(color: kBenfeitoriasMapaAccent, width: 2)
                : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
            color: isFocused ? kBenfeitoriasMapaAccent.withValues(alpha: 0.12) : null,
          ),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(),
            collapsedShape: const RoundedRectangleBorder(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            title: InkWell(
              onTap: () => widget.onToggleFocusRegiao(r.id),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          medalLabel,
                          style: TextStyle(
                            fontSize: i < 3 ? 18 : 13,
                            fontWeight: FontWeight.bold,
                            color: i >= 3 ? cs.onSurfaceVariant : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _tituloRegiaoRanking(r.nome),
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: barCor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            formatarMoedaPtBr(r.valorTotal),
                            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: barCor),
                          ),
                        ),
                        if (isFocused)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.map, size: 16, color: kBenfeitoriasMapaAccent),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 5,
                        backgroundColor: barCor.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(barCor),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      children: [
                        Text(
                          '${r.qtdTotal} registro(s)',
                          style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        GestureDetector(
                          onTap: () => widget.onToggleFocusRegiao(r.id),
                          child: Text(
                            isFocused ? '✕ Ver tudo' : '🗺 Filtrar',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: kBenfeitoriasMapaAccent,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        'Cidade',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      'Valor',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ...r.cidades.map((c) {
                final isSelected = c.key == widget.selectedMunicipioKey;
                return InkWell(
                  onTap: () => widget.onCityTap?.call(c.key),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: isSelected
                        ? BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: cs.primary, width: 1),
                          )
                        : null,
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.place : Icons.circle,
                          size: isSelected ? 14 : 6,
                          color: isSelected ? cs.primary : barCor.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.cidade,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: isSelected ? FontWeight.bold : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${c.qtd} reg.',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatarMoedaPtBr(c.valor),
                          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  // ── Lista comparativa (TSE 2022 vs Campanha) ─────────────────────────────

  Widget _buildListaComparativo(
    List<({String id, String nome, int total, int totalEstimativa, double pct, List<({String cidade, String key, int votos, double pct, int estimativa})> cidades})> ranking,
    int totalTse,
    int totalEstimativa,
    ColorScheme cs,
    ThemeData theme,
  ) {
    if (ranking.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sem dados TSE. Configure seu candidato em Meu Perfil.',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Legenda do comparativo
    final legendaWidget = Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final item in [
            (cor: '#D32F2F', label: '< 25%'),
            (cor: '#F57C00', label: '25–60%'),
            (cor: '#F9A825', label: '60–99%'),
            (cor: '#2E7D32', label: '≥ 100%'),
            (cor: '#FFD700', label: '> 150%'),
          ])
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: Color(int.parse(item.cor.replaceFirst('#', 'FF'), radix: 16)), shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text(item.label, style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        legendaWidget,
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: ranking.length,
            itemBuilder: (context, i) {
              final r = ranking[i];
              final ratio = r.total > 0 ? r.totalEstimativa / r.total : 0.0;
              final hexCor = _corAtingimento(ratio);
              final corAtingimento = Color(int.parse(hexCor.replaceFirst('#', 'FF'), radix: 16));
              final medalLabel = i < 3 ? _medals[i] : '${i + 1}º';
              final isFocused = widget.focusedRegiaoId == r.id;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: isFocused
                      ? Border.all(color: cs.primary, width: 2.5)
                      : Border.all(color: corAtingimento.withValues(alpha: 0.5)),
                  color: corAtingimento.withValues(alpha: isFocused ? 0.1 : 0.06),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: ExpansionTile(
                  shape: const RoundedRectangleBorder(),
                  collapsedShape: const RoundedRectangleBorder(),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  title: InkWell(
                    onTap: () => widget.onToggleFocusRegiao(r.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(medalLabel, style: TextStyle(fontSize: i < 3 ? 18 : 13, fontWeight: FontWeight.bold, color: i >= 3 ? cs.onSurfaceVariant : null)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _tituloRegiaoRanking(r.nome),
                                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: corAtingimento.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                                child: Text('${(ratio * 100).toStringAsFixed(1)}%', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: corAtingimento)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Barra dupla: TSE (base) vs campanha (progresso)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: 1.0,
                                  minHeight: 7,
                                  backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                                  valueColor: AlwaysStoppedAnimation<Color>(cs.outlineVariant.withValues(alpha: 0.3)),
                                ),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (ratio).clamp(0.0, 1.5) / 1.5,
                                  minHeight: 7,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(corAtingimento),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.how_to_vote_outlined, size: 12, color: cs.onSurfaceVariant),
                                const SizedBox(width: 2),
                                Text(formatarInteiroPtBr(r.total), style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                                Text(' TSE', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                              ]),
                              if (r.totalEstimativa > 0)
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.groups_outlined, size: 12, color: corAtingimento),
                                  const SizedBox(width: 2),
                                  Text(formatarInteiroPtBr(r.totalEstimativa), style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: corAtingimento)),
                                  Text(' camp.', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                                ]),
                              Text(_labelAtingimento(ratio), style: theme.textTheme.labelSmall?.copyWith(color: corAtingimento, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  children: [
                    const Divider(height: 1),
                    ...r.cidades.map((c) {
                      final cRatio = c.votos > 0 ? c.estimativa / c.votos : 0.0;
                      final cHex = _corAtingimento(cRatio);
                      final cCor = Color(int.parse(cHex.replaceFirst('#', 'FF'), radix: 16));
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: cCor, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(c.cidade, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text(
                              '${formatarInteiroPtBr(c.votos)} TSE  •  ${c.estimativa > 0 ? formatarInteiroPtBr(c.estimativa) : "—"} camp.',
                              style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Lista da rede (campanha) ────────────────────────────────────────────────

  Widget _buildListaRede(
    List<({String id, String nome, int estimativaTotal, List<({String cidade, String key, int estimativa})> cidades})> rankingRede,
    int totalEstimativa,
    ColorScheme cs,
    ThemeData theme,
  ) {
    if (rankingRede.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined, size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
              Text(
                'Nenhum dado da rede ainda.',
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Ative "Minha rede" nas camadas e cadastre votantes e apoiadores.',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: rankingRede.length,
      itemBuilder: (context, i) {
        final r = rankingRede[i];
        final isFocused = widget.focusedRegiaoId == r.id;
        final pct = totalEstimativa > 0 ? r.estimativaTotal / totalEstimativa * 100 : 0.0;
        final medalLabel = i < 3 ? _medals[i] : '${i + 1}º';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isFocused
                ? Border.all(color: cs.secondary, width: 2)
                : Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
            color: isFocused ? cs.secondaryContainer.withValues(alpha: 0.28) : null,
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: cs.secondary.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(),
            collapsedShape: const RoundedRectangleBorder(),
            tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            title: InkWell(
              onTap: () => widget.onToggleFocusRegiao(r.id),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          medalLabel,
                          style: TextStyle(
                            fontSize: i < 3 ? 18 : 13,
                            fontWeight: FontWeight.bold,
                            color: i >= 3 ? cs.onSurfaceVariant : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _tituloRegiaoRanking(r.nome),
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${pct.toStringAsFixed(1)}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.secondary,
                            ),
                          ),
                        ),
                        if (isFocused)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.map, size: 16, color: cs.secondary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Barra de progresso campanha
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 5,
                        backgroundColor: cs.secondary.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(cs.secondary),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.groups_outlined, size: 12, color: cs.secondary),
                            const SizedBox(width: 3),
                            Text(
                              formatarInteiroPtBr(r.estimativaTotal),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.secondary,
                              ),
                            ),
                            Text(
                              ' votos campanha',
                              style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => widget.onToggleFocusRegiao(r.id),
                          child: Text(
                            isFocused ? '✕ Ver tudo' : '🗺 Filtrar',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.secondary,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
                child: Row(
                  children: [
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        'Cidade',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      'Votos   %',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ...r.cidades.map((c) {
                final cpct = totalEstimativa > 0 ? c.estimativa / totalEstimativa * 100 : 0.0;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: cs.secondary.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          c.cidade,
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${formatarInteiroPtBr(c.estimativa)}  ${cpct.toStringAsFixed(1)}%',
                        style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}

/// Botão de aba no cabeçalho do ranking (TSE / Minha Rede).
class _TabBtn extends StatelessWidget {
  const _TabBtn({required this.label, required this.icon, required this.active, required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip de KPI no cabeçalho do ranking.
class _KpiChip extends StatelessWidget {
  const _KpiChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
    this.readableTextOnDark = false,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ThemeData theme;
  /// Texto do rótulo/valor em [onSurface] para leitura em chips coloridos no tema escuro.
  final bool readableTextOnDark;

  @override
  Widget build(BuildContext context) {
    final cs = theme.colorScheme;
    final labelColor = readableTextOnDark ? cs.onSurfaceVariant : color;
    final valueColor = readableTextOnDark ? cs.onSurface : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.65), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: labelColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


