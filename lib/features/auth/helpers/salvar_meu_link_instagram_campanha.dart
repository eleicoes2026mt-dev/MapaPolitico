import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/meu_instagram_campanha_provider.dart';
import '../../assessores/providers/assessores_provider.dart';
import '../../apoiadores/providers/apoiadores_provider.dart';
import '../../votantes/providers/votantes_provider.dart';

/// Persiste [linkInstagram] no registro de campanha do utilizador (assessor / apoiador / votante).
Future<void> salvarMeuLinkInstagramCampanha(WidgetRef ref, String? linkInstagram) async {
  final profile = await ref.read(profileProvider.future);
  if (profile == null) {
    throw Exception('Sessão inválida.');
  }
  final trimmed = linkInstagram?.trim();
  final toSave = (trimmed == null || trimmed.isEmpty) ? null : trimmed;

  if (profile.role == 'assessor') {
    final id = await ref.read(meuAssessorIdProvider.future);
    if (id == null) {
      throw Exception('Registro de assessor não encontrado.');
    }
    await atualizarAssessorLinkInstagram(assessorId: id, linkInstagram: toSave);
    ref.invalidate(meuAssessorRegistroProvider);
    ref.invalidate(meuAssessorIdProvider);
  } else if (profile.role == 'apoiador') {
    final id = await ref.read(meuApoiadorIdProvider.future);
    if (id == null) {
      throw Exception('Registro de apoiador não encontrado.');
    }
    await ref.read(atualizarApoiadorProvider)(
      id,
      AtualizarApoiadorParams(
        atualizarLinkInstagram: true,
        linkInstagram: toSave,
      ),
    );
    ref.invalidate(meuApoiadorProvider);
    ref.invalidate(meuApoiadorIdProvider);
  } else if (profile.role == 'votante') {
    final res = await supabase
        .from('votantes')
        .select('id')
        .eq('profile_id', profile.id)
        .maybeSingle();
    final vid = res?['id'] as String?;
    if (vid == null) {
      throw Exception('Seu cadastro ainda não está disponível. Aguarde um instante e tente de novo.');
    }
    await ref.read(atualizarVotanteProvider)(
      vid,
      AtualizarVotanteParams(
        atualizarLinkInstagram: true,
        linkInstagram: toSave,
      ),
    );
    ref.invalidate(votantesListProvider);
  } else {
    throw Exception('Este perfil não cadastra Instagram por aqui.');
  }

  ref.invalidate(meuInstagramCampanhaEstadoProvider);
}
