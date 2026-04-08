import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import 'assessores_provider.dart';

/// Enquanto o registo em [assessores] não carrega, não aplicar regras de «grau 2» (evita redirects e menu errados).
final assessorRegistroResolvidoProvider = Provider<bool>((ref) {
  final p = ref.watch(profileProvider).valueOrNull;
  if (p == null || p.role != 'assessor') return true;
  final async = ref.watch(meuAssessorRegistroProvider);
  return async.hasValue || async.hasError;
});

/// Candidato ou assessor com [Assessor.grauAcesso] == 1 (mesmas permissões de gestão que o deputado).
final podeGestaoCampanhaCompletaProvider = Provider<bool>((ref) {
  final p = ref.watch(profileProvider).valueOrNull;
  if (p == null) return false;
  if (p.isCandidato) return true;
  if (p.role != 'assessor') return false;
  final a = ref.watch(meuAssessorRegistroProvider).valueOrNull;
  return a != null && a.grauAcesso == 1;
});
