import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../core/constants/regioes_fundidas.dart';
import '../../../../core/geo/lat_lng.dart';
import '../../data/geo_loader.dart';
import '../../data/mt_municipios_coords.dart';
import '../../data/tse_votos_escala.dart';
import '../../models/mapa_marcador_cidade.dart';
import 'bandeira_marcador_widget.dart';

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
    /// Dashboard/mobile: ranking em coluna abaixo do mapa (sem sobrepor o mapa).
    this.embedRankingBelowMap = false,
  });

  final double height;
  final Map<String, int>? votosPorMunicipio;
  /// Estimativa de votos por cidade (chave normalizada). Para comparativo com votos TSE.
  final Map<String, int>? estimativaPorCidade;
  /// Marcadores por cidade (contagem + bandeira opcional do apoiador).
  final Map<String, MapaMarcadorCidade>? cidadesMarcadoresMapa;
  final List<RegiaoFundida>? regioesFundidas;
  final Map<String, String>? nomesCustomizados;
  final Map<String, String>? coresCustomizadas;
  final void Function(String cdRgint, String nome)? onSaveNomeRegiao;
  final void Function(String cdRgint)? onRemoverDaFusao;
  final void Function(String cdRgint, String hexCor)? onSaveCorRegiao;
  final bool Function(String id, String nome, String? cdRgint)? onRegionTap;
  /// Ao clicar numa cidade (mapa ou legenda), recebe o nome do município (chave em votosPorMunicipio) para exibir locais de votação.
  final void Function(String nomeMunicipio)? onCityTap;
  /// Conteúdo "Locais de votação" para exibir dentro do painel lateral (ranking). Quando definido, aparece expandido no bloco do ranking.
  final Widget? locaisVotacaoContent;
  /// Chave do município atualmente selecionado (para evidenciar a linha no ranking).
  final String? selectedMunicipioKey;
  final bool embedRankingBelowMap;

  @override
  State<MapaRegionalWidget> createState() => _MapaRegionalWidgetWebState();
}

/// Limites do Brasil (delimitação do território nacional).
/// Restringe a câmera para não mostrar nada além do Brasil; ver assets/geo/delimitacao_brasil.json.
final _brasilBounds = LatLngBounds(
  ll.LatLng(-33.75, -73.99),  // sudoeste Brasil
  ll.LatLng(5.27, -34.79),    // nordeste Brasil
);

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

Color _colorForRegiao(String? cdRgint, String id, Map<String, String>? coresCustomizadas, {String? partKey}) {
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

  RegiaoIntermediariaMT? get _regiaoDrillDown {
    final id = _regiaoDrillDownId;
    if (id == null) return null;
    return _regioesMT?.where((r) => r.id == id).firstOrNull;
  }

  /// Votos TSE a mostrar nas bolhas (filtrados se drill-down ativo).
  Map<String, int>? get _votosParaBolhas {
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

    // 2) Delimitações das regiões de MT: só borda; preenchimento transparente. Cor só na região clicada.
    // Drill-down: só desenha a região selecionada (as outras somem).
    final mtList = _regioesMT;
    if (mtList != null) {
      const neutralBorder = Color(0xFF757575);
      for (final regiao in mtList) {
        if (_regiaoDrillDownId != null && regiao.id != _regiaoDrillDownId) continue;
        var polygonIndex = 0;
        for (final geo in regiao.polygons) {
          final isEditing = regiao.id == _editingRegionId && polygonIndex == _editingPolygonIndex;
          final partKey = '${regiao.id}#$polygonIndex';
          final color = _colorForRegiao(regiao.cdRgint, regiao.id, widget.coresCustomizadas, partKey: partKey);
          final points = geo.points.map((p) => ll.LatLng(p.latitude, p.longitude)).toList();
          final holes = geo.holes
              .map((hole) => hole.map((p) => ll.LatLng(p.latitude, p.longitude)).toList())
              .toList();
          polygons.add(Polygon<String>(
            points: points,
            holePointsList: holes.isEmpty ? null : holes,
            color: isEditing ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderColor: isEditing ? Colors.white : neutralBorder,
            borderStrokeWidth: isEditing ? 5 : 1,
            hitValue: '${regiao.id}#$polygonIndex',
          ));
          polygonIndex++;
        }
      }
    }
    return polygons;
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

  /// Mapa + faixa drill-down + tooltip (sem ranking sobreposto).
  Widget _buildMapStackContent(
    BuildContext context,
    List<Polygon<String>> polygons,
    List<Marker> heatMarkers,
    List<Marker> markers,
  ) {
    final drillNome = _regiaoDrillDown?.nome;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        MouseRegion(
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
                simplificationTolerance: 0.5,
                useAltRendering: true,
              ),
              if (heatMarkers.isNotEmpty) MarkerLayer(markers: heatMarkers),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
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
                        'Só esta região: $drillNome',
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
      context: context,
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
    final ranking = _rankingRegioes();
    final totalVotosTseGeral = _totalVotosTseSomados();
    final totalEstimativaGeral = _totalEstimativaSomada();

    // Dashboard/mobile embutido: mapa e ranking em coluna — o mapa deixa de ser tapado pelo painel.
    if (widget.embedRankingBelowMap) {
      if (ranking.isEmpty) {
        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: _buildMapStackContent(context, polygons, heatMarkers, markers),
        );
      }
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 13,
              child: _buildMapStackContent(context, polygons, heatMarkers, markers),
            ),
            Expanded(
              flex: 11,
              child: _RankingPanel(
                ranking: ranking,
                totalVotosTseGeral: totalVotosTseGeral,
                totalEstimativaGeral: totalEstimativaGeral,
                onCityTap: widget.onCityTap,
                locaisVotacaoContent: widget.locaisVotacaoContent,
                selectedMunicipioKey: widget.selectedMunicipioKey,
                layoutCompact: true,
                focusedRegiaoId: _regiaoDrillDownId,
                onToggleFocusRegiao: (id) {
                  if (_regiaoDrillDownId == id) {
                    _setDrillDownRegiao(null);
                  } else {
                    _setDrillDownRegiao(id);
                  }
                },
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
          // Sobre o mapa (tela cheia estreita): painel mais baixo para não cobrir o território.
          final bottomPanelH = math.max(
            168.0,
            math.min(300.0, constraints.maxHeight * 0.36),
          );
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: _buildMapStackContent(context, polygons, heatMarkers, markers),
              ),
              if (ranking.isNotEmpty)
                narrow
                    ? Positioned(
                        left: 8,
                        right: 8,
                        bottom: 8,
                        height: bottomPanelH,
                        child: _RankingPanel(
                          ranking: ranking,
                          totalVotosTseGeral: totalVotosTseGeral,
                          totalEstimativaGeral: totalEstimativaGeral,
                          onCityTap: widget.onCityTap,
                          locaisVotacaoContent: widget.locaisVotacaoContent,
                          selectedMunicipioKey: widget.selectedMunicipioKey,
                          layoutCompact: true,
                          focusedRegiaoId: _regiaoDrillDownId,
                          onToggleFocusRegiao: (id) {
                            if (_regiaoDrillDownId == id) {
                              _setDrillDownRegiao(null);
                            } else {
                              _setDrillDownRegiao(id);
                            }
                          },
                        ),
                      )
                    : Positioned(
                        right: 8,
                        top: _regiaoDrillDownId != null ? 56 : 8,
                        bottom: 8,
                        child: _RankingPanel(
                          ranking: ranking,
                          totalVotosTseGeral: totalVotosTseGeral,
                          totalEstimativaGeral: totalEstimativaGeral,
                          onCityTap: widget.onCityTap,
                          locaisVotacaoContent: widget.locaisVotacaoContent,
                          selectedMunicipioKey: widget.selectedMunicipioKey,
                          layoutCompact: false,
                          focusedRegiaoId: _regiaoDrillDownId,
                          onToggleFocusRegiao: (id) {
                            if (_regiaoDrillDownId == id) {
                              _setDrillDownRegiao(null);
                            } else {
                              _setDrillDownRegiao(id);
                            }
                          },
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
class _RankingPanel extends StatelessWidget {
  const _RankingPanel({
    required this.ranking,
    required this.totalVotosTseGeral,
    required this.totalEstimativaGeral,
    this.onCityTap,
    this.locaisVotacaoContent,
    this.selectedMunicipioKey,
    this.layoutCompact = false,
    this.focusedRegiaoId,
    required this.onToggleFocusRegiao,
  });

  final List<({String id, String nome, int total, int totalEstimativa, double pct, List<({String cidade, String key, int votos, double pct, int estimativa})> cidades})> ranking;
  /// Soma real dos votos TSE (todos os municípios); o ranking por região pode somar menos se algum município não cair no polígono.
  final int totalVotosTseGeral;
  final int totalEstimativaGeral;
  final void Function(String nomeMunicipio)? onCityTap;
  final Widget? locaisVotacaoContent;
  final String? selectedMunicipioKey;
  /// Em ecrãs estreitos o painel fica na parte inferior do mapa; usa largura total.
  final bool layoutCompact;
  /// Região em modo drill-down no mapa (só essa região visível).
  final String? focusedRegiaoId;
  /// Alterna foco: se já for [id], o mapa volta a mostrar todo o estado.
  final void Function(String regiaoId) onToggleFocusRegiao;

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
    final showLocais = locaisVotacaoContent != null;
    final fmt = NumberFormat('#,##0', 'pt_BR');
    final screenW = MediaQuery.sizeOf(context).width;
    final panelWidth = layoutCompact
        ? double.infinity
        : math.min(400.0, math.max(220.0, screenW * 0.42));

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
                            onPressed: () => onToggleFocusRegiao(focusedRegiaoId!),
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
                    // KPIs resumo
                    Row(
                      children: [
                        Expanded(child: _KpiChip(
                          icon: Icons.how_to_vote_outlined,
                          label: 'TSE 2022',
                          value: fmt.format(totalVotosTseGeral),
                          color: cs.primary,
                          theme: theme,
                        )),
                        const SizedBox(width: 8),
                        if (totalEstimativaGeral > 0)
                          Expanded(child: _KpiChip(
                            icon: Icons.analytics_outlined,
                            label: 'Campanha',
                            value: fmt.format(totalEstimativaGeral),
                            color: cs.secondary,
                            theme: theme,
                          )),
                      ],
                    ),
                    if (onCityTap != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Toque na região para filtrar o mapa • Toque na cidade para ver urnas',
                          style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Lista de regiões ────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  itemCount: ranking.length,
                  itemBuilder: (context, i) {
                    final r = ranking[i];
                    final isFocused = focusedRegiaoId == r.id;
                    final containsSelected = selectedMunicipioKey != null &&
                        r.cidades.any((c) => c.key == selectedMunicipioKey);
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
                            ? cs.primaryContainer.withValues(alpha: 0.25)
                            : containsSelected
                                ? cs.secondaryContainer.withValues(alpha: 0.15)
                                : null,
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: containsSelected || isFocused,
                        shape: const RoundedRectangleBorder(),
                        collapsedShape: const RoundedRectangleBorder(),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        title: InkWell(
                          onTap: () => onToggleFocusRegiao(r.id),
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
                                        r.nome,
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
                                // Números TSE + estimativa
                                Row(
                                  children: [
                                    Icon(Icons.how_to_vote_outlined, size: 12, color: cs.onSurfaceVariant),
                                    const SizedBox(width: 3),
                                    Text(
                                      fmt.format(r.total),
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    Text(
                                      ' votos TSE',
                                      style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                                    ),
                                    if (r.totalEstimativa > 0) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.groups_outlined, size: 12, color: cs.secondary),
                                      const SizedBox(width: 3),
                                      Text(
                                        fmt.format(r.totalEstimativa),
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
                                    const Spacer(),
                                    Text(
                                      isFocused ? 'Ver tudo' : 'Filtrar mapa',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: cs.primary,
                                        decoration: TextDecoration.underline,
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
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Cidade',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurfaceVariant,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    'TSE',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '%',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...r.cidades.map((c) {
                            final isSelected = c.key == selectedMunicipioKey;
                            return InkWell(
                              onTap: () => onCityTap?.call(c.key),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                              '${fmt.format(c.estimativa)} campanha',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: cs.secondary,
                                                fontSize: 9,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        fmt.format(c.votos),
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        '${c.pct.toStringAsFixed(1)}%',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                        textAlign: TextAlign.right,
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
                Expanded(flex: 1, child: locaisVotacaoContent!),
              ],
            ],
          ),
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
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color.withValues(alpha: 0.8))),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
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
