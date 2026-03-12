import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../../core/constants/regioes_fundidas.dart';
import '../../../../core/geo/lat_lng.dart';
import '../../data/geo_loader.dart';
import '../../data/mt_municipios_coords.dart';

/// Mapa para **web**: OpenStreetMap + regiões de MT (flutter_map).
/// Mesma funcionalidade de regiões, toque e tooltip que no app mobile.
class MapaRegionalWidget extends StatefulWidget {
  const MapaRegionalWidget({
    super.key,
    this.height = 400,
    this.votosPorMunicipio,
    this.estimativaPorCidade,
    this.cidadesComApoiador,
    this.regioesFundidas,
    this.nomesCustomizados,
    this.coresCustomizadas,
    this.onSaveNomeRegiao,
    this.onRemoverDaFusao = null,
    this.onSaveCorRegiao,
    this.onRegionTap,
    this.onCityTap,
  });

  final double height;
  final Map<String, int>? votosPorMunicipio;
  /// Estimativa de votos por cidade (chave normalizada). Para comparativo com votos TSE.
  final Map<String, int>? estimativaPorCidade;
  final Map<String, int>? cidadesComApoiador;
  final List<RegiaoFundida>? regioesFundidas;
  final Map<String, String>? nomesCustomizados;
  final Map<String, String>? coresCustomizadas;
  final void Function(String cdRgint, String nome)? onSaveNomeRegiao;
  final void Function(String cdRgint)? onRemoverDaFusao;
  final void Function(String cdRgint, String hexCor)? onSaveCorRegiao;
  final bool Function(String id, String nome, String? cdRgint)? onRegionTap;
  /// Ao clicar numa cidade (mapa ou legenda), recebe o nome do município (chave em votosPorMunicipio) para exibir locais de votação.
  final void Function(String nomeMunicipio)? onCityTap;

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
  bool _loading = true;
  String? _error;

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
    final mtList = _regioesMT;
    if (mtList != null) {
      const neutralBorder = Color(0xFF757575);
      for (final regiao in mtList) {
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

  /// Mapa de calor: marcadores com degradê transparente nas bordas (centro forte, bordas fracas).
  List<Marker> _buildHeatMarkers() {
    final votos = widget.votosPorMunicipio;
    if (votos == null || votos.isEmpty) return [];

    final entries = votos.entries
        .map((e) => (nome: e.key, votos: e.value, coords: getCoordsMunicipioMT(e.key)))
        .where((e) => e.coords != null)
        .toList();
    if (entries.isEmpty) return [];

    final minV = entries.map((e) => e.votos).reduce((a, b) => a < b ? a : b);
    final maxV = entries.map((e) => e.votos).reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).clamp(1, double.infinity).toDouble();

    const sizeMin = 24.0;
    const sizeMax = 80.0;

    return entries.map((e) {
      final t = ((e.votos - minV) / range).clamp(0.0, 1.0);
      final size = sizeMin + (sizeMax - sizeMin) * (t * 0.5 + 0.5);
      final centerColor = Color.lerp(
        Colors.orange.shade400,
        Colors.deepOrange.shade800,
        t,
      )!.withValues(alpha: 0.75);
      final edgeColor = centerColor.withValues(alpha: 0.0);
      return Marker(
        point: ll.LatLng(e.coords!.latitude, e.coords!.longitude),
        width: size,
        height: size,
        child: Tooltip(
          message: '${displayNomeCidadeMT(e.nome)}: ${e.votos} votos (TSE). Toque para ver locais de votação.',
          child: GestureDetector(
            onTap: () => widget.onCityTap?.call(e.nome),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [centerColor, edgeColor],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Apenas marcadores de cidades com apoiadores (votos TSE ficam só no calor).
  List<Marker> _buildMarkers() {
    final markers = <Marker>[];
    final apoiadores = widget.cidadesComApoiador;
    if (apoiadores != null && apoiadores.isNotEmpty) {
      for (final e in apoiadores.entries) {
        final coords = getCoordsMunicipioMT(e.key);
        if (coords != null) {
          final nome = displayNomeCidadeMT(e.key);
          markers.add(
            Marker(
              point: ll.LatLng(coords.latitude, coords.longitude),
              width: 24,
              height: 24,
              child: Tooltip(
                message: '$nome: ${e.value} apoiador(es)',
                child: Icon(Icons.people, color: Colors.green.shade700, size: 24),
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

  /// Agrega votos por região (região imediata) usando point-in-polygon. Ordenado por total decrescente.
  /// Inclui estimativa por cidade e por região para comparativo.
  List<({String id, String nome, int total, int totalEstimativa, List<({String cidade, String key, int votos, double pct, int estimativa})> cidades})> _rankingRegioes() {
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
      return (id: id, nome: nome, total: total, totalEstimativa: totalEstimativa, cidades: cidades);
    }).toList();
    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  /// Top cidades por votos (para a legenda "Locais mais votados") com percentual, estimativa e chave para onCityTap.
  List<({String nome, String key, int votos, double pct, int estimativa})> _topLocaisVotados({int limit = 10}) {
    final votos = widget.votosPorMunicipio;
    if (votos == null || votos.isEmpty) return [];
    final total = votos.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return [];
    final list = votos.entries
        .map((e) => (
              nome: displayNomeCidadeMT(e.key),
              key: e.key,
              votos: e.value,
              pct: e.value / total * 100,
              estimativa: _estimativaCidade(e.key),
            ))
        .toList();
    list.sort((a, b) => b.votos.compareTo(a.votos));
    return list.take(limit).toList();
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
      if (mounted) setState(() {
        _editingRegionId = null;
        _editingPolygonIndex = null;
      });
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
    final topLocais = _topLocaisVotados(limit: 10);

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
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
          if (topLocais.isNotEmpty)
            Positioned(
              left: 8,
              bottom: 8,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.whatshot, size: 18, color: Colors.deepOrange.shade800),
                          const SizedBox(width: 6),
                          Text(
                            'Locais mais votados',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ...topLocais.asMap().entries.map((e) {
                        final i = e.key + 1;
                        final loc = e.value;
                        return InkWell(
                          onTap: () => widget.onCityTap?.call(loc.key),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2, bottom: 2),
                            child: Text(
                              loc.estimativa > 0
                                  ? '$i. ${loc.nome}: est. ${loc.estimativa} | ${loc.votos} votos (${loc.pct.toStringAsFixed(1)}%)'
                                  : '$i. ${loc.nome}: ${loc.votos} votos (${loc.pct.toStringAsFixed(1)}%)',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          if (ranking.isNotEmpty)
            Positioned(
              right: 8,
              top: 8,
              bottom: 8,
              child: _RankingPanel(ranking: ranking, onCityTap: widget.onCityTap),
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
      ),
    );
  }
}

/// Painel lateral: ranking de regiões; ao clicar expande com cidades (estimativa vs votos TSE); ao tocar na cidade abre locais de votação.
class _RankingPanel extends StatelessWidget {
  const _RankingPanel({
    required this.ranking,
    this.onCityTap,
  });

  final List<({String id, String nome, int total, int totalEstimativa, List<({String cidade, String key, int votos, double pct, int estimativa})> cidades})> ranking;
  final void Function(String nomeMunicipio)? onCityTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 280,
        constraints: const BoxConstraints(maxHeight: 400),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ranking por região (votos)',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (onCityTap != null)
                    Text(
                      'Toque numa cidade para ver locais de votação',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: ranking.length,
                itemBuilder: (context, i) {
                  final r = ranking[i];
                  return ExpansionTile(
                    initiallyExpanded: false,
                    title: Row(
                      children: [
                        Text(
                          '${i + 1}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.nome,
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (r.totalEstimativa > 0)
                          Text(
                            'est. ${r.totalEstimativa} | ',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Text(
                          '${r.total} votos',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    children: [
                      ...r.cidades.map((c) => InkWell(
                            onTap: () => onCityTap?.call(c.key),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 24, right: 12, top: 4, bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.cidade,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.place_outlined, size: 14, color: theme.colorScheme.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    c.estimativa > 0
                                        ? 'est. ${c.estimativa} | ${c.votos} (${c.pct.toStringAsFixed(1)}%)'
                                        : '${c.votos} (${c.pct.toStringAsFixed(1)}%)',
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
