import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/candidato_raiz_provider.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../../../models/profile.dart';
import '../../assessores/providers/gestao_campanha_provider.dart';
import '../../auth/providers/auth_provider.dart';

/// Igual ao uso no dashboard: soma oficial TSE MT 2022 para o sq do candidato.
Future<int> _rpcTotalVotosTse2022(dynamic client, int? sqCandidato) async {
  if (sqCandidato == null) return 0;
  try {
    final res = await client.rpc(
      'get_votos_por_municipio',
      params: {'p_sq_candidato': sqCandidato},
    );
    var total = 0;
    for (final e in res as List) {
      final row = Map<String, dynamic>.from(e as Map);
      total += (row['qt_votos'] as num?)?.toInt() ?? 0;
    }
    return total;
  } catch (_) {
    return 0;
  }
}

Future<(int votes, bool tseLinked)> _votosTseReferenciaCampanha(
  Ref ref,
  Profile profile,
) async {
  final client = supabase;
  int? sqTse = profile.sqCandidatoTse2022;
  if (profile.role == 'assessor') {
    final raiz = await ref.read(candidatoRaizCampanhaProfileIdProvider.future);
    if (raiz != null) {
      try {
        final row = await client
            .from('profiles')
            .select('sq_candidato_tse_2022')
            .eq('id', raiz)
            .maybeSingle();
        sqTse = (row?['sq_candidato_tse_2022'] as num?)?.toInt();
      } catch (_) {
        sqTse = null;
      }
    } else {
      sqTse = null;
    }
  }
  final votes = await _rpcTotalVotosTse2022(client, sqTse);
  final linked = sqTse != null;
  return (votes, linked);
}

/// Apoiadores com votantes registados sob este vínculo.
class PainelIndicacaoPorApoiador {
  const PainelIndicacaoPorApoiador({
    required this.apoiadorId,
    required this.apoiadorNome,
    required this.estimativaVotos,
    required this.totalVotantes,
    required this.somaVotosFamilia,
  });

  final String apoiadorId;
  final String apoiadorNome;
  final int estimativaVotos;
  final int totalVotantes;
  final int somaVotosFamilia;
}

/// Agregação por assessor (quem cadastrou os apoiadores).
class PainelIndicacaoPorAssessor {
  const PainelIndicacaoPorAssessor({
    required this.assessorId,
    required this.assessorNome,
    required this.totalApoiadoresAtivos,
    required this.estimativaVotosApoiadores,
    required this.apoiadoresComVotantes,
    required this.totalVotantesViaApoiadores,
    required this.somaVotosFamiliaViaApoiadores,
    required this.votantesDiretosSemApoiador,
    required this.somaVotosFamiliaDiretos,
    required this.linhasPorApoiador,
  });

  final String assessorId;
  final String assessorNome;
  /// Apoiadores ativos (`excluido_em` nulo).
  final int totalApoiadoresAtivos;
  /// Soma de `apoiadores.estimativa_votos` dessa rede.
  final int estimativaVotosApoiadores;
  /// Quantos destes apoiadores têm pelo menos um votante vinculado (`apoiador_id`).
  final int apoiadoresComVotantes;
  /// Votantes com `apoiador_id` nos apoiadores deste assessor.
  final int totalVotantesViaApoiadores;
  /// Soma de `votantes.qtd_votos_familia` nos votantes dessa rede.
  final int somaVotosFamiliaViaApoiadores;

  /// Votantes onde `assessor_id` é este mas `apoiador_id` é nulo (cadastro direto).
  final int votantesDiretosSemApoiador;
  final int somaVotosFamiliaDiretos;

  final List<PainelIndicacaoPorApoiador> linhasPorApoiador;

  /// Desempenho “rede”: votantes sob apoiadores + diretos pelo assessor.
  int get totalVotantesRede =>
      totalVotantesViaApoiadores + votantesDiretosSemApoiador;

  int get somaVotosFamiliaRede =>
      somaVotosFamiliaViaApoiadores + somaVotosFamiliaDiretos;
}

class PainelIndicacoesAgg {
  const PainelIndicacoesAgg({
    required this.porAssessor,
    required this.totalApoiadoresCampanhaAtivos,
    required this.totalApoiadoresNaBase,
    required this.totalVotantesSomadosFamiliaViaRede,
    required this.subtotalEstimativaTodosApoiadores,
    required this.subtotalVotosFamiliaTodosVotantes,
    required this.totalEstimativaAlinhadoDashboard,
    required this.totalCadastrosVotantesNaRede,
    required this.votosOficiaisTseUltimaCorridaCampanha,
    required this.campanhaTseVinculada,
  });

  final List<PainelIndicacaoPorAssessor> porAssessor;
  final int totalApoiadoresCampanhaAtivos;
  /// Linhas em `apoiadores` (inclui excluídos), para médias no mesmo critério do dashboard.
  final int totalApoiadoresNaBase;
  /// Soma dos votos em família agregados pela rede de indicações (para barras por assessor).
  final int totalVotantesSomadosFamiliaViaRede;
  /// Σ `apoiadores.estimativa_votos` em **todos** os apoiadores (igual dashboard).
  final int subtotalEstimativaTodosApoiadores;
  /// Σ `votantes.qtd_votos_familia` em **todos** os votantes (igual dashboard).
  final int subtotalVotosFamiliaTodosVotantes;
  /// Igual ao cartão «Est. Votos» do dashboard: [subtotalEstimativaTodosApoiadores] + [subtotalVotosFamiliaTodosVotantes].
  final int totalEstimativaAlinhadoDashboard;
  /// Soma, por rede de assessores, dos votantes registados (`totalVotantesRede`). Cada linha conta uma vez sob o assessor dono da rede.
  final int totalCadastrosVotantesNaRede;
  /// Soma oficial TSE 2022 (MT) quando o deputado está vinculado a `sq_candidato` no perfil.
  final int votosOficiaisTseUltimaCorridaCampanha;
  final bool campanhaTseVinculada;
}

/// Painel de indicações: candidato ou assessor grau 1 (gestão da campanha).
final painelIndicacoesProvider = FutureProvider<PainelIndicacoesAgg?>((ref) async {
  final pode = ref.watch(podeGestaoCampanhaCompletaProvider);
  if (!pode) return null;

  final profile = await ref.watch(profileProvider.future);
  if (profile == null) return null;

  final apRes = await supabase
      .from('apoiadores')
      .select('id, nome, assessor_id, estimativa_votos, excluido_em');

  final vtRes =
      await supabase.from('votantes').select('apoiador_id, assessor_id, qtd_votos_familia');

  final apRows = (apRes as List).map((e) => Map<String, dynamic>.from(e as Map));
  final ativos = apRows.where((m) => m['excluido_em'] == null).toList();

  /// apoiador_id -> lista votantes { 'qtd': int }
  final votantesPorApoiador = <String, List<int>>{};
  /// assessor_id -> votantes diretos (sem apoiador)
  final diretosPorAssessor = <String, List<int>>{};

  for (final raw in vtRes as List) {
    final m = Map<String, dynamic>.from(raw as Map);
    final aidAp = m['apoiador_id'] as String?;
    final qty = (m['qtd_votos_familia'] as num?)?.toInt() ?? 1;
    if (aidAp != null && aidAp.isNotEmpty) {
      votantesPorApoiador.putIfAbsent(aidAp, () => []).add(qty);
    } else {
      final aidAs = m['assessor_id'] as String?;
      if (aidAs != null && aidAs.isNotEmpty) {
        diretosPorAssessor.putIfAbsent(aidAs, () => []).add(qty);
      }
    }
  }

  final porAssessorId = <String, List<Map<String, dynamic>>>{};
  for (final m in ativos) {
    final sid = m['assessor_id'] as String?;
    if (sid == null || sid.isEmpty) continue;
    porAssessorId.putIfAbsent(sid, () => []).add(m);
  }

  /// Nomes (lista do painel pode excluir o próprio deputado como linha «assessor»).
  final nomesAssessor = <String, String>{};
  try {
    final asRes = await supabase.from('assessores').select('id, nome');
    for (final r in asRes as List) {
      final mm = Map<String, dynamic>.from(r as Map);
      final id = mm['id'] as String?;
      final nome = (mm['nome'] as String?)?.trim();
      if (id != null && nome != null && nome.isNotEmpty) nomesAssessor[id] = nome;
    }
  } catch (_) {}

  /// Assessores sem apoiadores ou só com cadastro direto de votantes.
  for (final id in nomesAssessor.keys) {
    porAssessorId.putIfAbsent(id, () => []);
  }
  for (final id in diretosPorAssessor.keys) {
    porAssessorId.putIfAbsent(id, () => []);
  }

  final linhas = <PainelIndicacaoPorAssessor>[];

  for (final entry in porAssessorId.entries) {
    final assessorId = entry.key;
    final listaAp = entry.value;

    listaAp.sort(
      (a, b) => (a['nome'] as String? ?? '').toLowerCase().compareTo(
            (b['nome'] as String? ?? '').toLowerCase(),
          ),
    );

    final porApoiador = <PainelIndicacaoPorApoiador>[];
    var sumEst = 0;
    var apComVt = 0;
    var totVtVia = 0;
    var sumFamVia = 0;

    for (final ap in listaAp) {
      final pid = ap['id'] as String;
      final nome = ap['nome'] as String? ?? '—';
      final est =
          (ap['estimativa_votos'] as num?)?.toInt() ?? 0;
      sumEst += est;

      final qts = votantesPorApoiador[pid] ?? const [];
      final nVt = qts.length;
      final sFam =
          qts.fold<int>(0, (a, q) => a + q);
      if (nVt > 0) apComVt++;
      totVtVia += nVt;
      sumFamVia += sFam;

      porApoiador.add(
        PainelIndicacaoPorApoiador(
          apoiadorId: pid,
          apoiadorNome: nome,
          estimativaVotos: est,
          totalVotantes: nVt,
          somaVotosFamilia: sFam,
        ),
      );
    }

    porApoiador.sort((a, b) => b.totalVotantes.compareTo(a.totalVotantes));

    final dirs = diretosPorAssessor[assessorId] ?? const [];
    final nDir = dirs.length;
    final sDir = dirs.fold<int>(0, (a, q) => a + q);

    final nomeAss = nomesAssessor[assessorId] ?? 'Assessor';

    linhas.add(
      PainelIndicacaoPorAssessor(
        assessorId: assessorId,
        assessorNome: nomeAss,
        totalApoiadoresAtivos: listaAp.length,
        estimativaVotosApoiadores: sumEst,
        apoiadoresComVotantes: apComVt,
        totalVotantesViaApoiadores: totVtVia,
        somaVotosFamiliaViaApoiadores: sumFamVia,
        votantesDiretosSemApoiador: nDir,
        somaVotosFamiliaDiretos: sDir,
        linhasPorApoiador: porApoiador,
      ),
    );
  }

  linhas.sort((a, b) => b.estimativaVotosApoiadores.compareTo(a.estimativaVotosApoiadores));

  final totalAp = ativos.length;
  final sumFamCampaign = linhas.fold<int>(
      0, (acc, row) => acc + row.somaVotosFamiliaRede);

  final sumEstTodosApoiadores = apRows.fold<int>(
    0,
    (a, m) => a + ((m['estimativa_votos'] as num?)?.toInt() ?? 0),
  );
  final sumFamTodosVotantes = (vtRes as List).fold<int>(0, (a, raw) {
    final m = Map<String, dynamic>.from(raw as Map);
    return a + ((m['qtd_votos_familia'] as num?)?.toInt() ?? 1);
  });
  final totalAlinhadoDashboard = sumEstTodosApoiadores + sumFamTodosVotantes;
  final totalCadVot =
      linhas.fold<int>(0, (acc, row) => acc + row.totalVotantesRede);

  final tseFut = await _votosTseReferenciaCampanha(ref, profile);
  final votosTse = tseFut.$1;
  final tseVin = tseFut.$2;

  return PainelIndicacoesAgg(
    porAssessor: linhas,
    totalApoiadoresCampanhaAtivos: totalAp,
    totalApoiadoresNaBase: apRows.length,
    totalVotantesSomadosFamiliaViaRede: sumFamCampaign,
    subtotalEstimativaTodosApoiadores: sumEstTodosApoiadores,
    subtotalVotosFamiliaTodosVotantes: sumFamTodosVotantes,
    totalEstimativaAlinhadoDashboard: totalAlinhadoDashboard,
    totalCadastrosVotantesNaRede: totalCadVot,
    votosOficiaisTseUltimaCorridaCampanha: votosTse,
    campanhaTseVinculada: tseVin,
  );
});
