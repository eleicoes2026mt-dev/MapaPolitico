import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/apoiador.dart';
import '../../../models/votante.dart';
import '../../dados_tse/providers/dados_tse_provider.dart';
import '../../votantes/providers/votantes_provider.dart';
import '../data/mt_municipios_coords.dart';
import '../models/mapa_marcador_cidade.dart';
import 'benfeitorias_agg_provider.dart';
import 'cidades_marcadores_provider.dart';
import 'mapa_filtros_provider.dart';
import 'municipio_cd_rgint_provider.dart';

Map<String, int> buildEstimativaPorCidadeFromLists(
  List<Apoiador> apoiadores,
  List<Votante> votantes, {
  String? onlyApoiadorId,
  FonteEstimativaMapa fonte = FonteEstimativaMapa.todos,
}) {
  final result = <String, int>{};

  // Apoiadores
  if (fonte == FonteEstimativaMapa.todos || fonte == FonteEstimativaMapa.apenasApoiadores) {
    for (final a in apoiadores) {
      if (onlyApoiadorId != null && a.id != onlyApoiadorId) continue;
      final cidade = a.cidadeParaMapa ?? a.cidadeNome;
      if (cidade == null || cidade.trim().isEmpty) continue;
      final key = normalizarNomeMunicipioMT(cidade);
      result[key] = (result[key] ?? 0) + a.estimativaVotos;
    }
  }

  // Votantes — usa municipioNome (join) ou cidadeNome (texto livre) como fallback
  if (fonte == FonteEstimativaMapa.todos || fonte == FonteEstimativaMapa.apenasVotantes) {
    for (final v in votantes) {
      if (onlyApoiadorId != null && v.apoiadorId != onlyApoiadorId) continue;
      final nome = v.municipioNome ?? v.cidadeNome;
      if (nome == null || nome.trim().isEmpty) continue;
      final key = normalizarNomeMunicipioMT(nome);
      final q = v.qtdVotosFamilia < 1 ? 1 : v.qtdVotosFamilia;
      result[key] = (result[key] ?? 0) + q;
    }
  }

  return result;
}

Set<String>? _topBenfeitoriasKeys(List<BenfeitoriaAggMunicipio>? agg, int topN) {
  if (agg == null || agg.isEmpty || topN <= 0) return null;
  final sorted = List<BenfeitoriaAggMunicipio>.from(agg)..sort((a, b) => b.qtd.compareTo(a.qtd));
  final take = sorted.length < topN ? sorted.length : topN;
  return {for (var i = 0; i < take; i++) sorted[i].chaveNormalizada};
}

Map<String, T> _intersecionarChaves<T>(Map<String, T> map, Set<String> permitidas) {
  return {for (final e in map.entries) if (permitidas.contains(e.key)) e.key: e.value};
}

/// Estimativa por cidade respeitando filtros da tela Mapa.
final mapaEstimativaFiltradaProvider = Provider<Map<String, int>>((ref) {
  final filtros = ref.watch(mapaFiltrosProvider);
  final apoiadores = ref.watch(apoiadoresParaMapaProvider).valueOrNull ?? [];
  final votantes = ref.watch(votantesListProvider).valueOrNull ?? [];
  var map = buildEstimativaPorCidadeFromLists(
    apoiadores,
    votantes,
    onlyApoiadorId: filtros.apoiadorId,
    fonte: filtros.fonteEstimativa,
  );

  final cdRgintCache = ref.watch(municipioCdRgintCacheProvider).valueOrNull;
  final agg = ref.watch(benfeitoriasAggPorMunicipioProvider).valueOrNull;
  final topKeys = _topBenfeitoriasKeys(agg, filtros.topBenfeitoriasMunicipios);

  if (filtros.cidadeKey != null && filtros.cidadeKey!.isNotEmpty) {
    final k = filtros.cidadeKey!;
    map = map.containsKey(k) ? {k: map[k]!} : {};
  }

  if (filtros.regiaoCdRgint != null && filtros.regiaoCdRgint!.isNotEmpty && cdRgintCache != null) {
    final permitidas =
        cdRgintCache.entries.where((e) => e.value == filtros.regiaoCdRgint).map((e) => e.key).toSet();
    map = _intersecionarChaves(map, permitidas);
  }

  if (topKeys != null) {
    map = _intersecionarChaves(map, topKeys);
  }

  return map;
});

/// Marcadores (apoiadores/votantes) com os mesmos filtros.
final mapaMarcadoresFiltradosProvider = Provider<Map<String, MapaMarcadorCidade>>((ref) {
  final filtros = ref.watch(mapaFiltrosProvider);
  final apoiadores = ref.watch(apoiadoresParaMapaProvider).valueOrNull ?? [];
  final votantes = ref.watch(votantesListProvider).valueOrNull ?? [];
  var map = buildMarcadoresCidadesMap(
    apoiadores,
    votantes,
    onlyApoiadorId: filtros.apoiadorId,
  );

  final cdRgintCache = ref.watch(municipioCdRgintCacheProvider).valueOrNull;
  final agg = ref.watch(benfeitoriasAggPorMunicipioProvider).valueOrNull;
  final topKeys = _topBenfeitoriasKeys(agg, filtros.topBenfeitoriasMunicipios);

  if (filtros.cidadeKey != null && filtros.cidadeKey!.isNotEmpty) {
    final k = filtros.cidadeKey!;
    map = map.containsKey(k) ? {k: map[k]!} : {};
  }

  if (filtros.regiaoCdRgint != null && filtros.regiaoCdRgint!.isNotEmpty && cdRgintCache != null) {
    final permitidas =
        cdRgintCache.entries.where((e) => e.value == filtros.regiaoCdRgint).map((e) => e.key).toSet();
    map = _intersecionarChaves(map, permitidas);
  }

  if (topKeys != null) {
    map = _intersecionarChaves(map, topKeys);
  }

  return map;
});

/// Votos TSE: mapa completo, restrito por filtros, ou vazio quando TSE está desligado.
final mapaVotosTseAjustadosProvider = Provider<Map<String, int>>((ref) {
  final filtros = ref.watch(mapaFiltrosProvider);

  // TSE desligado → não passa dados para o widget (círculos somem)
  if (!filtros.mostrarTSE) return {};

  final full = ref.watch(votosPorMunicipioTseProvider).valueOrNull ?? {};

  final temFiltro = filtros.cidadeKey != null ||
      (filtros.regiaoCdRgint != null && filtros.regiaoCdRgint!.isNotEmpty) ||
      filtros.topBenfeitoriasMunicipios > 0 ||
      filtros.apoiadorId != null;

  if (!temFiltro) return full;

  final estimativa = ref.watch(mapaEstimativaFiltradaProvider);
  final marcadores = ref.watch(mapaMarcadoresFiltradosProvider);

  final keys = <String>{
    ...estimativa.keys,
    ...marcadores.keys,
    if (filtros.cidadeKey != null && filtros.cidadeKey!.isNotEmpty) filtros.cidadeKey!,
  };

  if (keys.isEmpty) return {};

  return {for (final k in keys) if (full.containsKey(k)) k: full[k]!};
});
