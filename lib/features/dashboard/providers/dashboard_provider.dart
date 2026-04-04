import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../auth/providers/auth_provider.dart';

class DashboardStats {
  const DashboardStats({
    this.assessores = 0,
    this.apoiadores = 0,
    this.votantes = 0,
    this.estimativaVotos = 0,
    this.votosPorCidade = const [],
    this.apoiadoresPorPerfil = const [],
    this.totalBenfeitorias = 0,
    this.benfeitoriasCount = 0,
    this.aniversariantesHoje = 0,
    this.mensagensCount = 0,
  });

  final int assessores;
  final int apoiadores;
  final int votantes;
  final int estimativaVotos;
  final List<MapEntry<String, int>> votosPorCidade;
  final List<MapEntry<String, int>> apoiadoresPorPerfil;
  final double totalBenfeitorias;
  final int benfeitoriasCount;
  final int aniversariantesHoje;
  final int mensagensCount;
}

String _nomeMunicipioFromRow(Map<String, dynamic> r) {
  final mun = r['municipios'];
  if (mun is Map && mun['nome'] != null) return mun['nome'].toString().trim();
  return '';
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final client = supabase;
  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return const DashboardStats();

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
      votosPorCidade:
          votosPorCidade.map((e) => MapEntry(e.key, e.value)).toList(),
      apoiadoresPorPerfil: const [],
      totalBenfeitorias: 0,
      benfeitoriasCount: 0,
      aniversariantesHoje: 0,
      mensagensCount: 0,
    );
  }

  final assessoresRes = await client.from('assessores').select('id');
  var assessoresCount = assessoresRes.length;
  // O candidato também tem linha em assessores; a métrica é só assessores convidados (nível 2).
  if (profile.role == 'candidato' && assessoresCount > 0) {
    assessoresCount -= 1;
  }
  final apoiadoresRes =
      await client.from('apoiadores').select('id, estimativa_votos, perfil');
  final apoiadoresCount = apoiadoresRes.length;
  int estimativaVotos = 0;
  final perfilCount = <String, int>{};
  for (final r in apoiadoresRes) {
    estimativaVotos += (r['estimativa_votos'] as num?)?.toInt() ?? 0;
    final p = r['perfil'] as String? ?? 'Outro';
    perfilCount[p] = (perfilCount[p] ?? 0) + 1;
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

  final benfeitoriasRes = await client.from('benfeitorias').select('valor');
  double totalBenfeitorias = 0;
  for (final r in benfeitoriasRes) {
    totalBenfeitorias += (r['valor'] as num?)?.toDouble() ?? 0;
  }

  final now = DateTime.now();
  int aniversariantesHoje = 0;
  try {
    final raw = await client.from('aniversariantes').select('data_nascimento');
    for (final r in raw) {
      final d = DateTime.tryParse(r['data_nascimento'].toString());
      if (d != null && d.month == now.month && d.day == now.day)
        aniversariantesHoje++;
    }
  } catch (_) {}

  final mensagensRes = await client.from('mensagens').select('id');
  final mensagensCount = mensagensRes.length;

  final votosPorCidade = cidadeCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final apoiadoresPorPerfil = perfilCount.entries.toList();

  return DashboardStats(
    assessores: assessoresCount,
    apoiadores: apoiadoresCount,
    votantes: votantesCount,
    estimativaVotos: estimativaVotos,
    votosPorCidade:
        votosPorCidade.map((e) => MapEntry(e.key, e.value)).toList(),
    apoiadoresPorPerfil:
        apoiadoresPorPerfil.map((e) => MapEntry(e.key, e.value)).toList(),
    totalBenfeitorias: totalBenfeitorias,
    benfeitoriasCount: benfeitoriasRes.length,
    aniversariantesHoje: aniversariantesHoje,
    mensagensCount: mensagensCount,
  );
});
