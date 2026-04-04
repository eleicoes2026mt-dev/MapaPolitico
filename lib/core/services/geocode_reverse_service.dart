import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/env_config.dart';

/// Rótulo legível (endereço) a partir de latitude/longitude.
/// Tenta Google Geocoding se houver chave; senão Nominatim (OSM).
Future<String?> reverseGeocodeLabel(double lat, double lng) async {
  final key = EnvConfig.googleMapsApiKey.trim();
  if (key.isNotEmpty) {
    try {
      final u = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '$lat,$lng',
        'key': key,
        'language': 'pt-BR',
      });
      final r = await http.get(u).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if ((j['status'] as String?) != 'OK') return null;
      final results = j['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      return first['formatted_address'] as String?;
    } catch (_) {}
  }

  try {
    final u = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'json',
      'lat': '$lat',
      'lon': '$lng',
      'accept-language': 'pt-BR',
    });
    final r = await http
        .get(
          u,
          headers: {'User-Agent': 'CampanhaMT/1.0 (agenda visitas)'},
        )
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final name = j['display_name'] as String?;
    return name?.trim().isNotEmpty == true ? name!.trim() : null;
  } catch (_) {
    return null;
  }
}

/// Resultado de busca direta (Nominatim — sem chave Google).
class NominatimSearchHit {
  const NominatimSearchHit({
    required this.lat,
    required this.lng,
    required this.displayName,
  });

  final double lat;
  final double lng;
  final String displayName;
}

/// Busca de endereços/lugares (Brasil). Usado no mapa quando não há Places.
Future<List<NominatimSearchHit>> nominatimSearchPlaces(String query) async {
  final q = query.trim();
  if (q.length < 3) return [];

  try {
    final u = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'json',
      'q': q,
      'limit': '8',
      'countrycodes': 'br',
      'accept-language': 'pt-BR',
    });
    final r = await http
        .get(
          u,
          headers: {'User-Agent': 'CampanhaMT/1.0 (agenda mapa)'},
        )
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return [];
    final list = jsonDecode(r.body) as List<dynamic>;
    final out = <NominatimSearchHit>[];
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final lat = double.tryParse(m['lat']?.toString() ?? '');
      final lon = double.tryParse(m['lon']?.toString() ?? '');
      final name = m['display_name'] as String?;
      if (lat == null || lon == null || name == null || name.trim().isEmpty) continue;
      out.add(NominatimSearchHit(lat: lat, lng: lon, displayName: name.trim()));
    }
    return out;
  } catch (_) {
    return [];
  }
}
