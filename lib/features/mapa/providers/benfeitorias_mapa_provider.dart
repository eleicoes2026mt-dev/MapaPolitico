import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/geo_loader.dart';
import 'benfeitorias_agg_provider.dart';
import 'municipio_regiao_id_provider.dart';

/// Cores e valores agregados para preencher regiões no modo benfeitorias (mapa web).
class BenfeitoriasMapaPayload {
  const BenfeitoriasMapaPayload({
    required this.cores,
    required this.ratios,
    required this.valores,
  });
  final Map<String, String> cores;
  final Map<String, double> ratios;
  final Map<String, double> valores;
}

/// Cidade dentro do ranking de benfeitorias por região.
typedef BenfeitoriaCidadeRanking = ({
  String cidade,
  String key,
  double valor,
  int qtd,
});

/// Região intermediária com total de benfeitorias e cidades.
class BenfeitoriaRegiaoRanking {
  const BenfeitoriaRegiaoRanking({
    required this.id,
    required this.nome,
    required this.valorTotal,
    required this.qtdTotal,
    required this.cidades,
  });

  final String id;
  final String nome;
  final double valorTotal;
  final int qtdTotal;
  final List<BenfeitoriaCidadeRanking> cidades;
}

/// Agrega [benfeitoriasAggPorMunicipioProvider] por região do mapa (só linhas com município na RPC).
final benfeitoriasRankingRegioesProvider = FutureProvider<List<BenfeitoriaRegiaoRanking>>((ref) async {
  final agg = await ref.watch(benfeitoriasAggPorMunicipioProvider.future);
  final cache = await ref.watch(municipioRegiaoIdMapaProvider.future);
  final regioes = await loadRegioesImediatasMTFromAsset(kMTRegioesImediatas2024Asset);
  final nomePorId = {for (final r in regioes) r.id: r.nome};

  final groups = <String, List<BenfeitoriaAggMunicipio>>{};
  for (final row in agg) {
    final rid = cache[row.chaveNormalizada];
    if (rid == null) continue;
    groups.putIfAbsent(rid, () => []).add(row);
  }

  final out = <BenfeitoriaRegiaoRanking>[];
  for (final e in groups.entries) {
    final cidades = e.value
        .map(
          (m) => (
            cidade: m.municipioNome,
            key: m.chaveNormalizada,
            valor: m.valorTotal,
            qtd: m.qtd,
          ),
        )
        .toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
    final vt = cidades.fold<double>(0, (s, c) => s + c.valor);
    final qt = cidades.fold<int>(0, (s, c) => s + c.qtd);
    out.add(BenfeitoriaRegiaoRanking(
      id: e.key,
      nome: nomePorId[e.key] ?? e.key,
      valorTotal: vt,
      qtdTotal: qt,
      cidades: cidades,
    ));
  }
  out.sort((a, b) => b.valorTotal.compareTo(a.valorTotal));
  return out;
});
