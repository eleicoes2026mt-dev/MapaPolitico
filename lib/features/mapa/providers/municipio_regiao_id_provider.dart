import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/geo/lat_lng.dart';
import '../data/geo_loader.dart';
import '../data/mt_municipios_coords.dart';

/// Mapeia chave normalizada do município → `id` da região intermediária no GeoJSON (para colorir polígonos do mapa).
final municipioRegiaoIdMapaProvider = FutureProvider<Map<String, String>>((ref) async {
  final regioes = await loadRegioesImediatasMTFromAsset(kMTRegioesImediatas2024Asset);
  final map = <String, String>{};
  for (final nomeKey in listCidadesMTNomesNormalizados) {
    final coords = getCoordsMunicipioMT(nomeKey);
    if (coords == null) continue;
    final pt = LatLng(coords.latitude, coords.longitude);
    for (final reg in regioes) {
      if (pointInRegion(pt, reg.polygons)) {
        map[nomeKey] = reg.id;
        break;
      }
    }
  }
  return map;
});
