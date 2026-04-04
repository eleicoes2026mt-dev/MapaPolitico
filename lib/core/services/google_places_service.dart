import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../config/env_config.dart';

/// Distância em metros entre dois pontos WGS84.
double _haversineM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final p1 = lat1 * math.pi / 180.0;
  final p2 = lat2 * math.pi / 180.0;
  final dLat = (lat2 - lat1) * math.pi / 180.0;
  final dLng = (lng2 - lng1) * math.pi / 180.0;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Viés geográfico: raio até 50 km (limite da API) para cidades grandes (ex.: Cuiabá).
class GooglePlacesMunicipioContext {
  const GooglePlacesMunicipioContext({
    required this.centerLat,
    required this.centerLng,
    required this.municipioNome,
    this.radiusMeters = 50000,
  });

  final double centerLat;
  final double centerLng;
  final String municipioNome;
  final int radiusMeters;

  int get clampedRadius => radiusMeters.clamp(1500, 50000);

  /// Caixa para Geocoding API (`southwest|northeast`).
  String get geocodeBounds {
    const d = 0.34;
    final swLat = centerLat - d;
    final swLng = centerLng - d;
    final neLat = centerLat + d;
    final neLng = centerLng + d;
    return '$swLat,$swLng|$neLat,$neLng';
  }
}

String _foldPt(String s) {
  var t = s.toLowerCase().trim();
  const map = {
    'á': 'a',
    'à': 'a',
    'ã': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'ê': 'e',
    'í': 'i',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  for (final e in map.entries) {
    t = t.replaceAll(e.key, e.value);
  }
  return t;
}

bool _textoMencionaMunicipio(String texto, String municipioNome) {
  final m = _foldPt(municipioNome);
  if (m.length < 3) return true;
  return _foldPt(texto).contains(m);
}

/// Uma sugestão da API Places (Autocomplete).
class PlacePrediction {
  const PlacePrediction({required this.description, required this.placeId});

  final String description;
  final String placeId;
}

/// Autocomplete de endereços/lugares (Brasil).
/// Com [municipioContext]: [strictBounds]=true aperta demais para termos genéricos ("escola estadual");
/// use false só com filtro extra (ex.: nome da cidade na descrição).
Future<List<PlacePrediction>> fetchGooglePlacePredictions(
  String input, {
  String? sessionToken,
  GooglePlacesMunicipioContext? municipioContext,
  bool strictBounds = true,
}) async {
  final key = EnvConfig.googleMapsApiKey.trim();
  if (key.isEmpty || input.trim().length < 3) return [];

  final q = <String, String>{
    'input': input.trim(),
    'key': key,
    'components': 'country:br',
    'language': 'pt-BR',
  };
  if (sessionToken != null && sessionToken.isNotEmpty) {
    q['sessiontoken'] = sessionToken;
  }
  if (municipioContext != null) {
    q['location'] = '${municipioContext.centerLat},${municipioContext.centerLng}';
    q['radius'] = '${municipioContext.clampedRadius}';
    if (strictBounds) {
      q['strictbounds'] = 'true';
    }
  }

  final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', q);
  try {
    final r = await http.get(uri).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return [];
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final status = j['status'] as String? ?? '';
    if (status != 'OK' && status != 'ZERO_RESULTS') return [];
    final list = j['predictions'] as List<dynamic>? ?? [];
    var out = list
        .map((e) {
          final m = e as Map<String, dynamic>;
          return PlacePrediction(
            description: m['description'] as String? ?? '',
            placeId: m['place_id'] as String? ?? '',
          );
        })
        .where((p) => p.description.isNotEmpty && p.placeId.isNotEmpty)
        .toList();
    // Com location+strictbounds o Autocomplete já fica na região; não filtrar por nome da cidade
    // na descrição (muitas ruas vêm sem o município na primeira linha).
    return out;
  } catch (_) {
    return [];
  }
}

bool _placeInMunicipioArea(Map<String, dynamic> m, GooglePlacesMunicipioContext ctx, double maxDistM) {
  final formatted = m['formatted_address']?.toString() ?? '';
  final vicinity = m['vicinity']?.toString() ?? '';
  final name = m['name']?.toString() ?? '';
  if (_textoMencionaMunicipio('$formatted $vicinity $name', ctx.municipioNome)) {
    return true;
  }
  final loc = (m['geometry'] as Map<String, dynamic>?)?['location'] as Map<String, dynamic>?;
  if (loc == null) return false;
  final lat = (loc['lat'] as num?)?.toDouble();
  final lng = (loc['lng'] as num?)?.toDouble();
  if (lat == null || lng == null) return false;
  return _haversineM(ctx.centerLat, ctx.centerLng, lat, lng) <= maxDistM;
}

PlacePrediction? _placeMapToPrediction(Map<String, dynamic> m) {
  final placeId = m['place_id'] as String? ?? '';
  if (placeId.isEmpty) return null;
  final name = (m['name'] as String?)?.trim() ?? '';
  final formatted = (m['formatted_address'] as String?)?.trim() ?? '';
  final vicinity = (m['vicinity'] as String?)?.trim();
  String desc;
  if (name.isNotEmpty) {
    desc = vicinity != null && vicinity.isNotEmpty ? '$name — $vicinity' : '$name — $formatted';
  } else {
    desc = formatted.isNotEmpty ? formatted : vicinity ?? '';
  }
  if (desc.isEmpty) return null;
  return PlacePrediction(description: desc, placeId: placeId);
}

/// Text Search com viés local (lista parecida com o Maps: nomes de estabelecimentos).
Future<List<PlacePrediction>> fetchGooglePlaceTextSearchInMunicipio(
  String query,
  GooglePlacesMunicipioContext ctx, {
  double? maxDistanceMeters,
}) async {
  final key = EnvConfig.googleMapsApiKey.trim();
  if (key.isEmpty || query.trim().length < 2) return [];

  final maxD = maxDistanceMeters ?? (ctx.clampedRadius * 1.35).toDouble();

  final uri = Uri.https('maps.googleapis.com', '/maps/api/place/textsearch/json', {
    'query': query.trim(),
    'location': '${ctx.centerLat},${ctx.centerLng}',
    'radius': '${ctx.clampedRadius}',
    'key': key,
    'language': 'pt-BR',
  });
  try {
    final r = await http.get(uri).timeout(const Duration(seconds: 14));
    if (r.statusCode != 200) return [];
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final status = j['status'] as String? ?? '';
    if (status != 'OK' && status != 'ZERO_RESULTS') return [];
    final list = j['results'] as List<dynamic>? ?? [];
    final out = <PlacePrediction>[];
    for (final e in list.take(15)) {
      final m = e as Map<String, dynamic>;
      if (!_placeInMunicipioArea(m, ctx, maxD)) continue;
      final p = _placeMapToPrediction(m);
      if (p != null) out.add(p);
    }
    return out;
  } catch (_) {
    return [];
  }
}

/// Nearby Search por palavra-chave (escolas, comércios, etc.) perto do centro do município.
Future<List<PlacePrediction>> fetchGooglePlaceNearbyKeyword(
  String keyword,
  GooglePlacesMunicipioContext ctx, {
  double? maxDistanceMeters,
}) async {
  final key = EnvConfig.googleMapsApiKey.trim();
  if (key.isEmpty || keyword.trim().length < 2) return [];

  final maxD = maxDistanceMeters ?? (ctx.clampedRadius * 1.35).toDouble();

  final uri = Uri.https('maps.googleapis.com', '/maps/api/place/nearbysearch/json', {
    'location': '${ctx.centerLat},${ctx.centerLng}',
    'radius': '${ctx.clampedRadius}',
    'keyword': keyword.trim(),
    'key': key,
    'language': 'pt-BR',
  });
  try {
    final r = await http.get(uri).timeout(const Duration(seconds: 14));
    if (r.statusCode != 200) return [];
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final status = j['status'] as String? ?? '';
    if (status != 'OK' && status != 'ZERO_RESULTS') return [];
    final list = j['results'] as List<dynamic>? ?? [];
    final out = <PlacePrediction>[];
    for (final e in list.take(15)) {
      final m = e as Map<String, dynamic>;
      if (!_placeInMunicipioArea(m, ctx, maxD)) continue;
      final p = _placeMapToPrediction(m);
      if (p != null) out.add(p);
    }
    return out;
  } catch (_) {
    return [];
  }
}

/// Combina Nearby + Text Search + Autocomplete (como o app do Google Maps para termos genéricos).
Future<List<PlacePrediction>> fetchGooglePlacesAgendaPickerResults(
  String input,
  GooglePlacesMunicipioContext ctx, {
  String? sessionToken,
}) async {
  final raw = input.trim();
  if (raw.length < 3) return [];

  final maxD = (ctx.clampedRadius * 1.38).toDouble();
  final qComCidade = '$raw ${ctx.municipioNome}, MT';
  final qEmCidade = '$raw em ${ctx.municipioNome}';

  final acPair = await Future.wait([
    fetchGooglePlacePredictions(
      raw,
      sessionToken: sessionToken,
      municipioContext: ctx,
      strictBounds: true,
    ),
    fetchGooglePlacePredictions(
      raw,
      sessionToken: sessionToken,
      municipioContext: ctx,
      strictBounds: false,
    ),
  ]);
  final acStrict = acPair[0];
  final softFiltrado = acPair[1]
      .where((p) => _textoMencionaMunicipio(p.description, ctx.municipioNome))
      .toList();

  final poiBatch = await Future.wait([
    fetchGooglePlaceNearbyKeyword(raw, ctx, maxDistanceMeters: maxD),
    fetchGooglePlaceTextSearchInMunicipio(qComCidade, ctx, maxDistanceMeters: maxD),
    fetchGooglePlaceTextSearchInMunicipio(qEmCidade, ctx, maxDistanceMeters: maxD),
  ]);
  final nearby = poiBatch[0];
  final ts1 = poiBatch[1];
  final ts2 = poiBatch[2];

  final seen = <String>{};
  final merged = <PlacePrediction>[];

  void addList(List<PlacePrediction> list) {
    for (final p in list) {
      if (p.placeId.isEmpty || seen.contains(p.placeId)) continue;
      seen.add(p.placeId);
      merged.add(p);
    }
  }

  // POIs com nome primeiro (Nearby + Text), depois Autocomplete.
  addList(nearby);
  addList(ts1);
  addList(ts2);
  addList(acStrict);
  addList(softFiltrado);

  return merged.take(14).toList();
}

/// Endereço formatado a partir do [placeId] (opcional, para refinar o texto salvo).
Future<String?> fetchGooglePlaceFormattedAddress(String placeId) async {
  final d = await fetchGooglePlaceDetailsLatLng(placeId);
  return d?.formattedAddress;
}

/// Detalhes do lugar com coordenadas (para mapa / confirmação).
class PlaceDetailsLatLng {
  const PlaceDetailsLatLng({
    required this.lat,
    required this.lng,
    this.formattedAddress,
    this.name,
  });

  final double lat;
  final double lng;
  final String? formattedAddress;
  final String? name;

  /// Nome do estabelecimento/POI quando existir; senão endereço formatado.
  String get primaryLabel {
    final n = name?.trim();
    if (n != null && n.isNotEmpty) return n;
    final f = formattedAddress?.trim();
    if (f != null && f.isNotEmpty) return f;
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }
}

/// Resultado da API Geocoding (endereço livre).
class GeocodeHit {
  const GeocodeHit({
    required this.lat,
    required this.lng,
    required this.formattedAddress,
    required this.displayLabel,
  });

  final double lat;
  final double lng;
  final String formattedAddress;
  final String displayLabel;
}

String _geocodeDisplayLabel(Map<String, dynamic> m) {
  final formatted = (m['formatted_address'] as String?)?.trim() ?? '';
  String? poiName;
  for (final c in (m['address_components'] as List<dynamic>? ?? [])) {
    final map = c as Map<String, dynamic>;
    final types = List<String>.from(map['types'] as List<dynamic>? ?? []);
    final ln = (map['long_name'] as String?)?.trim() ?? '';
    if (ln.isEmpty) continue;
    if (types.contains('establishment') ||
        types.contains('point_of_interest') ||
        types.contains('university') ||
        types.contains('school')) {
      poiName = ln;
      break;
    }
  }
  if (poiName != null && poiName.isNotEmpty) {
    return '$poiName — $formatted';
  }
  return formatted;
}

bool _geocodeHitInMunicipio(Map<String, dynamic> m, String municipioNome) {
  if (_textoMencionaMunicipio(m['formatted_address']?.toString() ?? '', municipioNome)) {
    return true;
  }
  for (final c in (m['address_components'] as List<dynamic>? ?? [])) {
    final map = c as Map<String, dynamic>;
    final types = List<String>.from(map['types'] as List<dynamic>? ?? []);
    if (!types.contains('locality') &&
        !types.contains('administrative_area_level_2') &&
        !types.contains('administrative_area_level_3')) {
      continue;
    }
    final ln = map['long_name']?.toString() ?? '';
    if (_textoMencionaMunicipio(ln, municipioNome) || _textoMencionaMunicipio(municipioNome, ln)) {
      return true;
    }
  }
  return false;
}

/// Geocodificação direita, com opção de bounds + filtro pelo município.
Future<List<GeocodeHit>> fetchGoogleGeocodeForward(
  String address, {
  String? bounds,
  GooglePlacesMunicipioContext? municipioContext,
}) async {
  final key = EnvConfig.googleMapsApiKey.trim();
  if (key.isEmpty || address.trim().length < 2) return [];

  final q = <String, String>{
    'address': address.trim(),
    'key': key,
    'components': 'country:BR',
    'language': 'pt-BR',
  };
  if (bounds != null && bounds.isNotEmpty) {
    q['bounds'] = bounds;
  }

  final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', q);
  try {
    final r = await http.get(uri).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return [];
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if ((j['status'] as String?) != 'OK') return [];
    final results = j['results'] as List<dynamic>? ?? [];
    final out = <GeocodeHit>[];
    for (final e in results.take(8)) {
      final m = e as Map<String, dynamic>;
      if (municipioContext != null && !_geocodeHitInMunicipio(m, municipioContext.municipioNome)) {
        continue;
      }
      final loc = (m['geometry'] as Map<String, dynamic>?)?['location'] as Map<String, dynamic>?;
      final lat = (loc?['lat'] as num?)?.toDouble();
      final lng = (loc?['lng'] as num?)?.toDouble();
      final addr = (m['formatted_address'] as String?)?.trim() ?? '';
      if (lat == null || lng == null || addr.isEmpty) continue;
      out.add(GeocodeHit(
        lat: lat,
        lng: lng,
        formattedAddress: addr,
        displayLabel: _geocodeDisplayLabel(m),
      ));
    }
    return out;
  } catch (_) {
    return [];
  }
}

Future<PlaceDetailsLatLng?> fetchGooglePlaceDetailsLatLng(String placeId) async {
  final key = EnvConfig.googleMapsApiKey.trim();
  if (key.isEmpty || placeId.isEmpty) return null;
  final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
    'place_id': placeId,
    'fields': 'name,formatted_address,geometry',
    'key': key,
    'language': 'pt-BR',
  });
  try {
    final r = await http.get(uri).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    if ((j['status'] as String?) != 'OK') return null;
    final res = j['result'] as Map<String, dynamic>?;
    if (res == null) return null;
    final geom = res['geometry'] as Map<String, dynamic>?;
    final loc = geom?['location'] as Map<String, dynamic>?;
    final lat = (loc?['lat'] as num?)?.toDouble();
    final lng = (loc?['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    final addr = res['formatted_address'] as String?;
    final name = res['name'] as String?;
    return PlaceDetailsLatLng(
      lat: lat,
      lng: lng,
      formattedAddress: addr?.trim().isNotEmpty == true ? addr!.trim() : null,
      name: name?.trim().isNotEmpty == true ? name!.trim() : null,
    );
  } catch (_) {
    return null;
  }
}
