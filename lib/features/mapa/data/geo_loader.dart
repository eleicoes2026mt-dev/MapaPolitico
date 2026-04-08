import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../../core/geo/lat_lng.dart';

/// Um polígono para desenhar no mapa (anel exterior; furos opcionais).
class GeoPolygon {
  const GeoPolygon({
    required this.points,
    this.holes = const [],
  });
  final List<LatLng> points;
  final List<List<LatLng>> holes;
}

/// Verifica se o ponto está dentro do polígono (ray-casting). Considera apenas o anel exterior.
bool pointInPolygon(LatLng point, GeoPolygon polygon) {
  final pts = polygon.points;
  if (pts.length < 3) return false;
  final px = point.longitude;
  final py = point.latitude;
  var crossings = 0;
  for (var i = 0; i < pts.length; i++) {
    final p0 = pts[i];
    final p1 = pts[(i + 1) % pts.length];
    if ((p0.latitude > py) == (p1.latitude > py)) continue;
    final x = p0.longitude + (py - p0.latitude) / (p1.latitude - p0.latitude) * (p1.longitude - p0.longitude);
    if (x > px) crossings++;
  }
  return crossings.isOdd;
}

/// Retorna true se o ponto está dentro de algum dos polígonos da região.
bool pointInRegion(LatLng point, List<GeoPolygon> polygons) {
  for (final poly in polygons) {
    if (pointInPolygon(point, poly)) return true;
  }
  return false;
}

/// Área aproximada do anel exterior (|graus²|) — só para comparar fragmentos de um MultiPolygon.
double geoPolygonExteriorAreaSq(GeoPolygon g) {
  return _ringAreaAbs(g.points);
}

double _ringAreaAbs(List<LatLng> ring) {
  if (ring.length < 3) return 0;
  var s = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final j = (i + 1) % ring.length;
    s += ring[i].longitude * ring[j].latitude - ring[j].longitude * ring[i].latitude;
  }
  return (s * 0.5).abs();
}

/// Índice do maior polígono numa região (MultiPolygon). Usar para desenhar **contorno só nessa parte**,
/// evitando linhas internas entre fragmentos da mesma região no mapa.
int indexOfLargestGeoPolygon(List<GeoPolygon> polygons) {
  if (polygons.isEmpty) return -1;
  var bestI = 0;
  var bestA = geoPolygonExteriorAreaSq(polygons[0]);
  for (var i = 1; i < polygons.length; i++) {
    final a = geoPolygonExteriorAreaSq(polygons[i]);
    if (a > bestA) {
      bestA = a;
      bestI = i;
    }
  }
  return bestI;
}

/// Região com nome (ex.: estado "Mato Grosso") e um ou mais polígonos.
class GeoRegion {
  const GeoRegion({this.name, required this.polygons});
  final String? name;
  final List<GeoPolygon> polygons;
}

/// Converte coordenadas GeoJSON [lng, lat] em LatLng(lat, lng).
List<LatLng> _ringToLatLngs(List<dynamic> ring) {
  return ring.map<LatLng>((e) {
    final list = e as List<dynamic>;
    final lng = (list[0] as num).toDouble();
    final lat = (list[1] as num).toDouble();
    return LatLng(lat, lng);
  }).toList();
}

/// Parse de uma geometry GeoJSON (Polygon ou MultiPolygon) em lista de GeoPolygon.
List<GeoPolygon> _parseGeometry(Map<String, dynamic> geometry) {
  final type = geometry['type'] as String?;
  final coords = geometry['coordinates'];
  if (coords == null) return [];

  if (type == 'Polygon') {
    final rings = coords as List<dynamic>;
    if (rings.isEmpty) return [];
    final exterior = _ringToLatLngs(rings[0] as List<dynamic>);
    final holes = rings.length > 1
        ? rings.skip(1).map((r) => _ringToLatLngs(r as List<dynamic>)).toList()
        : <List<LatLng>>[];
    return [GeoPolygon(points: exterior, holes: holes)];
  }

  if (type == 'MultiPolygon') {
    final multi = coords as List<dynamic>;
    final result = <GeoPolygon>[];
    for (final part in multi) {
      final rings = part as List<dynamic>;
      if (rings.isEmpty) continue;
      final exterior = _ringToLatLngs(rings[0] as List<dynamic>);
      final holes = rings.length > 1
          ? rings
              .skip(1)
              .map((r) => _ringToLatLngs(r as List<dynamic>))
              .toList()
          : <List<LatLng>>[];
      result.add(GeoPolygon(points: exterior, holes: holes));
    }
    return result;
  }

  return [];
}

/// Carrega um GeoJSON (FeatureCollection) do asset e retorna lista de [GeoRegion].
Future<List<GeoRegion>> loadGeoJsonFromAsset(String assetPath) async {
  final data = await rootBundle.loadString(assetPath);
  final map = jsonDecode(data) as Map<String, dynamic>;
  final type = map['type'] as String?;
  if (type != 'FeatureCollection') return [];

  final features = map['features'] as List<dynamic>? ?? [];
  final regions = <GeoRegion>[];

  for (final f in features) {
    final feature = f as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final properties = feature['properties'] as Map<String, dynamic>?;
    final name = properties?['name'] as String?;

    if (geometry == null) continue;
    final polygons = _parseGeometry(geometry);
    if (polygons.isEmpty) continue;

    regions.add(GeoRegion(name: name, polygons: polygons));
  }

  return regions;
}

/// Região de MT (IBGE): id, nome, polígonos e opcionalmente cdRgint (região intermediária para cor).
class RegiaoIntermediariaMT {
  const RegiaoIntermediariaMT({
    required this.id,
    required this.nome,
    required this.polygons,
    this.cdRgint,
  });
  final String id;
  final String nome;
  final List<GeoPolygon> polygons;

  /// Código da região intermediária (ex.: 5101) para colorir por polo.
  final String? cdRgint;
}

/// Formato transferível entre isolates: lista de mapas com id, nome, polygons.
/// polygons: [ { 'points': [[lat,lng],...], 'holes': [ [[lat,lng],...], ... ] }, ... ]
List<Map<String, dynamic>> _parseRegioesMTInIsolate(String data) {
  final map = jsonDecode(data) as Map<String, dynamic>;
  final type = map['type'] as String?;
  if (type != 'FeatureCollection') return [];

  final features = map['features'] as List<dynamic>? ?? [];
  final result = <Map<String, dynamic>>[];

  for (final f in features) {
    final feature = f as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final properties = feature['properties'] as Map<String, dynamic>?;
    if (geometry == null || properties == null) continue;

    final id = properties['CD_RGINT']?.toString() ?? 'unknown';
    final nome = properties['NM_RGINT'] as String? ??
        properties['name'] as String? ??
        'Região $id';
    final polygons = _parseGeometryToTransferable(geometry);
    if (polygons.isEmpty) continue;

    result.add({'id': id, 'nome': nome, 'polygons': polygons});
  }

  return result;
}

/// Mantém até [maxPoints] pontos por anel para contornos mais suaves (150 = linhas menos tortas).
List<List<double>> _simplifyRing(List<List<double>> ring,
    {int maxPoints = 150}) {
  if (ring.length <= maxPoints) return ring;
  final step = (ring.length / maxPoints).ceil().clamp(2, 5);
  final out = <List<double>>[];
  for (var i = 0; i < ring.length; i += step) out.add(ring[i]);
  if (ring.length > 1 && out.last != ring.last) out.add(ring.last);
  return out;
}

/// Converte geometry para lista de mapas { points: [[lat,lng],...], holes: [...] } (transferível).
List<Map<String, dynamic>> _parseGeometryToTransferable(
    Map<String, dynamic> geometry) {
  final type = geometry['type'] as String?;
  final coords = geometry['coordinates'];
  if (coords == null) return [];

  List<Map<String, dynamic>> toPolygon(dynamic rings) {
    final r = rings as List<dynamic>;
    if (r.isEmpty) return [];
    List<List<double>> toPoints(List<dynamic> list) {
      final pts = list.map<List<double>>((e) {
        final l = e as List<dynamic>;
        final lng = (l[0] as num).toDouble();
        final lat = (l[1] as num).toDouble();
        return [lat, lng];
      }).toList();
      return _simplifyRing(pts);
    }

    final exterior = toPoints(r[0] as List<dynamic>);
    final holes = r.length > 1
        ? (r
            .skip(1)
            .map<List<List<double>>>((ring) => toPoints(ring as List<dynamic>))
            .toList())
        : <List<List<double>>>[];
    return [
      {'points': exterior, 'holes': holes}
    ];
  }

  if (type == 'Polygon') return toPolygon(coords);
  if (type == 'MultiPolygon') {
    final multi = coords as List<dynamic>;
    final out = <Map<String, dynamic>>[];
    for (final part in multi) {
      out.addAll(toPolygon(part));
    }
    return out;
  }
  return [];
}

/// Formato transferível para regiões imediatas (CD_RGI, NM_RGI, CD_RGINT).
List<Map<String, dynamic>> _parseRegioesImediatasMTInIsolate(String data) {
  final map = jsonDecode(data) as Map<String, dynamic>;
  final type = map['type'] as String?;
  if (type != 'FeatureCollection') return [];

  final features = map['features'] as List<dynamic>? ?? [];
  final result = <Map<String, dynamic>>[];

  for (final f in features) {
    final feature = f as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final properties = feature['properties'] as Map<String, dynamic>?;
    if (geometry == null || properties == null) continue;

    final id = properties['CD_RGI']?.toString() ?? 'unknown';
    final nome = properties['NM_RGI'] as String? ??
        properties['name'] as String? ??
        'Região $id';
    final cdRgint = properties['CD_RGINT']?.toString();
    final polygons = _parseGeometryToTransferable(geometry);
    if (polygons.isEmpty) continue;

    result.add(
        {'id': id, 'nome': nome, 'cdRgint': cdRgint, 'polygons': polygons});
  }

  return result;
}

/// Formato transferível para delimitação dos estados (properties.id, properties.name).
/// Usado como fonte que prevalece no mapa (assets/geo/delimitacao_estados.json).
List<Map<String, dynamic>> _parseDelimitacaoEstadosInIsolate(String data) {
  final map = jsonDecode(data) as Map<String, dynamic>;
  final type = map['type'] as String?;
  if (type != 'FeatureCollection') return [];

  final features = map['features'] as List<dynamic>? ?? [];
  final result = <Map<String, dynamic>>[];

  for (final f in features) {
    final feature = f as Map<String, dynamic>;
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final properties = feature['properties'] as Map<String, dynamic>?;
    if (geometry == null || properties == null) continue;

    final id = properties['id']?.toString() ?? 'unknown';
    final nome = properties['name'] as String? ?? 'Região $id';
    final polygons = _parseGeometryToTransferable(geometry);
    if (polygons.isEmpty) continue;

    result.add({'id': id, 'nome': nome, 'cdRgint': null, 'polygons': polygons});
  }

  return result;
}

List<RegiaoIntermediariaMT> _rawToRegioesMT(List<Map<String, dynamic>> raw) {
  return raw.map<RegiaoIntermediariaMT>((m) {
    final polygons = (m['polygons'] as List<dynamic>).map<GeoPolygon>((p) {
      final pts = (p['points'] as List<dynamic>).map<LatLng>((e) {
        final l = e as List<dynamic>;
        return LatLng((l[0] as num).toDouble(), (l[1] as num).toDouble());
      }).toList();
      final holes = (p['holes'] as List<dynamic>).map<List<LatLng>>((h) {
        return (h as List<dynamic>).map<LatLng>((e) {
          final l = e as List<dynamic>;
          return LatLng((l[0] as num).toDouble(), (l[1] as num).toDouble());
        }).toList();
      }).toList();
      return GeoPolygon(points: pts, holes: holes);
    }).toList();
    return RegiaoIntermediariaMT(
      id: m['id'] as String,
      nome: m['nome'] as String,
      polygons: polygons,
      cdRgint: m['cdRgint'] as String?,
    );
  }).toList();
}

/// Carrega GeoJSON de regiões intermediárias de MT em isolate (evita travar a UI).
Future<List<RegiaoIntermediariaMT>> loadRegioesMTFromAsset(
    String assetPath) async {
  final data = await rootBundle.loadString(assetPath);
  final raw = await compute(_parseRegioesMTInIsolate, data);
  return _rawToRegioesMT(raw);
}

/// Carrega GeoJSON de regiões imediatas de MT (CD_RGI, NM_RGI, CD_RGINT) em isolate.
Future<List<RegiaoIntermediariaMT>> loadRegioesImediatasMTFromAsset(
    String assetPath) async {
  final data = await rootBundle.loadString(assetPath);
  final raw = await compute(_parseRegioesImediatasMTInIsolate, data);
  return _rawToRegioesMT(raw);
}

/// Asset da delimitação dos estados (fonte que prevalece no mapa).
const String kDelimitacaoEstadosAsset = 'assets/geo/delimitacao_estados.json';

/// Regiões imediatas de MT (IBGE 2024). Fonte que prevalece para as delimitações dentro de MT.
const String kMTRegioesImediatas2024Asset =
    'assets/geo/mt_regioes_imediatas_2024.geojson';

/// Regiões intermediárias de MT (5 polos: Cuiabá, Cáceres, Sinop, Barra do Garças, Rondonópolis).
/// Usado no ranking do mapa web para agrupar cidades por polo.
const String kMTRegioesIntermediariasAsset =
    'assets/geo/mt_regioes_intermediarias.geojson';

/// Carrega GeoJSON de delimitação dos estados em isolate. Retorna regiões com id/nome por estado.
/// Esta é a fonte que prevalece para desenhar os polígonos do mapa.
Future<List<RegiaoIntermediariaMT>> loadDelimitacaoEstadosFromAsset() async {
  final data = await rootBundle.loadString(kDelimitacaoEstadosAsset);
  final raw = await compute(_parseDelimitacaoEstadosInIsolate, data);
  return _rawToRegioesMT(raw);
}
