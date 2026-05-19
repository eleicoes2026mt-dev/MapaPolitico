import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/profile.dart';
import '../../../core/supabase/supabase_provider.dart';
import 'auth_provider.dart';
import '../../assessores/providers/assessores_provider.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';

const kInstagramPromptSnoozePrefix = 'campanha_mt_ig_prompt_snooze_';

/// Assessores, apoiadores e votantes do cadastro público «Amigos do Gilberto».
bool perfilPodeCadastrarInstagramCampanha(Profile? p) {
  if (p == null) return false;
  if (p.role == 'assessor' || p.role == 'apoiador') return true;
  if (p.role == 'votante') return p.cadastroViaQr;
  return false;
}

enum MeuInstagramCampanhaEstado {
  /// Candidato ou papel sem fluxo de Instagram.
  naoAplica,

  /// Ainda não há linha em assessores/apoiadores/votantes (aguardar sync).
  aguardandoCadastroBase,

  /// Elegível e sem `link_instagram` preenchido.
  faltaCadastrar,

  /// Já possui link salvo.
  ok,
}

final meuInstagramCampanhaEstadoProvider =
    FutureProvider<MeuInstagramCampanhaEstado>((ref) async {
  final profile = await ref.watch(profileProvider.future);
  if (!perfilPodeCadastrarInstagramCampanha(profile)) {
    return MeuInstagramCampanhaEstado.naoAplica;
  }

  if (profile!.role == 'assessor') {
    final a = await ref.watch(meuAssessorRegistroProvider.future);
    if (a == null) return MeuInstagramCampanhaEstado.aguardandoCadastroBase;
    final ig = a.linkInstagram?.trim() ?? '';
    return ig.isEmpty
        ? MeuInstagramCampanhaEstado.faltaCadastrar
        : MeuInstagramCampanhaEstado.ok;
  }

  if (profile.role == 'apoiador') {
    final ap = await ref.watch(meuApoiadorProvider.future);
    if (ap == null) return MeuInstagramCampanhaEstado.aguardandoCadastroBase;
    final ig = ap.linkInstagram?.trim() ?? '';
    return ig.isEmpty
        ? MeuInstagramCampanhaEstado.faltaCadastrar
        : MeuInstagramCampanhaEstado.ok;
  }

  if (profile.role == 'votante') {
    final res = await supabase
        .from('votantes')
        .select('link_instagram')
        .eq('profile_id', profile.id)
        .maybeSingle();
    if (res == null) return MeuInstagramCampanhaEstado.aguardandoCadastroBase;
    final ig = (res['link_instagram'] as String?)?.trim() ?? '';
    return ig.isEmpty
        ? MeuInstagramCampanhaEstado.faltaCadastrar
        : MeuInstagramCampanhaEstado.ok;
  }

  return MeuInstagramCampanhaEstado.naoAplica;
});
