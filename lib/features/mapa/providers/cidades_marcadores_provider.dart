import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../votantes/providers/votantes_provider.dart';
import '../data/mt_municipios_coords.dart';

/// Cidades com pelo menos um apoiador ou votante (marcadores no mapa).
final cidadesComApoiadorProvider = Provider<Map<String, int>>((ref) {
  final map = <String, int>{};
  final apoiadores = ref.watch(apoiadoresListProvider).valueOrNull ?? [];
  for (final a in apoiadores) {
    final cidade = a.cidadeParaMapa ?? a.cidadeNome;
    if (cidade != null && cidade.trim().isNotEmpty) {
      final key = normalizarNomeMunicipioMT(cidade);
      map[key] = (map[key] ?? 0) + 1;
    }
  }
  final votantes = ref.watch(votantesListProvider).valueOrNull ?? [];
  for (final v in votantes) {
    final nome = v.municipioNome;
    if (nome != null && nome.trim().isNotEmpty) {
      final key = normalizarNomeMunicipioMT(nome);
      map[key] = (map[key] ?? 0) + 1;
    }
  }
  return map;
});
