import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/apoiador.dart';
import '../../../models/assessor.dart';
import '../../../models/votante.dart';
import '../../auth/providers/auth_provider.dart';
import '../../assessores/providers/assessores_provider.dart';
import '../../votantes/providers/votantes_provider.dart';
import 'apoiadores_provider.dart';

/// Indicadores agregados por assessor (candidato + equipe).
class AssessorKpiLinha {
  const AssessorKpiLinha({
    required this.assessorId,
    required this.nome,
    required this.qtdApoiadores,
    required this.qtdVotantes,
    required this.estimativaVotosApoiadores,
    required this.estimativaVotosVotantes,
  });

  final String assessorId;
  final String nome;
  final int qtdApoiadores;
  final int qtdVotantes;
  final int estimativaVotosApoiadores;
  final int estimativaVotosVotantes;
}

class CampanhaKpisResumo {
  const CampanhaKpisResumo({
    required this.porAssessor,
    required this.totalApoiadores,
    required this.totalVotantes,
    required this.totalEstimativaApoiadores,
    required this.totalEstimativaVotantes,
  });

  final List<AssessorKpiLinha> porAssessor;
  final int totalApoiadores;
  final int totalVotantes;
  final int totalEstimativaApoiadores;
  final int totalEstimativaVotantes;
}

int _votosEstimadosVotante(Votante v) {
  if (v.abrangencia == 'Familiar') {
    return v.qtdVotosFamilia < 1 ? 1 : v.qtdVotosFamilia;
  }
  return 1;
}

/// KPIs para candidato e assessor (painel Apoiadores). Apoiador não usa.
final campanhaKpisProvider = FutureProvider<CampanhaKpisResumo?>((ref) async {
  final profile = ref.watch(profileProvider).valueOrNull;
  if (profile == null) return null;
  if (profile.role == 'apoiador') return null;

  final apoiadores = await ref.watch(apoiadoresListProvider.future);
  final votantes = await ref.watch(votantesListProvider.future);
  final assessores = await ref.watch(assessoresListProvider.future);

  final porId = <String, _Acc>{};
  for (final Apoiador ap in apoiadores) {
    porId.putIfAbsent(ap.assessorId, () => _Acc());
    final acc = porId[ap.assessorId]!;
    acc.apoiadores++;
    acc.estApoiadores += ap.estimativaVotos;
  }

  for (final Votante v in votantes) {
    final aid = v.assessorId;
    if (aid == null || aid.isEmpty) continue;
    porId.putIfAbsent(aid, () => _Acc());
    final acc = porId[aid]!;
    acc.votantes++;
    acc.estVotantes += _votosEstimadosVotante(v);
  }

  final sortedAssessores = List<Assessor>.from(assessores)
    ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

  final linhas = <AssessorKpiLinha>[];
  for (final a in sortedAssessores) {
    final acc = porId[a.id];
    linhas.add(
      AssessorKpiLinha(
        assessorId: a.id,
        nome: a.nome,
        qtdApoiadores: acc?.apoiadores ?? 0,
        qtdVotantes: acc?.votantes ?? 0,
        estimativaVotosApoiadores: acc?.estApoiadores ?? 0,
        estimativaVotosVotantes: acc?.estVotantes ?? 0,
      ),
    );
  }

  for (final e in porId.entries) {
    if (assessores.any((a) => a.id == e.key)) continue;
    linhas.add(
      AssessorKpiLinha(
        assessorId: e.key,
        nome: 'Outros / legado',
        qtdApoiadores: e.value.apoiadores,
        qtdVotantes: e.value.votantes,
        estimativaVotosApoiadores: e.value.estApoiadores,
        estimativaVotosVotantes: e.value.estVotantes,
      ),
    );
  }

  var tAp = 0, tVo = 0, tEstA = 0, tEstV = 0;
  for (final l in linhas) {
    tAp += l.qtdApoiadores;
    tVo += l.qtdVotantes;
    tEstA += l.estimativaVotosApoiadores;
    tEstV += l.estimativaVotosVotantes;
  }

  return CampanhaKpisResumo(
    porAssessor: linhas,
    totalApoiadores: tAp,
    totalVotantes: tVo,
    totalEstimativaApoiadores: tEstA,
    totalEstimativaVotantes: tEstV,
  );
});

class _Acc {
  int apoiadores = 0;
  int votantes = 0;
  int estApoiadores = 0;
  int estVotantes = 0;
}
