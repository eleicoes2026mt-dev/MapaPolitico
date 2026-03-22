import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/regioes_mt.dart';
import '../../../models/votante.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../votantes/providers/votantes_provider.dart';
import '../data/mt_municipios_coords.dart';
import 'benfeitorias_agg_provider.dart';
import 'mapa_filtros_provider.dart';
import 'municipio_cd_rgint_provider.dart';

/// KPIs da campanha limitados à região selecionada (ou todo MT se não houver filtro de região).
class MapaKpisRegiao {
  const MapaKpisRegiao({
    required this.temFiltroRegiao,
    this.nomeRegiao,
    required this.totalVotantesCadastrados,
    required this.totalVotosEstimadosRede,
    this.cidadeMaisVotosNome,
    required this.cidadeMaisVotosValor,
    this.apoiadorMaisVotantesNome,
    required this.apoiadorMaisVotantesQtd,
    required this.valorTotalBenfeitorias,
    required this.benfeitoriasPorCidadeTop,
  });

  final bool temFiltroRegiao;
  final String? nomeRegiao;
  final int totalVotantesCadastrados;
  final int totalVotosEstimadosRede;
  final String? cidadeMaisVotosNome;
  final int cidadeMaisVotosValor;
  final String? apoiadorMaisVotantesNome;
  final int apoiadorMaisVotantesQtd;
  final double valorTotalBenfeitorias;
  /// Até 8 linhas: cidade, qtd benfeitorias, valor
  final List<({String cidadeNome, int qtd, double valor})> benfeitoriasPorCidadeTop;
}

bool _votanteNaArea(Votante v, Set<String>? chavesRegiao) {
  final nome = v.municipioNome;
  if (nome == null || nome.trim().isEmpty) return false;
  final k = normalizarNomeMunicipioMT(nome);
  if (chavesRegiao == null) return true;
  return chavesRegiao.contains(k);
}

final mapaKpisRegiaoProvider = Provider<MapaKpisRegiao>((ref) {
  final filtros = ref.watch(mapaFiltrosProvider);
  final cache = ref.watch(municipioCdRgintCacheProvider).valueOrNull;
  final votantes = ref.watch(votantesListProvider).valueOrNull ?? [];
  final apoiadores = ref.watch(apoiadoresListProvider).valueOrNull ?? [];
  final agg = ref.watch(benfeitoriasAggPorMunicipioProvider).valueOrNull ?? [];

  Set<String>? chavesRegiao;
  String? nomeRegiao;
  if (filtros.regiaoCdRgint != null && filtros.regiaoCdRgint!.isNotEmpty && cache != null) {
    chavesRegiao = cache.entries
        .where((e) => e.value == filtros.regiaoCdRgint)
        .map((e) => e.key)
        .toSet();
    for (final r in regioesIntermediariasMT) {
      if (r.id == filtros.regiaoCdRgint) {
        nomeRegiao = r.nome;
        break;
      }
    }
  }

  final votantesArea = votantes.where((v) => _votanteNaArea(v, chavesRegiao)).toList();

  final totalCad = votantesArea.length;
  final totalVotos = votantesArea.fold<int>(0, (s, v) => s + (v.qtdVotosFamilia < 1 ? 1 : v.qtdVotosFamilia));

  final porCidade = <String, int>{};
  for (final v in votantesArea) {
    final nome = v.municipioNome;
    if (nome == null || nome.isEmpty) continue;
    final k = normalizarNomeMunicipioMT(nome);
    porCidade[k] = (porCidade[k] ?? 0) + (v.qtdVotosFamilia < 1 ? 1 : v.qtdVotosFamilia);
  }
  String? cidadeTopNome;
  var cidadeTopVal = 0;
  for (final e in porCidade.entries) {
    if (e.value > cidadeTopVal) {
      cidadeTopVal = e.value;
      cidadeTopNome = displayNomeCidadeMT(e.key);
    }
  }

  final porApoiador = <String, int>{};
  for (final v in votantesArea) {
    final aid = v.apoiadorId;
    if (aid == null || aid.isEmpty) continue;
    porApoiador[aid] = (porApoiador[aid] ?? 0) + 1;
  }
  String? apTopNome;
  var apTopQtd = 0;
  final apPorId = {for (final a in apoiadores) a.id: a.nome};
  for (final e in porApoiador.entries) {
    if (e.value > apTopQtd) {
      apTopQtd = e.value;
      apTopNome = apPorId[e.key] ?? 'Apoiador';
    }
  }

  final keys = chavesRegiao;
  final aggFiltrado = keys == null
      ? agg
      : agg.where((b) => keys.contains(b.chaveNormalizada)).toList();
  final valorBen = aggFiltrado.fold<double>(0, (s, b) => s + b.valorTotal);

  final benTop = aggFiltrado.map((b) => (cidadeNome: displayNomeCidadeMT(b.chaveNormalizada), qtd: b.qtd, valor: b.valorTotal)).toList()
    ..sort((a, b) => b.valor.compareTo(a.valor));

  return MapaKpisRegiao(
    temFiltroRegiao: chavesRegiao != null,
    nomeRegiao: nomeRegiao,
    totalVotantesCadastrados: totalCad,
    totalVotosEstimadosRede: totalVotos,
    cidadeMaisVotosNome: cidadeTopNome,
    cidadeMaisVotosValor: cidadeTopVal,
    apoiadorMaisVotantesNome: apTopNome,
    apoiadorMaisVotantesQtd: apTopQtd,
    valorTotalBenfeitorias: valorBen,
    benfeitoriasPorCidadeTop: benTop.take(8).toList(),
  );
});
