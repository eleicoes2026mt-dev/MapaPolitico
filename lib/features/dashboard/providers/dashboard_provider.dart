import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';

class DashboardStats {
  const DashboardStats({
    this.assessores = 0,
    this.apoiadores = 0,
    this.votantes = 0,
    this.estimativaVotos = 0,
    this.votosTseEleicao2022 = 0,
    this.perfilTseVinculado = false,
    this.votosPorCidade = const [],
  });

  final int assessores;
  final int apoiadores;
  final int votantes;
  final int estimativaVotos;
  /// Total de votos oficiais (TSE) na eleição 2022, soma por município (`get_votos_por_municipio`).
  final int votosTseEleicao2022;
  /// Se o perfil tem `sq_candidato_tse_2022` (Meu perfil → candidato na lista TSE).
  final bool perfilTseVinculado;
  final List<MapEntry<String, int>> votosPorCidade;
}

String _nomeMunicipioFromRow(Map<String, dynamic> r) {
  final mun = r['municipios'];
  if (mun is Map && mun['nome'] != null) return mun['nome'].toString().trim();
  return '';
}

/// Soma os votos oficiais do TSE (2022) para o `sq_candidato` do perfil.
Future<int> _totalVotosTseEleicao2022(
  dynamic client,
  int? sqCandidato,
) async {
  if (sqCandidato == null) return 0;
  try {
    final res = await client.rpc(
      'get_votos_por_municipio',
      params: {'p_sq_candidato': sqCandidato},
    );
    var total = 0;
    for (final e in res as List) {
      final row = e as Map<String, dynamic>;
      total += (row['qt_votos'] as num?)?.toInt() ?? 0;
    }
    return total;
  } catch (_) {
    return 0;
  }
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final client = supabase;
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return const DashboardStats();

  final sqTse = profile.sqCandidatoTse2022;
  final tseVinculado = sqTse != null;
  final votosTseTotal = await _totalVotosTseEleicao2022(client, sqTse);

  if (profile.role == 'apoiador') {
    final votantesRes = await client
        .from('votantes')
        .select('id, qtd_votos_familia, municipio_id, municipios(nome)');
    final votantesCount = votantesRes.length;
    var votosVotantes = 0;
    final cidadeCount = <String, int>{};
    for (final r in votantesRes) {
      final row = Map<String, dynamic>.from(r as Map);
      final q = (row['qtd_votos_familia'] as num?)?.toInt() ?? 1;
      votosVotantes += q;
      final nome = _nomeMunicipioFromRow(row);
      if (nome.isNotEmpty) cidadeCount[nome] = (cidadeCount[nome] ?? 0) + q;
    }
    final votosPorCidade = cidadeCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return DashboardStats(
      assessores: 0,
      apoiadores: 1,
      votantes: votantesCount,
      estimativaVotos: votosVotantes,
      votosTseEleicao2022: votosTseTotal,
      perfilTseVinculado: tseVinculado,
      votosPorCidade:
          votosPorCidade.map((e) => MapEntry(e.key, e.value)).toList(),
    );
  }

  final assessoresRes = await client.from('assessores').select('id');
  var assessoresCount = assessoresRes.length;
  // O candidato também tem linha em assessores; a métrica é só assessores convidados (nível 2).
  if (profile.role == 'candidato' && assessoresCount > 0) {
    assessoresCount -= 1;
  }
  final apoiadoresRes =
      await client.from('apoiadores').select('id, estimativa_votos');
  final apoiadoresCount = apoiadoresRes.length;
  int estimativaVotos = 0;
  for (final r in apoiadoresRes) {
    estimativaVotos += (r['estimativa_votos'] as num?)?.toInt() ?? 0;
  }

  final votantesRes = await client
      .from('votantes')
      .select('id, qtd_votos_familia, municipio_id, municipios(nome)');
  final votantesCount = votantesRes.length;
  int votosVotantes = 0;
  final cidadeCount = <String, int>{};
  for (final r in votantesRes) {
    final row = Map<String, dynamic>.from(r as Map);
    final q = (row['qtd_votos_familia'] as num?)?.toInt() ?? 1;
    votosVotantes += q;
    final nome = _nomeMunicipioFromRow(row);
    if (nome.isNotEmpty) cidadeCount[nome] = (cidadeCount[nome] ?? 0) + q;
  }

  estimativaVotos += votosVotantes;

  final votosPorCidade = cidadeCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return DashboardStats(
    assessores: assessoresCount,
    apoiadores: apoiadoresCount,
    votantes: votantesCount,
    estimativaVotos: estimativaVotos,
    votosTseEleicao2022: votosTseTotal,
    perfilTseVinculado: tseVinculado,
    votosPorCidade:
        votosPorCidade.map((e) => MapEntry(e.key, e.value)).toList(),
  );
});
