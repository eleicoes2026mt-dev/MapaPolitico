import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Um polígono para desenhar no mapa (anel exterior; furos opcionais).
class GeoPolygon {
  const GeoPolygon({
    required this.points,
    this.holes = const [],
  });
  final List<LatLng> points;
  final List<List<LatLng>> holes;
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
          ? rings.skip(1).map((r) => _ringToLatLngs(r as List<dynamic>)).toList()
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
    final nome = properties['NM_RGINT'] as String? ?? properties['name'] as String? ?? 'Região $id';
    final polygons = _parseGeometryToTransferable(geometry);
    if (polygons.isEmpty) continue;

    result.add({'id': id, 'nome': nome, 'polygons': polygons});
  }

  return result;
}

/// Converte geometry para lista de mapas { points: [[lat,lng],...], holes: [...] } (transferível).
List<Map<String, dynamic>> _parseGeometryToTransferable(Map<String, dynamic> geometry) {
  final type = geometry['type'] as String?;
  final coords = geometry['coordinates'];
  if (coords == null) return [];

  List<Map<String, dynamic>> toPolygon(dynamic rings) {
    final r = rings as List<dynamic>;
    if (r.isEmpty) return [];
    final exterior = (r[0] as List<dynamic>).map<List<double>>((e) {
      final list = e as List<dynamic>;
      final lng = (list[0] as num).toDouble();
      final lat = (list[1] as num).toDouble();
      return [lat, lng];
    }).toList();
    final holes = r.length > 1
        ? (r.skip(1).map<List<List<double>>>((ring) => (ring as List<dynamic>).map<List<double>>((e) {
              final list = e as List<dynamic>;
              final lng = (list[0] as num).toDouble();
              final lat = (list[1] as num).toDouble();
              return [lat, lng];
            }).toList()).toList())
        : <List<List<double>>>[];
    return [{'points': exterior, 'holes': holes}];
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
    final nome = properties['NM_RGI'] as String? ?? properties['name'] as String? ?? 'Região $id';
    final cdRgint = properties['CD_RGINT']?.toString();
    final polygons = _parseGeometryToTransferable(geometry);
    if (polygons.isEmpty) continue;

    result.add({'id': id, 'nome': nome, 'cdRgint': cdRgint, 'polygons': polygons});
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
Future<List<RegiaoIntermediariaMT>> loadRegioesMTFromAsset(String assetPath) async {
  final data = await rootBundle.loadString(assetPath);
  final raw = await compute(_parseRegioesMTInIsolate, data);
  return _rawToRegioesMT(raw);
}

/// Carrega GeoJSON de regiões imediatas de MT (CD_RGI, NM_RGI, CD_RGINT) em isolate.
Future<List<RegiaoIntermediariaMT>> loadRegioesImediatasMTFromAsset(String assetPath) async {
  final data = await rootBundle.loadString(assetPath);
  final raw = await compute(_parseRegioesImediatasMTInIsolate, data);
  return _rawToRegioesMT(raw);
}
