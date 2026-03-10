import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/regioes_fundidas.dart';
import '../../data/geo_loader.dart';
import '../../data/mt_municipios_coords.dart';

const _prefsKeyRegionNames = 'mapa_regioes_nomes';

/// Centro de Mato Grosso (Cuiabá)
const mtCenterLatLng = LatLng(-15.6014, -56.0979);

/// Coordenadas das cidades-sede das regiões intermediárias de MT (marcadores no mapa).
const polosMT = [
  ('Cuiabá', LatLng(-15.6014, -56.0979)),
  ('Rondonópolis', LatLng(-16.4677, -54.6362)),
  ('Sinop', LatLng(-11.8642, -55.5094)),
  ('Barra do Garças', LatLng(-15.8896, -52.2569)),
  ('Tangará da Serra', LatLng(-14.6229, -57.4933)),
];

/// Nome do estado do candidato (para destacar no mapa).
const nomeEstadoCandidato = 'Mato Grosso';

/// Widget reutilizável: mapa Google com demarcação Brasil/estados, cidades e votos TSE por município.
class MapaRegionalWidget extends StatefulWidget {
  const MapaRegionalWidget({
    super.key,
    this.height = 400,
    this.votosPorMunicipio,
    this.regioesFundidas,
    /// Nomes editados pelo usuário (por cdRgint); quando definido, prevalece em todo o app.
    this.nomesCustomizados,
    /// Salva nome da região (cdRgint) para persistir em todo o app.
    this.onSaveNomeRegiao,
    /// Se retornar true, o diálogo de editar nome não será aberto (ex.: Ctrl+clique para seleção).
    this.onRegionTap,
  });

  final double height;
  final Map<String, int>? votosPorMunicipio;
  final List<RegiaoFundida>? regioesFundidas;
  final Map<String, String>? nomesCustomizados;
  final void Function(String cdRgint, String nome)? onSaveNomeRegiao;
  final bool Function(String id, String nome, String? cdRgint)? onRegionTap;

  @override
  State<MapaRegionalWidget> createState() => _MapaRegionalWidgetState();
}

class _MapaRegionalWidgetState extends State<MapaRegionalWidget> {
  final Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  bool _geoLoaded = false;
  GoogleMapController? _mapController;
  List<RegiaoIntermediariaMT>? _regioesMTList;
  String? _hoveredRegionId;
  String? _hoveredRegionName;
  Offset? _hoverPosition;
  Map<String, String> _customRegionNames = {};

  /// Point-in-polygon (ray casting) para um anel (exterior ou hole).
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

  String _displayName(String id, String originalNome) =>
      _customRegionNames[id] ?? originalNome;

  String _nomeParaTooltip(String id, String originalNome, String? cdRgint) {
    final fundidas = widget.regioesFundidas;
    final nomes = widget.nomesCustomizados;
    if (cdRgint != null) {
      return nomeRegiaoPorCdRgint(
        cdRgint,
        fundidas ?? [],
        nomesCustomizados: nomes,
      );
    }
    return nomes != null ? originalNome : _displayName(id, originalNome);
  }

  /// Marcadores das cidades-sede + cidades com votos TSE (quando votosPorMunicipio fornecido).
  Set<Marker> get _allMarkers {
    final set = Set<Marker>.from(_markers);
    final votos = widget.votosPorMunicipio;
    if (votos == null || votos.isEmpty) return set;
    var i = 0;
    for (final e in votos.entries) {
      final coords = getCoordsMunicipioMT(e.key);
      if (coords != null) {
        set.add(
          Marker(
            markerId: MarkerId('tse_${e.key}_$i'),
            position: coords,
            infoWindow: InfoWindow(
              title: e.key,
              snippet: '${e.value} votos',
            ),
          ),
        );
        i++;
      }
    }
    return set;
  }

  Future<void> _loadCustomNames() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKeyRegionNames);
    if (json == null) return;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>?;
      if (map != null && mounted) {
        setState(() => _customRegionNames = map.map((k, v) => MapEntry(k, v as String)));
      }
    } catch (_) {}
  }

  Future<void> _saveCustomNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyRegionNames, jsonEncode(_customRegionNames));
  }

  String _currentDisplayNameForEdit(String regionId, String nomeOriginal, String? cdRgint) {
    if (cdRgint != null) {
      return nomeRegiaoPorCdRgint(
        cdRgint,
        widget.regioesFundidas ?? [],
        nomesCustomizados: widget.nomesCustomizados,
      );
    }
    return _displayName(regionId, nomeOriginal);
  }

  Future<void> _showEditRegionNameDialog(
    BuildContext context,
    String regionId,
    String nomeOriginal,
    String? cdRgint,
  ) async {
    final currentName = _currentDisplayNameForEdit(regionId, nomeOriginal, cdRgint);
    final controller = TextEditingController(text: currentName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar nome da região'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nome da região',
            hintText: 'Ex.: Juína, Cuiabá',
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          onSubmitted: (_) => Navigator.of(ctx).pop(true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    final nome = controller.text.trim();
    if (nome.isEmpty) return;
    if (widget.onSaveNomeRegiao != null && cdRgint != null) {
      widget.onSaveNomeRegiao!(cdRgint, nome);
    } else {
      setState(() => _customRegionNames[regionId] = nome);
      await _saveCustomNames();
    }
  }

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < polosMT.length; i++) {
      final p = polosMT[i];
      _markers.add(
        Marker(
          markerId: MarkerId('polo_$i'),
          position: p.$2,
          infoWindow: InfoWindow(title: p.$1),
        ),
      );
    }
    _loadGeo();
    if (widget.onSaveNomeRegiao == null) _loadCustomNames();
  }

  static Color _getColorForRegiao(String id) {
    switch (id) {
      case '5101':
        return Colors.blue; // Cuiabá
      case '5102':
        return Colors.green; // Cáceres
      case '5103':
        return Colors.orange; // Sinop
      case '5104':
        return Colors.purple; // Barra do Garças
      case '5105':
        return Colors.red; // Rondonópolis
      default:
        return Colors.grey;
    }
  }

  Future<void> _loadGeo() async {
    final estados = await loadGeoJsonFromAsset('assets/geo/estados.json');
    final brasil = await loadGeoJsonFromAsset('assets/geo/brasil.json');
    final regioesMT = await loadRegioesImediatasMTFromAsset('assets/geo/mt_regioes_imediatas.geojson');

    if (!mounted) return;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final outline = theme.colorScheme.outline;

    final Set<Polygon> result = {};
    int id = 0;

    // Brasil: contorno com traço, preenchimento bem suave
    for (final region in brasil) {
      for (final geo in region.polygons) {
        if (geo.points.length < 2) continue;
        result.add(
          Polygon(
            polygonId: PolygonId('br_$id'),
            points: geo.points,
            fillColor: Colors.grey.withValues(alpha: 0.06),
            strokeColor: outline.withValues(alpha: 0.5),
            strokeWidth: 1,
            consumeTapEvents: false,
          ),
        );
        id++;
      }
    }

    // Estados: MT em destaque (cor primária), demais em cinza suave
    for (final region in estados) {
      final isMT = region.name == nomeEstadoCandidato;
      final fillColor = isMT ? primary.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.08);
      final strokeColor = isMT ? primary.withValues(alpha: 0.85) : outline.withValues(alpha: 0.4);
      final strokeWidth = isMT ? 2.0 : 1.0;

      for (final geo in region.polygons) {
        if (geo.points.length < 2) continue;
        result.add(
          Polygon(
            polygonId: PolygonId('est_$id'),
            points: geo.points,
            holes: geo.holes,
            fillColor: fillColor,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth.round(),
            consumeTapEvents: false,
          ),
        );
        id++;
      }
    }

    // Regiões imediatas de MT: cor pela região intermediária (cdRgint), onTap (editar nome) e hover
    for (final regiao in regioesMT) {
      final color = _getColorForRegiao(regiao.cdRgint ?? regiao.id);
      final regionId = regiao.id;
      final nomeOriginal = regiao.nome;
      for (final geo in regiao.polygons) {
        if (geo.points.length < 2) continue;
        result.add(
          Polygon(
            polygonId: PolygonId('rg_${regiao.id}_$id'),
            points: geo.points,
            holes: geo.holes,
            fillColor: color.withValues(alpha: 0.15),
            strokeColor: color,
            strokeWidth: 2,
            consumeTapEvents: true,
            onTap: () {
              if (!mounted) return;
              if (widget.onRegionTap != null && widget.onRegionTap!(regionId, nomeOriginal, regiao.cdRgint)) return;
              _showEditRegionNameDialog(context, regionId, nomeOriginal, regiao.cdRgint);
            },
          ),
        );
        id++;
      }
    }

    setState(() {
      _polygons = result;
      _regioesMTList = regioesMT;
      _geoLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: MouseRegion(
        onHover: (e) async {
          if (_mapController == null || !_geoLoaded) return;
          final x = e.localPosition.dx.round();
          final y = e.localPosition.dy.round();
          try {
            final latLng = await _mapController!.getLatLng(ScreenCoordinate(x: x, y: y));
            if (!mounted) return;
            final found = _findRegionAt(latLng);
            setState(() {
              if (found != null) {
                _hoveredRegionId = found.$1;
                _hoveredRegionName = _nomeParaTooltip(found.$1, found.$2, found.$3);
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
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: mtCenterLatLng,
                zoom: 6.2,
              ),
              markers: _allMarkers,
              polygons: _polygons,
              onMapCreated: (c) => setState(() => _mapController = c),
              mapType: MapType.normal,
              zoomControlsEnabled: true,
              myLocationButtonEnabled: false,
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
