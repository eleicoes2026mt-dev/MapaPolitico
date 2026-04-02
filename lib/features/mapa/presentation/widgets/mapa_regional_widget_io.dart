import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arcgis_maps/arcgis_maps.dart';
import '../../../../core/constants/regioes_fundidas.dart';
import '../../../../core/geo/lat_lng.dart';
import '../../data/geo_loader.dart';
import '../../data/mt_municipios_coords.dart';
import '../../data/tse_votos_escala.dart';
import '../../../../models/bandeira_visual.dart';
import '../../models/mapa_marcador_cidade.dart';

const _prefsKeyRegionNames = 'mapa_regioes_nomes';

/// ID do item do mapa base MT no ArcGIS (Web Map). Se não for Web Map, usa basemap padrão.
const arcGisMapItemId = 'cc5f37a5d30c4fb3a04e0ee054ab0cde';

/// Centro de Mato Grosso (Cuiabá)
const mtCenterLatLng = LatLng(-15.6014, -56.0979);

/// Centro aproximado do Brasil (para vista inicial que enquadra o país)
const _brasilCenterLatLng = LatLng(-14.2, -51.9);

/// Escala para enquadrar o Brasil inteiro na vista inicial (~1:25M)
const _brasilViewScale = 25000000.0;

/// Coordenadas das cidades-sede das regiões intermediárias de MT (marcadores no mapa).
const polosMT = [
  ('Cuiabá', LatLng(-15.6014, -56.0979)),
  ('Rondonópolis', LatLng(-16.4677, -54.6362)),
  ('Sinop', LatLng(-11.8642, -55.5094)),
  ('Barra do Garças', LatLng(-15.8896, -52.2569)),
  ('Tangará da Serra', LatLng(-14.6229, -57.4933)),
];

const nomeEstadoCandidato = 'Mato Grosso';

/// Widget reutilizável: mapa ArcGIS (Android/iOS) com demarcação Brasil/estados, cidades e votos TSE.
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
    // Ignorados no ArcGIS — só usados na versão web
    this.onMostrarTSE,
    this.onMostrarMarcadores,
    this.mostrarTSE = false,
    this.mostrarMarcadores = false,
    this.onComparativoColors,
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
  /// Na web, exibido dentro do painel ranking; em mobile ignorado.
  final Widget? locaisVotacaoContent;
  /// Na web, evidencia a linha da cidade no ranking; em mobile ignorado.
  final String? selectedMunicipioKey;
  final bool embedRankingBelowMap;
  final void Function(bool)? onMostrarTSE;
  final void Function(bool)? onMostrarMarcadores;
  final bool mostrarTSE;
  final bool mostrarMarcadores;
  final void Function(Map<String, String>?)? onComparativoColors;

  @override
  State<MapaRegionalWidget> createState() => _MapaRegionalWidgetState();
}

class _MapaRegionalWidgetState extends State<MapaRegionalWidget> {
  ArcGISMapViewController? _mapController;
  List<RegiaoIntermediariaMT>? _regioesMTList;
  String? _hoveredRegionId;
  String? _hoveredRegionName;
  Offset? _hoverPosition;
  Map<String, String> _customRegionNames = {};
  String? _editingRegionId;
  /// Drill-down: só polígonos e bolhas desta região imediata (toque sem admin).
  String? _regiaoDrillDownId;
  bool _geoLoaded = false;
  GraphicsOverlay? _overlayRegioesMT;

  bool _municipioVisivelNoDrill(String municipioKey) {
    final id = _regiaoDrillDownId;
    if (id == null) return true;
    final list = _regioesMTList;
    if (list == null) return true;
    RegiaoIntermediariaMT? reg;
    for (final r in list) {
      if (r.id == id) {
        reg = r;
        break;
      }
    }
    if (reg == null) return true;
    final coords = getCoordsMunicipioMT(municipioKey);
    if (coords == null) return false;
    return pointInRegion(LatLng(coords.latitude, coords.longitude), reg.polygons);
  }

  static SpatialReference get _wgs84 => SpatialReference.wgs84;

  @override
  void didUpdateWidget(covariant MapaRegionalWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.votosPorMunicipio != widget.votosPorMunicipio ||
        oldWidget.cidadesMarcadoresMapa != widget.cidadesMarcadoresMapa ||
        oldWidget.coresCustomizadas != widget.coresCustomizadas) {
      _loadGeo();
    }
  }

  void _setEditingRegion(String? regionId) {
    if (_editingRegionId == regionId) return;
    setState(() => _editingRegionId = regionId);
    _loadGeo();
  }

  static bool _pointInRing(LatLng p, List<LatLng> ring) {
    final n = ring.length;
    bool inside = false;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final vi = ring[i], vj = ring[j];
      final cross = (vi.latitude > p.latitude) != (vj.latitude > p.latitude);
      if (cross) {
        final slope = (vj.latitude - vi.latitude).abs() < 1e-10
            ? null
            : (vj.longitude - vi.longitude) * (p.latitude - vi.latitude) / (vj.latitude - vi.latitude) + vi.longitude;
        if (slope != null && p.longitude < slope) inside = !inside;
      }
    }
    return inside;
  }

  static bool _pointInGeoPolygon(LatLng p, GeoPolygon geo) {
    if (!_pointInRing(p, geo.points)) return false;
    for (final hole in geo.holes) {
      if (_pointInRing(p, hole)) return false;
    }
    return true;
  }

  (String id, String nome, String? cdRgint)? _findRegionAt(LatLng p) {
    final list = _regioesMTList;
    if (list == null) return null;
    for (final regiao in list) {
      for (final geo in regiao.polygons) {
        if (_pointInGeoPolygon(p, geo)) return (regiao.id, regiao.nome, regiao.cdRgint);
      }
    }
    return null;
  }

  Future<void> _showEditRegionNameDialog(
    BuildContext context,
    String regionId,
    String nomeOriginal,
    String? cdRgint,
  ) async {
    _setEditingRegion(regionId);
    // No mapa só o nome oficial do GeoJSON no campo inicial.
    final nomeController = TextEditingController(text: nomeOriginal);
    const coresOpcoes = [
      '#2196F3', '#4CAF50', '#FF9800', '#9C27B0', '#F44336', '#009688', '#FFC107', '#3F51B5', '#FF5722', '#9E9E9E',
      '#E91E63', '#00BCD4', '#8BC34A', '#795548', '#607D8B', '#673AB7', '#CDDC39', '#FF4081', '#FF6F00', '#00695C',
      '#37474F', '#7B1FA2', '#C2185B', '#1976D2', '#388E3C', '#F9A825', '#D32F2F', '#5D4037',
    ];
    String? corSelecionada = cdRgint != null ? (widget.coresCustomizadas?[cdRgint] ?? _coresPadrao[cdRgint]) : null;
    if (corSelecionada == null || !coresOpcoes.contains(corSelecionada)) corSelecionada = coresOpcoes.first;

    final fundidas = widget.regioesFundidas ?? [];
    final estaEmFusao = cdRgint != null && fundidas.any((f) => f.ids.contains(cdRgint) && f.ids.length > 1);
    bool aplicarSoNestaRegiao = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Editar região'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da região',
                    hintText: 'Ex.: Juína, Cuiabá',
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
                    'Esta região faz parte de uma fusão. Marque acima para que só esta região receba o novo nome.',
                    style: Theme.of(ctx2).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx2).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Cor da região', style: Theme.of(ctx2).textTheme.labelLarge),
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
    );
    _setEditingRegion(null);
    if (saved != true || !mounted) return;
    if (aplicarSoNestaRegiao && widget.onRemoverDaFusao != null && cdRgint != null) {
      widget.onRemoverDaFusao!(cdRgint);
    }
    final nome = nomeController.text.trim();
    if (nome.isEmpty) return;
    if (widget.onSaveNomeRegiao != null && cdRgint != null) {
      widget.onSaveNomeRegiao!(cdRgint, nome);
    } else {
      setState(() => _customRegionNames[regionId] = nome);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyRegionNames, jsonEncode(_customRegionNames));
    }
    if (widget.onSaveCorRegiao != null && cdRgint != null && corSelecionada != null) {
      widget.onSaveCorRegiao!(cdRgint, corSelecionada!);
    }
  }

  static Geometry? _geoPolygonToArcGIS(GeoPolygon geo) {
    final sr = _wgs84;
    final parts = MutablePartCollection(spatialReference: sr);
    void addRing(List<LatLng> ring) {
      if (ring.length < 2) return;
      final part = MutablePart(spatialReference: sr);
      for (final p in ring) {
        part.addPointXY(x: p.longitude, y: p.latitude);
      }
      parts.addPart(part);
    }
    addRing(geo.points);
    for (final hole in geo.holes) addRing(hole);
    if (parts.isEmpty) return null;
    final builder = PolygonBuilder(spatialReference: sr);
    builder.parts = parts;
    return builder.toGeometry();
  }

  static const _coresPadrao = <String, String>{
    '5101': '#2196F3',
    '5102': '#4CAF50',
    '5103': '#FF9800',
    '5104': '#9C27B0',
    '5105': '#F44336',
  };

  static Color _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return Colors.grey;
  }

  Color _colorForRegiao(String id) {
    final custom = widget.coresCustomizadas?[id];
    if (custom != null && custom.isNotEmpty) return _colorFromHex(custom);
    return _colorFromHex(_coresPadrao[id] ?? '#9E9E9E');
  }

  Future<void> _loadGeo() async {
    final brasil = await loadGeoJsonFromAsset('assets/geo/brasil.json');
    final regioesEstados = await loadDelimitacaoEstadosFromAsset();
    final regioesMT = await loadRegioesImediatasMTFromAsset(kMTRegioesImediatas2024Asset);

    if (!mounted) return;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final outline = theme.colorScheme.outline;

    final overlayBase = GraphicsOverlay();
    int id = 0;

    for (final region in brasil) {
      for (final geo in region.polygons) {
        final g = _geoPolygonToArcGIS(geo);
        if (g != null) {
          final sym = SimpleFillSymbol(
            color: Colors.grey.withValues(alpha: 0.06),
          );
          sym.outline = SimpleLineSymbol(color: outline.withValues(alpha: 0.5), width: 1);
          overlayBase.graphics.add(
            Graphic(geometry: g, symbol: sym, attributes: {'layer': 'br', 'id': id++}),
          );
        }
      }
    }

    // Apenas MT: desenha só a delimitação de Mato Grosso (não desenha os outros estados).
    final overlayEstados = GraphicsOverlay();
    for (final regiao in regioesEstados) {
      if (regiao.nome != nomeEstadoCandidato) continue;
      final strokeColor = primary.withValues(alpha: 0.85);
      const strokeWidth = 2.0;

      for (final geo in regiao.polygons) {
        final g = _geoPolygonToArcGIS(geo);
        if (g != null) {
          final sym = SimpleFillSymbol(color: Colors.transparent);
          sym.outline = SimpleLineSymbol(color: strokeColor, width: strokeWidth);
          overlayEstados.graphics.add(
            Graphic(
              geometry: g,
              symbol: sym,
              attributes: {'layer': 'est', 'id': id++},
            ),
          );
        }
      }
    }

    final overlayRegioesMT = GraphicsOverlay();
    const neutralBorder = Color(0xFF757575);
    for (final regiao in regioesMT) {
      if (_regiaoDrillDownId != null && regiao.id != _regiaoDrillDownId) continue;
      final color = _colorForRegiao(regiao.cdRgint ?? regiao.id);
      final regionId = regiao.id;
      final nomeOriginal = regiao.nome;
      final cdRgint = regiao.cdRgint;

      for (final geo in regiao.polygons) {
        final g = _geoPolygonToArcGIS(geo);
        if (g != null) {
          final isEditing = regionId == _editingRegionId;
          final sym = SimpleFillSymbol(
            color: isEditing ? color.withValues(alpha: 0.2) : Colors.transparent,
          );
          sym.outline = SimpleLineSymbol(
            color: isEditing ? Colors.white : neutralBorder,
            width: isEditing ? 5 : 1,
          );
          overlayRegioesMT.graphics.add(
            Graphic(
              geometry: g,
              symbol: sym,
              attributes: {
                'layer': 'rg',
                'regionId': regionId,
                'nome': nomeOriginal,
                'cdRgint': cdRgint ?? '',
              },
            ),
          );
        }
      }
    }

    final overlayMarkers = GraphicsOverlay();
    for (var i = 0; i < polosMT.length; i++) {
      final p = polosMT[i];
      final markerSym = SimpleMarkerSymbol(
        style: SimpleMarkerSymbolStyle.circle,
        color: Colors.red,
        size: 12,
      );
      markerSym.outline = SimpleLineSymbol(color: Colors.white, width: 2);
      overlayMarkers.graphics.add(
        Graphic(
          geometry: ArcGISPoint(x: p.$2.longitude, y: p.$2.latitude, spatialReference: _wgs84),
          symbol: markerSym,
          attributes: {'title': p.$1, 'type': 'polo'},
        ),
      );
    }

    final votos = widget.votosPorMunicipio;
    if (votos != null && votos.isNotEmpty) {
      final votosList = votos.entries
          .map((e) => (key: e.key, v: e.value, coords: getCoordsMunicipioMT(e.key)))
          .where((e) => e.coords != null)
          .where((e) => _municipioVisivelNoDrill(e.key))
          .toList();
      if (votosList.isNotEmpty) {
        final mm = minMaxVotos(votos);
        final minV = mm.minV;
        final maxV = mm.maxV;
        const sizeMin = 5.0;
        const sizeMax = 24.0;
        for (final e in votosList) {
          final tVis = proporcaoVisualVotos(e.v, minV, maxV);
          final size = sizeMin + (sizeMax - sizeMin) * tVis;
          final tier = tierParaVotos(e.v, minV, maxV);
          final cor = corHeatmapVotos(e.v, minV, maxV);
          final tseSym = SimpleMarkerSymbol(
            style: SimpleMarkerSymbolStyle.circle,
            color: cor,
            size: size,
          );
          tseSym.outline = SimpleLineSymbol(color: Colors.white.withValues(alpha: 0.95), width: 1.5);
          overlayMarkers.graphics.add(
            Graphic(
              geometry: ArcGISPoint(x: e.coords!.longitude, y: e.coords!.latitude, spatialReference: _wgs84),
              symbol: tseSym,
              attributes: {
                'title': e.key,
                'snippet': '${e.v} votos (TSE) — ${tier.tituloCurto}',
                'type': 'tse',
              },
            ),
          );
        }
      }
    }

    Color marcadorCor(MapaMarcadorCidade m) {
      final v = m.bandeiraVisual;
      if (v != null) return v.corDominanteMapa;
      final h = m.bandeiraCorPrimariaHex;
      if (h == null || h.isEmpty) return Colors.green;
      final s = h.replaceFirst('#', '');
      if (s.length == 6) {
        return Color(int.parse('FF$s', radix: 16));
      }
      return Colors.green;
    }

    final marcadoresPorCidade = widget.cidadesMarcadoresMapa;
    if (marcadoresPorCidade != null && marcadoresPorCidade.isNotEmpty) {
      for (final e in marcadoresPorCidade.entries) {
        if (!_municipioVisivelNoDrill(e.key)) continue;
        final coords = getCoordsMunicipioMT(e.key);
        if (coords != null) {
          final m = e.value;
          final apSym = SimpleMarkerSymbol(
            style: SimpleMarkerSymbolStyle.circle,
            color: marcadorCor(m),
            size: m.bandeiraEmoji != null && m.bandeiraEmoji!.trim().isNotEmpty ? 12 : 10,
          );
          apSym.outline = SimpleLineSymbol(color: Colors.white, width: 1);
          overlayMarkers.graphics.add(
            Graphic(
              geometry: ArcGISPoint(x: coords.longitude, y: coords.latitude, spatialReference: _wgs84),
              symbol: apSym,
              attributes: {
                'title': e.key,
                'snippet':
                    '${m.quantidade} na rede${m.bandeiraEmoji != null && m.bandeiraEmoji!.trim().isNotEmpty ? ' ${m.bandeiraEmoji}' : ''}',
                'type': 'apoiador',
              },
            ),
          );
        }
      }
    }

    _overlayRegioesMT = overlayRegioesMT;
    _regioesMTList = regioesMT;

    final ctrl = _mapController;
    if (ctrl != null) {
      ctrl.graphicsOverlays
        ..clear()
        ..addAll([overlayBase, overlayEstados, overlayRegioesMT, overlayMarkers]);
    }

    setState(() => _geoLoaded = true);
  }

  Future<void> _tryLoadArcGISWebMap(ArcGISMapViewController ctrl) async {
    try {
      final portal = Portal.arcGISOnline();
      await portal.load();
      if (!mounted) return;
      final item = PortalItem.withPortalAndItemId(portal: portal, itemId: arcGisMapItemId);
      await item.load();
      if (!mounted) return;
      if (item.type == PortalItemType.webMap) {
        final webMap = ArcGISMap.withItem(item);
        webMap.initialViewpoint = Viewpoint.withLatLongScale(
          latitude: _brasilCenterLatLng.latitude,
          longitude: _brasilCenterLatLng.longitude,
          scale: _brasilViewScale,
        );
        ctrl.arcGISMap = webMap;
      }
    } catch (_) {}
  }

  Future<void> _loadCustomNames() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKeyRegionNames);
    if (json == null) return;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>?;
      if (map != null && mounted) {
        setState(() => _customRegionNames = map.map((k, v) => MapEntry(k.toString(), v is String ? v : v.toString())));
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    if (widget.onSaveNomeRegiao == null) _loadCustomNames();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: MouseRegion(
        onHover: (e) async {
          final ctrl = _mapController;
          if (ctrl == null || !_geoLoaded) return;
          try {
            final point = ctrl.screenToLocation(screen: e.localPosition);
            if (point == null || !mounted) return;
            final latLng = LatLng(point.y, point.x);
            final found = _findRegionAt(latLng);
            setState(() {
              if (found != null) {
                _hoveredRegionId = found.$1;
                // No mapa só o nome oficial do GeoJSON (padronizado).
                _hoveredRegionName = found.$2;
              } else {
                _hoveredRegionId = null;
                _hoveredRegionName = null;
              }
              _hoverPosition = found != null ? e.localPosition : null;
            });
          } catch (_) {}
        },
        onExit: (_) {
          setState(() {
            _hoveredRegionId = null;
            _hoveredRegionName = null;
            _hoverPosition = null;
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ArcGISMapView(
              controllerProvider: () {
                final ctrl = ArcGISMapView.createController();
                final map = ArcGISMap.withBasemapStyle(BasemapStyle.arcGISTopographic);
                map.initialViewpoint = Viewpoint.withLatLongScale(
                  latitude: _brasilCenterLatLng.latitude,
                  longitude: _brasilCenterLatLng.longitude,
                  scale: _brasilViewScale,
                );
                ctrl.arcGISMap = map;
                ctrl.graphicsOverlays.addAll([
                  GraphicsOverlay(),
                  GraphicsOverlay(),
                  GraphicsOverlay(),
                ]);
                // Desabilita rotação — o mapa sempre fica com norte para cima.
                ctrl.interactionOptions.rotateEnabled = false;
                _mapController = ctrl;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadGeo();
                  _tryLoadArcGISWebMap(ctrl);
                });
                return ctrl;
              },
              onMapViewReady: () {},
              onTap: (screenPosition) async {
                final ctrl = _mapController;
                final overlay = _overlayRegioesMT;
                if (ctrl == null || overlay == null) return;

                try {
                  final results = await ctrl.identifyGraphicsOverlays(
                    screenPoint: screenPosition,
                    tolerance: 12,
                    maximumResultsPerOverlay: 1,
                  );
                  for (final result in results) {
                    if (result.graphicsOverlay != overlay) continue;
                    for (final g in result.graphics) {
                      final att = g.attributes;
                      final regionId = att['regionId'] as String?;
                      final nome = att['nome'] as String?;
                      final cdRgint = att['cdRgint'] as String?;
                      if (regionId != null && nome != null && mounted) {
                        if (widget.onRegionTap != null && widget.onRegionTap!(regionId, nome, cdRgint)) return;
                        if (widget.onSaveNomeRegiao == null) {
                          setState(() {
                            _regiaoDrillDownId = _regiaoDrillDownId == regionId ? null : regionId;
                          });
                          _loadGeo();
                          return;
                        }
                        _showEditRegionNameDialog(context, regionId, nome, cdRgint);
                      }
                      return;
                    }
                  }
                } catch (_) {}
              },
            ),
            if (!_geoLoaded)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text('Carregando demarcações...'),
                    ),
                  ),
                ),
              ),
            if (_hoveredRegionId != null && _hoveredRegionName != null && _hoverPosition != null)
              Positioned(
                left: _hoverPosition!.dx + 12,
                top: _hoverPosition!.dy + 8,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      'Região: $_hoveredRegionName',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
